from transformers import AutoTokenizer, AutoModelForCausalLM
from typing import Dict
import torch
import torch.nn.functional as F
from dataclasses import dataclass
import os
import math

@dataclass
class WeightsAndBiases:
    weights: torch.Tensor
    bias: torch.Tensor

def layer_norm(activations: torch.Tensor, ln: WeightsAndBiases):
    eps = 1e-05
    mean = activations.mean(dim=-1, keepdim=True)
    variance = ((activations - mean) ** 2).mean(dim=-1, keepdim=True)
    normalized = (activations - mean) / torch.sqrt(variance + eps)
    return ln.weights * normalized + ln.bias

class MiniGPT2:
    def __init__(self):
        self.tokenizer = AutoTokenizer.from_pretrained("sshleifer/tiny-gpt2")
        self.state = AutoModelForCausalLM.from_pretrained("sshleifer/tiny-gpt2").state_dict()
        self.transformer_block_0 = Transformer(self.state, 0)
        self.transformer_block_1 = Transformer(self.state, 1)

    def prefill(self, input_tokens: torch.Tensor):
        token_embeddings = torch.stack([self.state["transformer.wte.weight"][t] for t in input_tokens]).squeeze(0)
        positional_embeddings = self.state['transformer.wpe.weight'][:input_tokens.shape[0]]
        hs = token_embeddings + positional_embeddings
        
        hs = self.transformer_block_0.prefill(hs)
        hs = self.transformer_block_1.prefill(hs)

        hs = layer_norm(hs, WeightsAndBiases(weights=self.state['transformer.ln_f.weight'], bias=self.state['transformer.ln_f.bias']))
        logits = hs @ self.state['lm_head.weight'].T

        next_token = torch.multinomial(F.softmax(logits[-1], dim=-1), num_samples=1)

        return next_token

    def decode(self, next_token: torch.Tensor, position: int):
        token_embedding = self.state["transformer.wte.weight"][next_token]
        positional_embedding = self.state['transformer.wpe.weight'][position]

        hs = token_embedding + positional_embedding
        hs = self.transformer_block_0.decode(hs)
        hs = self.transformer_block_1.decode(hs)

        hs = layer_norm(hs, WeightsAndBiases(weights=self.state['transformer.ln_f.weight'], bias=self.state['transformer.ln_f.bias']))
        logits = hs @ self.state['lm_head.weight'].T

        next_token = torch.multinomial(F.softmax(logits[-1], dim=-1), num_samples=1)

        return next_token
 

    def generate(self, prompt: str):
        input_tokens = self.tokenizer(prompt, return_tensors="pt").input_ids.squeeze(0)

        with torch.no_grad():
            next_token = self.prefill(input_tokens)
            full_generation = torch.cat((input_tokens, next_token), dim=0)

            while next_token.item() != self.tokenizer.eos_token_id and full_generation.shape[0] < 1024:
                next_token = self.decode(next_token, full_generation.shape[0])
                full_generation = torch.cat((full_generation, next_token), dim=0)
            
            return self.tokenizer.decode(full_generation)


class Transformer:
    def __init__(self, model_weights: Dict[str, torch.Tensor], transformer_layer_id):
        self.model_weights = model_weights
        self.ln1 = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.ln_1.weight'], model_weights[f'transformer.h.{transformer_layer_id}.ln_1.bias'])
        self.attn_head = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.attn.c_attn.weight'], model_weights[f'transformer.h.{transformer_layer_id}.attn.c_attn.bias'])
        self.proj = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.attn.c_proj.weight'], model_weights[f'transformer.h.{transformer_layer_id}.attn.c_proj.bias'])
        self.ln2 = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.ln_2.weight'], model_weights[f'transformer.h.{transformer_layer_id}.ln_2.bias'])
        self.mlp = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.mlp.c_fc.weight'], model_weights[f'transformer.h.{transformer_layer_id}.mlp.c_fc.bias'])
        self.mlp_proj = WeightsAndBiases(model_weights[f'transformer.h.{transformer_layer_id}.mlp.c_proj.weight'], model_weights[f'transformer.h.{transformer_layer_id}.mlp.c_proj.bias'])

        self.cache = {}

    def prefill(self, x_input: torch.Tensor):
        x = layer_norm(x_input, self.ln1)
        qkv = x @ self.attn_head.weights + self.attn_head.bias
        q, k, v = qkv.chunk(3, dim=-1)

        attention_scores = (q @ k.T) / math.sqrt(k.shape[-1])
        T = q.shape[0]
        mask = torch.triu(torch.ones(T, T, dtype=torch.bool), diagonal=1)
        attention_scores = attention_scores.masked_fill(mask, float("-inf"))
        attention_probs = attention_scores.softmax(dim=-1)
        attention_out = attention_probs @ v
        attention_out = attention_out @ self.proj.weights + self.proj.bias
        attention_out = x_input + attention_out

        mlp_in = layer_norm(attention_out, self.ln2)
        mlp_out = F.gelu(mlp_in @ self.mlp.weights + self.mlp.bias)
        mlp_out = mlp_out @ self.mlp_proj.weights + self.mlp_proj.bias

        transformer_out = attention_out + mlp_out

        self.cache['k'] = k
        self.cache['v'] = v

        return transformer_out

    def decode(self, x_input: torch.Tensor):
        x = layer_norm(x_input, self.ln1)
        k= self.cache['k']
        v = self.cache['v']
        qkv = x @ self.attn_head.weights + self.attn_head.bias
        q, k_new, v_new = qkv.chunk(3, dim=-1)
        k = torch.cat((k, k_new), dim=0)
        v = torch.cat((v, v_new), dim=0)

        attention_scores = (q @ k.T) / math.sqrt(k.shape[-1])
        attention_probs = attention_scores.softmax(dim=-1)
        attention_out = attention_probs @ v
        attention_out = attention_out @ self.proj.weights + self.proj.bias
        attention_out = x_input + attention_out

        mlp_in = layer_norm(attention_out, self.ln2)
        mlp_out = F.gelu(mlp_in @ self.mlp.weights + self.mlp.bias)
        mlp_out = mlp_out @ self.mlp_proj.weights + self.mlp_proj.bias

        transformer_out = attention_out + mlp_out

        self.cache['k'] = k
        self.cache['v'] = v

        return transformer_out


def main():
    prompt = input("Prompt: ")

    model = MiniGPT2()

    full_generation = model.generate(prompt)

    os.system("clear")
    print(full_generation)


if __name__ == "__main__":
    main()
