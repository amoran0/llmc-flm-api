import json
import os
from pathlib import Path

import requests


HOST_LLAMACPP = os.environ.get(
    "HOST_LLAMACPP",
    "http://localhost:4000/v1/chat/completions",
)
HOST_FLM = os.environ.get(
    "HOST_FLM",
    "http://localhost:4000/v1/chat/completions",
)
PROMPT = os.environ.get(
    "PROMPT",
    "write a terraform snippet that deploys an ec2 instance",
)


def get_models(env_name, default_models):
    if env_name not in os.environ:
        print(f"{env_name} is unset, using default models")
        return default_models

    value = os.environ.get(env_name, "")
    if value == "":
        print(f"{env_name} is set but empty, no models will be tested")
        return []

    return value.split()


def append_jsonl(path, entry):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


def log_flmserver(model, response, prompt, log_path):
    usage = response.get("usage", {})

    prompt_token_count = float(usage.get("prompt_tokens", 0))
    generated_token_count = float(usage.get("completion_tokens", 0))
    prompt_processing_time_ms = float(usage.get("prefill_duration_ttft", 0))
    generation_time_ms = float(usage.get("decoding_duration", 0))
    prompt_tokens_per_second = float(usage.get("prefill_speed_tps", 0))
    generated_tokens_per_second = float(usage.get("decoding_speed_tps", 0))

    print(f"= FLMServer ({model}) =")
    print(f"Prompt: {prompt}")
    print(
        f"Prompt processing:     {prompt_token_count} tokens in "
        f"{prompt_processing_time_ms}ms ({prompt_tokens_per_second} t/s)"
    )
    print(
        f"Generation: {generated_token_count} tokens in "
        f"{generation_time_ms}ms ({generated_tokens_per_second} t/s)"
    )
    print()

    append_jsonl(
        log_path,
        {
            "model": f"FLMServer ({model})",
            "server": "FLMServer",
            "input_prompt": prompt,
            "prompt_token_count": prompt_token_count,
            "prompt_processing_time_ms": prompt_processing_time_ms,
            "prompt_tokens_per_second": prompt_tokens_per_second,
            "generated_token_count": generated_token_count,
            "generation_time_ms": generation_time_ms,
            "generated_tokens_per_second": generated_tokens_per_second,
        },
    )


def log_llamacpp(model, response, prompt, log_path):
    timings = response.get("timings", {})

    prompt_token_count = float(timings.get("prompt_n", 0))
    prompt_processing_time_ms = float(timings.get("prompt_ms", 0))
    prompt_tokens_per_second = float(timings.get("prompt_per_second", 0))
    generated_token_count = float(timings.get("predicted_n", 0))
    generation_time_ms = float(timings.get("predicted_ms", 0))
    generated_tokens_per_second = float(timings.get("predicted_per_second", 0))

    print(f"= LLaMACPP ({model}) =")
    print(f"Prompt: {prompt}")
    print(
        f"Prompt processing:     {prompt_token_count} tokens in "
        f"{prompt_processing_time_ms}ms ({prompt_tokens_per_second} t/s)"
    )
    print(
        f"Generation: {generated_token_count} tokens in "
        f"{generation_time_ms}ms ({generated_tokens_per_second} t/s)"
    )
    print()

    append_jsonl(
        log_path,
        {
            "model": f"LLaMACPP ({model})",
            "server": "LLaMACPP",
            "input_prompt": prompt,
            "prompt_token_count": prompt_token_count,
            "prompt_processing_time_ms": prompt_processing_time_ms,
            "prompt_tokens_per_second": prompt_tokens_per_second,
            "generated_token_count": generated_token_count,
            "generation_time_ms": generation_time_ms,
            "generated_tokens_per_second": generated_tokens_per_second,
        },
    )


def post_json(url, payload):
    response = requests.post(url, json=payload, timeout=300)
    response.raise_for_status()
    return response.json()


def main():
    models_flm = get_models(
        "MODELS_FLM",
        ["deepseek-r1:8b", "gpt-oss:20b", "llama3.1:8b", "qwen3.5:9b"],
    )
    models_llamacpp = get_models(
        "MODELS_LLAMACPP",
        [
            "glm-4.7-flash",
            "qwen3-coder-next",
            "gpt-oss-20b-q4-k-m",
            "gpt-oss-120b",
            "gpt-oss-120b-high",
            "lfm2-24b-a2b-mxfp4-moe",
            "lfm2.5-1.2b-q8-k-xl",
        ],
    )

    print("models flm:", " ".join(models_flm))
    print("models llama:", " ".join(models_llamacpp))

    flm_log = Path.home() / "logs" / "benchmark_FLMSERVER.jsonl"
    llama_log = Path.home() / "logs" / "benchmark_LLAMACPP.jsonl"

    print("= FLMServer =")
    for model in models_flm:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": PROMPT}],
        }
        response = post_json(HOST_FLM, payload)
        log_flmserver(model, response, PROMPT, flm_log)

    print("= LLaMACPP =")
    for model in models_llamacpp:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": PROMPT}],
        }
        response = post_json(HOST_LLAMACPP, payload)
        log_llamacpp(model, response, PROMPT, llama_log)


if __name__ == "__main__":
    main()
