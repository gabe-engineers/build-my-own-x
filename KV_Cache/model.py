from dataclasses import dataclass
import math
from typing import Any, Dict

import torch
import torch.nn.functional as F
from transformers import AutoModelForCausalLM, AutoTokenizer

from device import get_accelerator_device
from metrics import GenerationTimings, measure_inference_ms


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
def layer_norm(activations: torch.Tensor, ln: WeightsAndBiases):
    eps = 1e-05
    mean = activations.mean(dim=-1, keepdim=True)
    variance = ((activations - mean) ** 2).mean(dim=-1, keepdim=True)
    normalized = (activations - mean) / (variance + eps).sqrt()
    return ln.weights * normalized + ln.bias


class GPT2:
    def __init__(
        self,
        model_name: str = "openai-community/gpt2",
        *,
        use_kv_cache: bool = True,
        target_device: str = "auto",
    ):
        self.use_kv_cache = use_kv_cache
        self.device = get_accelerator_device() if target_device == "auto" else target_device
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        pretrained_model: Any = AutoModelForCausalLM.from_pretrained(model_name)
        pretrained_model = pretrained_model.to(device=self.device)
        pretrained_model.eval()
        self.state = pretrained_model.state_dict()
        config = pretrained_model.config
        self.embedding_dim = config.n_embd
        transformer_layers = config.n_layer
        self.n_positions = config.n_positions
        self.transformer_blocks = [Transformer(self.state, layer_id, config.n_head) for layer_id in range(transformer_layers)]

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
        max_total_tokens = min(self.n_positions, input_tokens.shape[0] + max_new_tokens)
        all_tokens = input_tokens
        timings = GenerationTimings()


        with torch.no_grad():
            kv_cache = None
            if self.use_kv_cache:
                # Keep cached keys/values colocated with the model activations.
                kv_cache = torch.empty(
                    max_total_tokens,
                    len(self.transformer_blocks),
                    self.embedding_dim * 2,
                    device=self.device,
                    dtype=self.state["transformer.wte.weight"].dtype,
                )
            while all_tokens.shape[0] < max_total_tokens:
                if self.use_kv_cache:
                    assert kv_cache is not None
                    if all_tokens.shape[0] == input_tokens.shape[0]:
                        logits, prefill_ms = measure_inference_ms(
                            lambda: self.prefill(all_tokens, kv_cache)
                        )
                        timings.prefill_ms += prefill_ms
                        timings.prefill_calls += 1
                    else:
                        logits, decode_ms = measure_inference_ms(
                            lambda: self.decode(all_tokens[-1:], all_tokens.shape[0] - 1, kv_cache)
                        )
                        timings.decode_ms += decode_ms
                        timings.decode_calls += 1
                else:
                    logits, prefill_ms = measure_inference_ms(lambda: self.prefill(all_tokens))
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
    def __init__(self, model_weights: Dict[str, torch.Tensor], transformer_layer_id: int, n_heads: int):
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
        self.acc_device = get_accelerator_device() 

    def prefill(self, x_input: torch.Tensor, kv_cache: torch.Tensor | None = None):
        x = layer_norm(x_input, self.ln1)
        qkv = x @ self.attn_head.weights + self.attn_head.bias
        q, k, v = qkv.chunk(3, dim=-1)
        if kv_cache is not None:
            kv = torch.cat((k, v), dim=-1)
            kv_cache[: kv.shape[0], self.layer_id, :] = kv
        q_head_split = q.view(q.shape[0], self.n_heads, q.shape[-1] // self.n_heads).transpose(0,1)
        k_head_split = k.view(k.shape[0], self.n_heads, k.shape[-1] // self.n_heads).transpose(0,1)
        v_head_split = v.view(v.shape[0], self.n_heads, v.shape[-1] // self.n_heads).transpose(0,1)

        attention_scores = (q_head_split @ k_head_split.mT) / math.sqrt(k_head_split.shape[-1])
        mask = torch.ones(
            attention_scores.shape[1],
            attention_scores.shape[1],
            dtype=torch.bool,
            device=attention_scores.device,
        ).triu(diagonal=1)
        attention_scores = attention_scores.masked_fill(mask, float("-inf"))
        attention_probs = attention_scores.softmax(dim=-1)
        attention_out = attention_probs @ v_head_split

        attention_out = attention_out.transpose(0, 1).contiguous()
        attention_out = attention_out.view(attention_out.shape[0], -1)
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

        q_head_split = q.view(q.shape[0], self.n_heads, q.shape[-1] // self.n_heads).transpose(0, 1)
        k_head_split = k.view(k.shape[0], self.n_heads, k.shape[-1] // self.n_heads).transpose(0, 1)
        v_head_split = v.view(v.shape[0], self.n_heads, v.shape[-1] // self.n_heads).transpose(0, 1)

        attention_scores = (q_head_split @ k_head_split.mT) / math.sqrt(k_head_split.shape[-1])
        attention_probs = attention_scores.softmax(dim=-1)
        attention_out = attention_probs @ v_head_split

        attention_out = attention_out.transpose(0, 1).contiguous()
        attention_out = attention_out.view(attention_out.shape[0], -1)
        attention_out = attention_out @ self.proj.weights + self.proj.bias
        attention_out = x_input + attention_out

        mlp_in = layer_norm(attention_out, self.ln2)
        mlp_out = F.gelu(mlp_in @ self.mlp.weights + self.mlp.bias)
        mlp_out = mlp_out @ self.mlp_proj.weights + self.mlp_proj.bias

        transformer_out = attention_out + mlp_out
        return transformer_out
