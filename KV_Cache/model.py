from dataclasses import dataclass
import math
import time
from typing import Callable, Dict

import torch
import torch.nn.functional as F
from transformers import AutoModelForCausalLM, AutoTokenizer


@dataclass
class WeightsAndBiases:
    weights: torch.Tensor
    bias: torch.Tensor


@dataclass
class GenerationResult:
    full_text: str
    output_text: str
    prompt_tokens: int
    output_tokens: int
    timings: "GenerationTimings"


@dataclass
class GenerationTimings:
    prefill_ms: float = 0.0
    decode_ms: float = 0.0
    prefill_calls: int = 0
    decode_calls: int = 0

    @property
    def total_ms(self) -> float:
        return self.prefill_ms + self.decode_ms

    def as_dict(self) -> dict[str, float | int]:
        average_prefill_ms = self.prefill_ms / self.prefill_calls if self.prefill_calls else 0.0
        average_decode_ms = self.decode_ms / self.decode_calls if self.decode_calls else 0.0
        return {
            "prefill_ms": self.prefill_ms,
            "decode_ms": self.decode_ms,
            "total_ms": self.total_ms,
            "prefill_calls": self.prefill_calls,
            "decode_calls": self.decode_calls,
            "average_prefill_ms": average_prefill_ms,
            "average_decode_ms": average_decode_ms,
        }


def resolve_target_device(target_device: str) -> str:
    normalized_device = target_device.strip().lower()

    if normalized_device == "auto":
        if torch.cuda.is_available():
            return "cuda"
        if torch.backends.mps.is_available():
            return "mps"
        return "cpu"

    if normalized_device == "cpu":
        return "cpu"

    if normalized_device == "mps":
        if not torch.backends.mps.is_available():
            raise ValueError("target_device `mps` was requested, but MPS is not available.")
        return "mps"

    if normalized_device == "cuda" or normalized_device.startswith("cuda:"):
        if not torch.cuda.is_available():
            raise ValueError(f"target_device `{normalized_device}` was requested, but CUDA is not available.")
        return normalized_device

    raise ValueError(f"Unsupported target_device `{target_device}`. Use auto, cpu, mps, cuda, or cuda:N.")


def synchronize_device(device: str):
    if device.startswith("cuda"):
        torch.cuda.synchronize(device=device)
        return

    if device == "mps" and hasattr(torch, "mps") and torch.backends.mps.is_available():
        torch.mps.synchronize()


def measure_inference_ms(operation: Callable[[], torch.Tensor], device: str) -> tuple[torch.Tensor, float]:
    synchronize_device(device)
    started_at = time.perf_counter()
    output = operation()
    synchronize_device(device)
    elapsed_ms = (time.perf_counter() - started_at) * 1000
    return output, elapsed_ms


def layer_norm(activations: torch.Tensor, ln: WeightsAndBiases):
    eps = 1e-05
    mean = activations.mean(dim=-1, keepdim=True)
    variance = ((activations - mean) ** 2).mean(dim=-1, keepdim=True)
    normalized = (activations - mean) / (variance + eps).sqrt()
    return ln.weights * normalized + ln.bias


class GPT2:
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
        pretrained_model = AutoModelForCausalLM.from_pretrained(model_name)
        pretrained_model = pretrained_model.to(device=self.device)
        pretrained_model.eval()
        self.state = pretrained_model.state_dict()
        config = pretrained_model.config
        self.embedding_dim = config.n_embd
        transformer_layers = config.n_layer
        self.n_positions = config.n_positions
        self.transformer_blocks = [Transformer(self.state, layer_id, self.device, config.n_head) for layer_id in range(transformer_layers)]

    def poll_token_from_logits(self, logits: torch.Tensor):
        if logits.ndim > 1:
            logits = logits[-1]
        return F.softmax(logits, dim=-1).multinomial(num_samples=1)


    def prefill(self, input_tokens: torch.Tensor, kv_cache: torch.Tensor | None = None):
        token_embeddings = self.state["transformer.wte.weight"][input_tokens]
        positional_embeddings = self.state["transformer.wpe.weight"][:input_tokens.shape[0]]
        hs = token_embeddings + positional_embeddings

        for transformer_block in self.transformer_blocks:
            hs = transformer_block.prefill(hs, kv_cache)


        hs = layer_norm(
            hs,
            WeightsAndBiases(
                weights=self.state["transformer.ln_f.weight"],
                bias=self.state["transformer.ln_f.bias"],
            ),
        )
        logits = hs @ self.state["lm_head.weight"].T

        return logits

    def decode(self, next_token: torch.Tensor, position: int, kv_cache: torch.Tensor):
        token_embedding = self.state["transformer.wte.weight"][next_token]
        positional_embedding = self.state["transformer.wpe.weight"][position]

        hs = token_embedding + positional_embedding
        for transformer_block in self.transformer_blocks:
            hs = transformer_block.decode(hs, kv_cache, position)

        hs = layer_norm(
            hs,
            WeightsAndBiases(
                weights=self.state["transformer.ln_f.weight"],
                bias=self.state["transformer.ln_f.bias"],
            ),
        )
        logits = hs @ self.state["lm_head.weight"].T

        return logits

    def generate(self, prompt: str, max_new_tokens: int = 64, request_id: str = ""):
        return self.generate_with_metadata(
            prompt,
            max_new_tokens=max_new_tokens,
            request_id=request_id,
        ).full_text

    def generate_with_metadata(self, prompt: str, max_new_tokens: int = 64, request_id: str = "") -> GenerationResult:
        input_tokens = self.tokenizer(prompt, return_tensors="pt").to(self.device).input_ids.squeeze(0)
        max_total_tokens = min(1024, input_tokens.shape[0] + max_new_tokens)
        all_tokens = input_tokens
        timings = GenerationTimings()


        with torch.no_grad():
            kv_cache = None
            if self.use_kv_cache:
                kv_cache = self.state["transformer.wte.weight"].new_empty(
                    (max_total_tokens, len(self.transformer_blocks), self.embedding_dim * 2)
                )
            while all_tokens.shape[0] < max_total_tokens:
                if self.use_kv_cache:
                    if all_tokens.shape[0] == input_tokens.shape[0]:
                        logits, prefill_ms = measure_inference_ms(
                            lambda: self.prefill(all_tokens, kv_cache), self.device
                        )
                        timings.prefill_ms += prefill_ms
                        timings.prefill_calls += 1
                    else:
                        logits, decode_ms = measure_inference_ms(
                            lambda: self.decode(all_tokens[-1:], all_tokens.shape[0] - 1, kv_cache),
                            self.device,
                        )
                        timings.decode_ms += decode_ms
                        timings.decode_calls += 1
                else:
                    logits, prefill_ms = measure_inference_ms(lambda: self.prefill(all_tokens), self.device)
                    timings.prefill_ms += prefill_ms
                    timings.prefill_calls += 1

                next_token = self.poll_token_from_logits(logits)
                next_all_tokens = all_tokens.new_empty(all_tokens.shape[0] + next_token.shape[0])
                next_all_tokens[: all_tokens.shape[0]] = all_tokens
                next_all_tokens[all_tokens.shape[0] :] = next_token
                all_tokens = next_all_tokens
                if next_token.item() == self.tokenizer.eos_token_id:
                    break

            output_tokens = all_tokens[input_tokens.shape[0]:]
            return GenerationResult(
                full_text=self.tokenizer.decode(all_tokens),
                output_text=self.tokenizer.decode(output_tokens),
                prompt_tokens=input_tokens.shape[0],
                output_tokens=output_tokens.shape[0],
                timings=timings,
            )


class Transformer:
    def __init__(self, model_weights: Dict[str, torch.Tensor], transformer_layer_id: int, device: str, n_heads: int):
        self.model_weights = model_weights
        self.ln1 = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.ln_1.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.ln_1.bias"],
        )
        self.attn_head = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.attn.c_attn.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.attn.c_attn.bias"],
        )
        self.proj = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.attn.c_proj.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.attn.c_proj.bias"],
        )
        self.ln2 = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.ln_2.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.ln_2.bias"],
        )
        self.mlp = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.mlp.c_fc.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.mlp.c_fc.bias"],
        )
        self.mlp_proj = WeightsAndBiases(
            model_weights[f"transformer.h.{transformer_layer_id}.mlp.c_proj.weight"],
            model_weights[f"transformer.h.{transformer_layer_id}.mlp.c_proj.bias"],
        )
        self.n_heads = n_heads
        self.layer_id = transformer_layer_id
        self.device = device

    def attention_head(self, k: torch.Tensor, v: torch.Tensor, q: torch.Tensor):
        attention_scores = (q @ k.T) / math.sqrt(k.shape[-1])
        tokens = q.shape[0]
        mask = torch.ones(tokens, tokens, dtype=torch.bool, device=self.device).triu(diagonal=1)
        attention_scores = attention_scores.masked_fill(mask, float("-inf"))
        attention_probs = attention_scores.softmax(dim=-1)
        return attention_probs @ v

    def prefill(self, x_input: torch.Tensor, kv_cache: torch.Tensor | None = None):
        x = layer_norm(x_input, self.ln1)
        qkv = x @ self.attn_head.weights + self.attn_head.bias
        q, k, v = qkv.chunk(3, dim=-1)
        if kv_cache is not None:
            kv = torch.cat((k, v), dim=-1)
            kv_cache[: kv.shape[0], self.layer_id, :] = kv
        q_head_split = q.view(q.shape[0], self.n_heads, q.shape[-1] // self.n_heads)
        k_head_split = k.view(k.shape[0], self.n_heads, k.shape[-1] // self.n_heads)
        v_head_split = v.view(v.shape[0], self.n_heads, v.shape[-1] // self.n_heads)

        # Serial computation per head for simplicity
        head_outputs = []
        for head_i in range(self.n_heads): 
            head_out = self.attention_head(k_head_split[:,head_i, :], v_head_split[:, head_i, :], q_head_split[:, head_i, :])
            head_outputs.append(head_out)

        attention_out = torch.cat(head_outputs, dim=-1)
        attention_out = attention_out @ self.proj.weights + self.proj.bias
        attention_out = x_input + attention_out

        mlp_in = layer_norm(attention_out, self.ln2)
        mlp_out = F.gelu(mlp_in @ self.mlp.weights + self.mlp.bias)
        mlp_out = mlp_out @ self.mlp_proj.weights + self.mlp_proj.bias

        transformer_out = attention_out + mlp_out

        return transformer_out

    def decode(self, x_input: torch.Tensor, kv_cache: torch.Tensor, token_position: int):
        x = layer_norm(x_input, self.ln1)
        qkv = x @ self.attn_head.weights + self.attn_head.bias
        q, k_new_token, v_new_token = qkv.chunk(3, dim=-1)

        kv_cache[token_position : token_position + 1, self.layer_id, :] = torch.cat(
            (k_new_token, v_new_token), dim=-1
        )

        k, v = kv_cache[: token_position + 1, self.layer_id, :].chunk(2, dim=-1)

        q_head_split = q.view(q.shape[0], self.n_heads, q.shape[-1] // self.n_heads)
        k_head_split = k.view(k.shape[0], self.n_heads, k.shape[-1] // self.n_heads)
        v_head_split = v.view(v.shape[0], self.n_heads, v.shape[-1] // self.n_heads)

        # Serial computation per head for simplicity
        head_outputs = []
        for head_i in range(self.n_heads):
            head_out = self.attention_head(k_head_split[:,head_i, :], v_head_split[:, head_i, :], q_head_split[:, head_i, :])
            head_outputs.append(head_out)

        attention_out = torch.cat(head_outputs, dim=-1)
        attention_out = attention_out @ self.proj.weights + self.proj.bias
        attention_out = x_input + attention_out

        mlp_in = layer_norm(attention_out, self.ln2)
        mlp_out = F.gelu(mlp_in @ self.mlp.weights + self.mlp.bias)
        mlp_out = mlp_out @ self.mlp_proj.weights + self.mlp_proj.bias

        transformer_out = attention_out + mlp_out
        return transformer_out
