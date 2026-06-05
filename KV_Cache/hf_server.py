import argparse
from functools import lru_cache
import json
import os
from pathlib import Path
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import StreamingResponse
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import uvicorn

from config import CONFIG_PATH_ENV_VAR, RuntimeConfig, load_runtime_config
from model import GenerationResult, GenerationTimings, resolve_target_device, synchronize_device
from server import (
    CompletionChoice,
    CompletionUsage,
    CompletionsCreateRequest,
    CompletionsCreateResponse,
    InputTokensDetails,
    OutputMessage,
    OutputTextPart,
    OutputTokensDetails,
    ResponsesCreateRequest,
    ResponsesCreateResponse,
    Usage,
    build_prompt,
    normalize_completion_prompts,
)


class HFTransformer:
    def __init__(
        self,
        model_name: str = "sshleifer/tiny-gpt2",
        *,
        use_kv_cache: bool = True,
        target_device: str = "auto",
    ):
        self.use_kv_cache = use_kv_cache
        self.device = resolve_target_device(target_device)
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModelForCausalLM.from_pretrained(model_name).to(device=self.device)
        self.model.eval()

        if self.tokenizer.pad_token_id is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token

    def generate_with_metadata(
        self,
        prompt: str,
        max_new_tokens: int = 64,
        *,
        temperature: float | None = None,
        top_p: float | None = None,
    ) -> GenerationResult:
        encoded = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        input_ids = encoded.input_ids
        input_token_count = input_ids.shape[-1]

        generation_kwargs = {
            "max_new_tokens": max_new_tokens,
            "pad_token_id": self.tokenizer.pad_token_id,
            "eos_token_id": self.tokenizer.eos_token_id,
            "use_cache": self.use_kv_cache,
        }

        if temperature is not None and temperature <= 0:
            generation_kwargs["do_sample"] = False
        elif temperature is not None or top_p is not None:
            generation_kwargs["do_sample"] = True
            if temperature is not None:
                generation_kwargs["temperature"] = temperature
            if top_p is not None:
                generation_kwargs["top_p"] = top_p

        timings = GenerationTimings()
        with torch.no_grad():
            synchronize_device(self.device)
            started_at = time.perf_counter()
            output_ids = self.model.generate(**encoded, **generation_kwargs)
            synchronize_device(self.device)
            timings.decode_ms = (time.perf_counter() - started_at) * 1000
            timings.decode_calls = 1

        generated_ids = output_ids[0, input_token_count:]
        return GenerationResult(
            full_text=self.tokenizer.decode(output_ids[0]),
            output_text=self.tokenizer.decode(generated_ids),
            prompt_tokens=input_token_count,
            output_tokens=generated_ids.shape[-1],
            timings=timings,
        )


def get_requested_model(http_request: Request, model_name: str) -> HFTransformer:
    normalized_model_name = model_name.strip()
    if not normalized_model_name:
        raise HTTPException(status_code=422, detail="`model` cannot be empty.")

    try:
        return http_request.app.state.get_model(normalized_model_name)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to load Hugging Face model `{normalized_model_name}`: {exc}",
        ) from exc


def run_openai_compatible_generation(
    http_request: Request, payload: ResponsesCreateRequest
) -> ResponsesCreateResponse:
    if payload.stream:
        raise HTTPException(status_code=501, detail="Streaming is not supported by this local implementation.")

    prompt = build_prompt(payload)
    max_output_tokens = payload.max_output_tokens or 64
    generation = get_requested_model(http_request, payload.model).generate_with_metadata(
        prompt,
        max_new_tokens=max_output_tokens,
        temperature=payload.temperature,
        top_p=payload.top_p,
    )
    response_metadata = dict(payload.metadata)
    generation_timings = generation.timings.as_dict()
    generation_timings["backend"] = "hf_transformers"
    generation_timings["hf_generate_ms"] = generation_timings["total_ms"]
    response_metadata["generation_timings"] = generation_timings

    now = int(time.time())
    return ResponsesCreateResponse(
        id=f"resp_{uuid4().hex}",
        created_at=now,
        completed_at=now,
        instructions=payload.instructions,
        max_output_tokens=payload.max_output_tokens,
        model=payload.model,
        output=[
            OutputMessage(
                id=f"msg_{uuid4().hex}",
                content=[OutputTextPart(text=generation.output_text)],
            )
        ],
        parallel_tool_calls=payload.parallel_tool_calls,
        previous_response_id=payload.previous_response_id,
        store=payload.store,
        temperature=payload.temperature if payload.temperature is not None else 1.0,
        text=payload.text,
        tool_choice=payload.tool_choice,
        tools=payload.tools,
        top_p=payload.top_p if payload.top_p is not None else 1.0,
        truncation=payload.truncation,
        usage=Usage(
            input_tokens=generation.prompt_tokens,
            input_tokens_details=InputTokensDetails(),
            output_tokens=generation.output_tokens,
            output_tokens_details=OutputTokensDetails(),
            total_tokens=generation.prompt_tokens + generation.output_tokens,
        ),
        user=payload.user,
        metadata=response_metadata,
    )


def generate_completion_choices(
    http_request: Request, request: CompletionsCreateRequest
) -> tuple[list[CompletionChoice], CompletionUsage]:
    model = get_requested_model(http_request, request.model)
    prompts = normalize_completion_prompts(request.prompt, model)
    max_output_tokens = request.max_tokens or 64

    choices: list[CompletionChoice] = []
    total_input_tokens = 0
    total_output_tokens = 0
    choice_index = 0

    for prompt in prompts:
        for _ in range(request.n):
            generation = model.generate_with_metadata(
                prompt,
                max_new_tokens=max_output_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
            )
            text = generation.output_text if request.suffix is None else f"{generation.output_text}{request.suffix}"
            choices.append(CompletionChoice(text=text, index=choice_index))
            total_input_tokens += generation.prompt_tokens
            total_output_tokens += generation.output_tokens
            choice_index += 1

    return choices, CompletionUsage(
        prompt_tokens=total_input_tokens,
        completion_tokens=total_output_tokens,
        total_tokens=total_input_tokens + total_output_tokens,
    )


def run_legacy_completion(http_request: Request, request: CompletionsCreateRequest) -> CompletionsCreateResponse:
    choices, usage = generate_completion_choices(http_request, request)
    now = int(time.time())
    return CompletionsCreateResponse(
        id=f"cmpl_{uuid4().hex}",
        created=now,
        model=request.model,
        choices=choices,
        usage=usage,
    )


def stream_legacy_completion(http_request: Request, request: CompletionsCreateRequest) -> StreamingResponse:
    choices, _ = generate_completion_choices(http_request, request)
    completion_id = f"cmpl_{uuid4().hex}"
    created = int(time.time())

    def event_stream():
        for choice in choices:
            chunk = {
                "id": completion_id,
                "object": "text_completion",
                "created": created,
                "model": request.model,
                "usage": None,
                "choices": [
                    {
                        "text": choice.text,
                        "index": choice.index,
                        "logprobs": None,
                        "finish_reason": None,
                    }
                ],
            }
            yield f"data: {json.dumps(chunk)}\n\n"

            stop_chunk = {
                "id": completion_id,
                "object": "text_completion",
                "created": created,
                "model": request.model,
                "usage": None,
                "choices": [
                    {
                        "text": "",
                        "index": choice.index,
                        "logprobs": None,
                        "finish_reason": "stop",
                    }
                ],
            }
            yield f"data: {json.dumps(stop_chunk)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


def build_runtime_config(config_path: str | None) -> RuntimeConfig:
    try:
        return load_runtime_config(config_path)
    except ValueError as exc:
        raise RuntimeError(str(exc)) from exc


def create_app() -> FastAPI:
    runtime_config = build_runtime_config(os.environ.get(CONFIG_PATH_ENV_VAR))
    resolved_target_device = resolve_target_device(runtime_config.target_device)
    app = FastAPI(title="HF Transformers Benchmark API")
    app.state.runtime_config = runtime_config
    app.state.resolved_target_device = str(resolved_target_device)

    @lru_cache
    def get_model(model_name: str) -> HFTransformer:
        return HFTransformer(
            model_name=model_name,
            use_kv_cache=runtime_config.kv_cache,
            target_device=runtime_config.target_device,
        )

    app.state.get_model = get_model

    @app.get("/healthz")
    def healthz():
        return {
            "status": "ok",
            "backend": "hf_transformers",
            "kv_cache": runtime_config.kv_cache,
            "target_device": runtime_config.target_device,
            "resolved_target_device": app.state.resolved_target_device,
        }

    @app.post("/v1/responses", response_model=ResponsesCreateResponse)
    @app.post("/generate", response_model=ResponsesCreateResponse, include_in_schema=False)
    async def generate(http_request: Request, request: ResponsesCreateRequest):
        return await run_in_threadpool(run_openai_compatible_generation, http_request, request)

    @app.post("/v1/completions", response_model=CompletionsCreateResponse)
    async def completions(http_request: Request, request: CompletionsCreateRequest):
        if request.stream:
            return stream_legacy_completion(http_request, request)
        return await run_in_threadpool(run_legacy_completion, http_request, request)

    return app


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the HF Transformers benchmark API server.")
    parser.add_argument("--config", help="Path to a YAML runtime config file.", default=None)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8001)
    parser.add_argument("--reload", action="store_true")
    return parser.parse_args()


app = create_app()


if __name__ == "__main__":
    args = parse_args()
    if args.config is not None:
        os.environ[CONFIG_PATH_ENV_VAR] = str(Path(args.config).expanduser().resolve())

    uvicorn.run("hf_server:create_app", factory=True, host=args.host, port=args.port, reload=args.reload)
