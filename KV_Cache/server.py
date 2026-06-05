# Very simple implementation of the OpenAI compatible endpoints for testing purposes only, not close to being a complete implementation.

import argparse
from functools import lru_cache
import json
import os
from pathlib import Path
import time
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, ConfigDict, Field
import uvicorn

from config import CONFIG_PATH_ENV_VAR, RuntimeConfig, load_runtime_config
from device import resolve_target_device
from model import GPT2


class ResponsesCreateRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str
    input: str | list[dict[str, Any]] | None = None
    instructions: str | None = None
    max_output_tokens: int | None = Field(default=None, ge=1, le=512)
    temperature: float | None = None
    top_p: float | None = None
    stream: bool = False
    store: bool = True
    metadata: dict[str, Any] = Field(default_factory=dict)
    parallel_tool_calls: bool = True
    previous_response_id: str | None = None
    truncation: str = "disabled"
    text: dict[str, Any] = Field(default_factory=lambda: {"format": {"type": "text"}})
    tool_choice: str | dict[str, Any] = "auto"
    tools: list[dict[str, Any]] = Field(default_factory=list)
    user: str | None = None


class CompletionsCreateRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str
    prompt: Any
    max_tokens: int | None = Field(default=None, ge=1, le=512)
    temperature: float | None = None
    top_p: float | None = None
    n: int = Field(default=1, ge=1, le=8)
    stream: bool = False
    suffix: str | None = None
    user: str | None = None


class OutputTextPart(BaseModel):
    type: str = "output_text"
    text: str
    annotations: list[dict[str, Any]] = Field(default_factory=list)


class OutputMessage(BaseModel):
    type: str = "message"
    id: str
    status: str = "completed"
    role: str = "assistant"
    content: list[OutputTextPart]


class InputTokensDetails(BaseModel):
    cached_tokens: int = 0


class OutputTokensDetails(BaseModel):
    reasoning_tokens: int = 0


class Usage(BaseModel):
    input_tokens: int
    input_tokens_details: InputTokensDetails
    output_tokens: int
    output_tokens_details: OutputTokensDetails
    total_tokens: int


class Reasoning(BaseModel):
    effort: str | None = None
    summary: str | None = None


class CompletionChoice(BaseModel):
    text: str
    index: int = 0
    logprobs: None = None
    finish_reason: str = "stop"


class CompletionUsage(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class ResponsesCreateResponse(BaseModel):
    id: str
    object: str = "response"
    created_at: int
    status: str = "completed"
    completed_at: int
    error: None = None
    incomplete_details: None = None
    instructions: str | None = None
    max_output_tokens: int | None = None
    model: str
    output: list[OutputMessage]
    parallel_tool_calls: bool = True
    previous_response_id: str | None = None
    reasoning: Reasoning = Field(default_factory=Reasoning)
    store: bool = True
    temperature: float | None = None
    text: dict[str, Any] = Field(default_factory=lambda: {"format": {"type": "text"}})
    tool_choice: str | dict[str, Any] = "auto"
    tools: list[dict[str, Any]] = Field(default_factory=list)
    top_p: float | None = None
    truncation: str = "disabled"
    usage: Usage
    user: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class CompletionsCreateResponse(BaseModel):
    id: str
    object: str = "text_completion"
    created: int
    model: str
    choices: list[CompletionChoice]
    usage: CompletionUsage


def extract_text_from_input_item(item: Any) -> str:
    if isinstance(item, str):
        return item
    if isinstance(item, list):
        return "\n".join(filter(None, (extract_text_from_input_item(part) for part in item)))
    if not isinstance(item, dict):
        return ""

    if "text" in item and isinstance(item["text"], str):
        return item["text"]

    content = item.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(filter(None, (extract_text_from_input_item(part) for part in content)))

    return ""


def build_prompt(request: ResponsesCreateRequest) -> str:
    prompt_parts: list[str] = []
    if request.instructions:
        prompt_parts.append(request.instructions)

    if isinstance(request.input, str):
        prompt_parts.append(request.input)
    elif isinstance(request.input, list):
        prompt_parts.extend(filter(None, (extract_text_from_input_item(item) for item in request.input)))

    prompt = "\n\n".join(part.strip() for part in prompt_parts if part and part.strip())
    if not prompt:
        raise HTTPException(status_code=422, detail="A text `input` or `instructions` value is required.")

    return prompt


def get_requested_model(http_request: Request, model_name: str) -> GPT2:
    normalized_model_name = model_name.strip()
    if not normalized_model_name:
        raise HTTPException(status_code=422, detail="`model` cannot be empty.")

    try:
        return http_request.app.state.get_model(normalized_model_name)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to load model `{normalized_model_name}`: {exc}",
        ) from exc


def new_generation_request_id() -> str:
    return f"req_{uuid4().hex}"


def run_openai_compatible_generation(
    http_request: Request, payload: ResponsesCreateRequest
) -> ResponsesCreateResponse:
    if payload.stream:
        raise HTTPException(status_code=501, detail="Streaming is not supported by this local implementation.")

    prompt = build_prompt(payload)
    max_output_tokens = payload.max_output_tokens or 64
    request_id = new_generation_request_id()
    generation = get_requested_model(http_request, payload.model).generate_with_metadata(
        prompt,
        max_new_tokens=max_output_tokens,
        request_id=request_id,
    )
    response_metadata = dict(payload.metadata)
    response_metadata["generation_timings"] = generation.timings.as_dict()

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


def normalize_completion_prompts(prompt: Any, model: GPT2) -> list[str]:
    if isinstance(prompt, str):
        return [prompt]

    if isinstance(prompt, list):
        if all(isinstance(item, str) for item in prompt):
            return prompt

        if all(isinstance(item, int) for item in prompt):
            return [model.tokenizer.decode(prompt)]

        if all(isinstance(item, list) and all(isinstance(token, int) for token in item) for item in prompt):
            return [model.tokenizer.decode(item) for item in prompt]

    raise HTTPException(status_code=422, detail="Unsupported prompt format for this local completion endpoint.")


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
            request_id = new_generation_request_id()
            generation = model.generate_with_metadata(
                prompt,
                max_new_tokens=max_output_tokens,
                request_id=request_id,
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
    app = FastAPI(title="KV Cache API")
    app.state.runtime_config = runtime_config
    app.state.resolved_target_device = str(resolved_target_device)

    @lru_cache
    def get_model(model_name: str) -> GPT2:
        return GPT2(
            model_name=model_name,
            use_kv_cache=runtime_config.kv_cache,
            target_device=runtime_config.target_device,
        )

    app.state.get_model = get_model

    @app.get("/healthz")
    def healthz():
        return {
            "status": "ok",
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
    parser = argparse.ArgumentParser(description="Run the KV Cache API server.")
    parser.add_argument("--config", help="Path to a YAML runtime config file.", default=None)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--reload", action="store_true")
    return parser.parse_args()


app = create_app()


if __name__ == "__main__":
    args = parse_args()
    if args.config is not None:
        os.environ[CONFIG_PATH_ENV_VAR] = str(Path(args.config).expanduser().resolve())

    uvicorn.run("server:create_app", factory=True, host=args.host, port=args.port, reload=args.reload)
