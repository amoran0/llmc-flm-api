import json
import os
import subprocess
import tempfile
from pathlib import Path

from behave import given, when, then


def _read_jsonl(path):
    if not path.exists():
        return []
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    return [json.loads(line) for line in lines]


@given('a list of FLM models "{models}"')
def step_flm_models(context, models):
    context.flm_models = models


@given('a list of llama.cpp models "{models}"')
def step_llama_models(context, models):
    context.llama_models = models


@given('a prompt "{prompt}"')
def step_prompt(context, prompt):
    context.prompt = prompt


@when("I run the benchmark script")
def step_run_script(context):
    repo_root = Path(__file__).resolve().parents[2]
    script_path = repo_root / "scripts" / "benchmark.sh"

    temp_dir = Path(tempfile.mkdtemp(prefix="behave-benchmark-"))
    fake_bin = temp_dir / "bin"
    fake_bin.mkdir(parents=True, exist_ok=True)

    fake_curl = fake_bin / "curl"
    fake_curl.write_text(
        """#!/usr/bin/env bash
if printf '%s\n' "$@" | grep -q '52625'; then
  cat <<'EOF'
{"usage":{"prompt_tokens":12,"completion_tokens":34,"prefill_duration_ttft":56,"decoding_duration":78,"prefill_speed_tps":90,"decoding_speed_tps":12}}
EOF
else
  cat <<'EOF'
{"timings":{"prompt_n":11,"prompt_ms":22,"prompt_per_second":33,"predicted_n":44,"predicted_ms":55,"predicted_per_second":66}}
EOF
fi
"""
    )
    fake_curl.chmod(0o755)

    logs_dir = temp_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["HOME"] = str(temp_dir)
    env["PATH"] = f"{fake_bin}:{env['PATH']}"
    env["MODELS_FLM"] = getattr(context, "flm_models", "")
    env["MODELS_LLAMACPP"] = getattr(context, "llama_models", "")
    env["PROMPT"] = getattr(
        context,
        "prompt",
        "write a terraform snippet that deploys an ec2 instance",
    )
    env["HOST_FLM"] = "http://fake-flm:52625/v1/chat/completions"
    env["HOST_LLAMACPP"] = "http://fake-llama:4000/v1/chat/completions"

    context.result = subprocess.run(
        ["bash", str(script_path)],
        cwd=repo_root,
        env=env,
        capture_output=True,
        text=True,
    )

    context.flm_log = logs_dir / "benchmark_FLMSERVER.jsonl"
    context.llama_log = logs_dir / "benchmark_LLAMACPP.jsonl"

    assert context.result.returncode == 0, (
        f"benchmark.sh failed\nSTDOUT:\n{context.result.stdout}\nSTDERR:\n{context.result.stderr}"
    )


@then('the FLM benchmark log should contain {count:d} correctly formatted entries')
@then('the FLM benchmark log should contain {count:d} correctly formatted entry')
def step_verify_flm_log(context, count):
    entries = _read_jsonl(context.flm_log)
    assert len(entries) == count, f"Expected {count} FLM entries, got {len(entries)}"

    for entry in entries:
        assert entry["server"] == "FLMServer"
        assert entry["model"].startswith("FLMServer (")
        assert isinstance(entry["input_prompt"], str)
        assert isinstance(entry["prompt_token_count"], int)
        assert isinstance(entry["prompt_processing_time_ms"], int)
        assert isinstance(entry["generated_token_count"], int)
        assert isinstance(entry["generation_time_ms"], int)
        assert isinstance(entry["generated_tokens_per_second"], int)


@then('the llama.cpp benchmark log should contain {count:d} correctly formatted entries')
@then('the llama.cpp benchmark log should contain {count:d} correctly formatted entry')
def step_verify_llama_log(context, count):
    entries = _read_jsonl(context.llama_log)
    assert len(entries) == count, f"Expected {count} llama.cpp entries, got {len(entries)}"

    for entry in entries:
        assert entry["server"] == "LLaMACPP"
        assert entry["model"].startswith("LLaMACPP (")
        assert isinstance(entry["input_prompt"], str)
        assert isinstance(entry["prompt_token_count"], int)
        assert isinstance(entry["prompt_processing_time_ms"], int)
        assert isinstance(entry["generated_token_count"], int)
        assert isinstance(entry["generation_time_ms"], int)
        assert isinstance(entry["generated_tokens_per_second"], int)


@then('every benchmark log entry should include the prompt "{prompt}"')
def step_verify_prompt(context, prompt):
    flm_entries = _read_jsonl(context.flm_log)
    llama_entries = _read_jsonl(context.llama_log)
    all_entries = flm_entries + llama_entries

    assert all_entries, "Expected at least one logged benchmark entry"

    for entry in all_entries:
        assert entry["input_prompt"] == prompt
