import json
import os
import subprocess
import tempfile
from pathlib import Path

from behave import given, when, then, register_type
from parse import with_pattern


@with_pattern(r'.*')
def parse_text(text):
    return text


register_type(TEXT=parse_text)


def _read_jsonl(path):
    if not path.exists():
        return []
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    return [json.loads(line) for line in lines]


@given('a list of llama.cpp models "{models:TEXT}"')
def step_llama_models(context, models):
    context.llama_models = models


@given('a prompt "{prompt:TEXT}"')
def step_prompt(context, prompt):
    context.prompt = prompt


@when("I run the benchmark script")
def step_run_script(context):
    repo_root = Path(__file__).resolve().parents[2]

    script_relpath = os.environ.get("BENCHMARK_SCRIPT", "scripts/benchmark.sh")
    script_path = repo_root / script_relpath

    temp_dir = Path(tempfile.mkdtemp(prefix="behave-benchmark-"))
    logs_dir = temp_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["HOME"] = str(temp_dir)
    env["MODELS_LLAMACPP"] = getattr(
        context,
        "llama_models",
        "glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-moe lfm2.5-1.2b-q8-k-xl",
    )
    env["PROMPT"] = getattr(
        context,
        "prompt",
        "write a terraform snippet that deploys an ec2 instance",
    )
    env["HOST_LLAMACPP"] = "http://localhost:4000/v1/chat/completions"

    if script_path.suffix == ".py":
        command = ["python3", str(script_path)]
    else:
        command = ["bash", str(script_path)]

    context.result = subprocess.run(
        command,
        cwd=repo_root,
        env=env,
        capture_output=True,
        text=True,
    )

    context.llama_log = logs_dir / "benchmark_LLAMACPP.jsonl"

    assert context.result.returncode == 0, (
        f"{script_relpath} failed\nSTDOUT:\n{context.result.stdout}\nSTDERR:\n{context.result.stderr}"
    )


@then('the llama.cpp benchmark log should contain {count:d} correctly formatted entries')
@then('the llama.cpp benchmark log should contain {count:d} correctly formatted entry')
def step_verify_llama_log(context, count):
    entries = _read_jsonl(context.llama_log)
    assert len(entries) == count, f"Expected {count} llama.cpp entries, got {len(entries)}"

    for entry in entries:
        assert entry["model"] 
        assert entry["server"] == "LLaMACPP"
        assert isinstance(entry["input_prompt"], str)
        assert isinstance(entry["prompt_token_count"], (int, float))
        assert isinstance(entry["prompt_processing_time_ms"], (int, float))
        assert isinstance(entry["generated_token_count"], (int, float))
        #assert isinstance(entry["prompt_tokens_per_second"], (int, float))
        assert isinstance(entry["generation_time_ms"], (int, float))
        assert isinstance(entry["generated_tokens_per_second"], (int, float))    



@then('every benchmark log entry should include the prompt "{prompt:TEXT}"')
def step_verify_prompt(context, prompt):
    entries = _read_jsonl(context.llama_log)

    assert entries, "Expected at least one logged benchmark entry"

    for entry in entries:
        assert entry["input_prompt"] == prompt

@then("each llama.cpp benchmark log entry should contain all required fields and non-empty values")
def step_validate_llama_log_fields(context):
    entries = _read_jsonl(context.llama_log)

    assert entries, "Expected at least one llama.cpp benchmark log entry"

    for entry in entries:
        assert "model" in entry, "Missing field 'model'"
        assert entry["model"] is not None, "Field 'model' must not be None"
        assert isinstance(entry["model"], str), "Field 'model' must be a string"
        assert entry["model"].strip(), "Field 'model' must not be empty"

        assert "server" in entry, "Missing field 'server'"
        assert entry["server"] is not None, "Field 'server' must not be None"
        assert isinstance(entry["server"], str), "Field 'server' must be a string"
        assert entry["server"].strip(), "Field 'server' must not be empty"

        assert "input_prompt" in entry, "Missing field 'input_prompt'"
        assert entry["input_prompt"] is not None, "Field 'input_prompt' must not be None"
        assert isinstance(entry["input_prompt"], str), "Field 'input_prompt' must be a string"
        assert entry["input_prompt"].strip(), "Field 'input_prompt' must not be empty"

        assert "prompt_token_count" in entry, "Missing field 'prompt_token_count'"
        assert entry["prompt_token_count"] is not None, "Field 'prompt_token_count' must not be None"
        assert isinstance(entry["prompt_token_count"], (int, float)), "Field 'prompt_token_count' must be numeric"

        assert "prompt_processing_time_ms" in entry, "Missing field 'prompt_processing_time_ms'"
        assert entry["prompt_processing_time_ms"] is not None, "Field 'prompt_processing_time_ms' must not be None"
        assert isinstance(entry["prompt_processing_time_ms"], (int, float)), "Field 'prompt_processing_time_ms' must be numeric"
        
        assert "generated_token_count" in entry, "Missing field 'generated_token_count'"
        assert entry["generated_token_count"] is not None, "Field 'generated_token_count' must not be None"
        assert isinstance(entry["generated_token_count"], (int, float)), "Field 'generated_token_count' must be numeric"

        assert "generation_time_ms" in entry, "Missing field 'generation_time_ms'"
        assert entry["generation_time_ms"] is not None, "Field 'generation_time_ms' must not be None"
        assert isinstance(entry["generation_time_ms"], (int, float)), "Field 'generation_time_ms' must be numeric"

        assert "generated_tokens_per_second" in entry, "Missing field 'generated_tokens_per_second'"
        assert entry["generated_tokens_per_second"] is not None, "Field 'generated_tokens_per_second' must not be None"
        assert isinstance(entry["generated_tokens_per_second"], (int, float)), "Field 'generated_tokens_per_second' must be numeric"
