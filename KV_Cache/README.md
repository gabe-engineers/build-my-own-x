# KV Cache API

Run the API with:

```bash
python server.py --reload
```

Run the Hugging Face Transformers baseline API on a second port with:

```bash
python hf_server.py --port 8001 --reload
```

Both servers expose the same `/v1/responses` and `/v1/completions` endpoints, so
you can benchmark your implementation on `:8000` against the HF Transformers
baseline on `:8001` with the same request body.

To provide runtime settings from YAML, pass a config file when you start the server:

```bash
python server.py --reload --config config.example.yaml
python hf_server.py --port 8001 --reload --config config.example.yaml
```

If you prefer `uvicorn` directly, use the app factory and set `KV_CACHE_CONFIG`:

```bash
KV_CACHE_CONFIG=config.example.yaml uvicorn server:create_app --factory --reload
```

The OpenAI-compatible text generation endpoint is:

```text
POST /v1/responses
```

Legacy clients can also use:

```text
POST /v1/completions
```

Example request:

```bash
curl http://127.0.0.1:8000/v1/responses \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sshleifer/tiny-gpt2",
    "input": "Tell me a short story about a cache."
  }'
```

The request `model` value is used as the Hugging Face model id to load. Loaded models are cached by id for reuse.

Example response shape:

```json
{
  "id": "resp_...",
  "object": "response",
  "status": "completed",
  "model": "local-tiny-gpt2",
  "output": [
    {
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "output_text",
          "text": "..."
        }
      ]
    }
  ]
}
```

Responses also include a `metadata.generation_timings` object with measured `prefill_ms`,
`decode_ms`, total time, and call counts.

For the HF Transformers baseline, `metadata.generation_timings.backend` is
`hf_transformers`, and `hf_generate_ms` is the measured wall-clock time around
`model.generate(...)`.

If you want to compare cached vs uncached generation directly from the CLI:

```bash
uv run python main.py --prompt "Explain KV cache in one sentence." --compare-kv-cache
```

For a single run without the cache:

```bash
uv run python main.py --prompt "Explain KV cache in one sentence." --no-kv-cache
```

Runtime config supports these keys:

```yaml
kv_cache: true
target_device: mps
```

You can also nest the same values under `model` or write `kv_cache` as a mapping:

```yaml
model:
  kv_cache:
    enabled: false
  target_device: cpu
```
