import argparse

import torch

from model import GPT2, GenerationResult


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate text and report prefill/decode timings.")
    parser.add_argument("--prompt", default=None, help="Prompt to generate from. If omitted, prompt interactively.")
    parser.add_argument(
        "--model-name",
        default="openai-community/gpt2",
        help="Hugging Face model name to load for generation.",
    )
    parser.add_argument("--max-new-tokens", type=int, default=500)
    parser.add_argument("--no-kv-cache", action="store_true", help="Disable the KV cache for this run.")
    parser.add_argument(
        "--compare-kv-cache",
        action="store_true",
        help="Run the same prompt once with the KV cache enabled and once without it.",
    )
    parser.add_argument("--seed", type=int, default=0, help="Seed used before each generation run.")
    return parser.parse_args()


def resolve_prompt(prompt_arg: str | None) -> str:
    if prompt_arg is not None:
        prompt = prompt_arg.strip()
    else:
        prompt = input("Prompt: ").strip()

    if not prompt:
        raise SystemExit("Prompt cannot be empty.")

    return prompt


def seed_generation(seed: int):
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def run_generation(
    prompt: str,
    *,
    model_name: str,
    use_kv_cache: bool,
    max_new_tokens: int,
    seed: int,
) -> GenerationResult:
    seed_generation(seed)
    model = GPT2(model_name=model_name, use_kv_cache=use_kv_cache)
    return model.generate_with_metadata(prompt, max_new_tokens=max_new_tokens)


def print_summary(label: str, result: GenerationResult):
    timings = result.timings.as_dict()
    print(label)
    print(f"Prompt tokens: {result.prompt_tokens}")
    print(f"Output tokens: {result.output_tokens}")
    print(
        f"Prefill: {timings['prefill_ms']:.3f} ms across {timings['prefill_calls']} call(s) "
        f"(avg {timings['average_prefill_ms']:.3f} ms)"
    )
    print(
        f"Decode: {timings['decode_ms']:.3f} ms across {timings['decode_calls']} call(s) "
        f"(avg {timings['average_decode_ms']:.3f} ms)"
    )
    print(f"Measured total: {timings['total_ms']:.3f} ms")


def main():
    args = parse_args()
    prompt = resolve_prompt(args.prompt)

    if args.compare_kv_cache:
        cached_result = run_generation(
            prompt,
            model_name=args.model_name,
            use_kv_cache=True,
            max_new_tokens=args.max_new_tokens,
            seed=args.seed,
        )
        uncached_result = run_generation(
            prompt,
            model_name=args.model_name,
            use_kv_cache=False,
            max_new_tokens=args.max_new_tokens,
            seed=args.seed,
        )

        print(cached_result.full_text)
        print()
        print_summary("KV cache enabled", cached_result)
        print()
        print_summary("KV cache disabled", uncached_result)

        cached_total_ms = cached_result.timings.total_ms
        uncached_total_ms = uncached_result.timings.total_ms
        if cached_total_ms > 0:
            print()
            print(f"KV cache speedup vs uncached: {uncached_total_ms / cached_total_ms:.3f}x")
        if cached_result.full_text != uncached_result.full_text:
            print("Warning: cached and uncached generations produced different text for the same seed.")
        return

    result = run_generation(
        prompt,
        model_name=args.model_name,
        use_kv_cache=not args.no_kv_cache,
        max_new_tokens=args.max_new_tokens,
        seed=args.seed,
    )
    print(result.full_text)
    print()
    print_summary("Generation timings", result)


if __name__ == "__main__":
    main()
