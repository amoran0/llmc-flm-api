#!/usr/bin/env python3
"""
Mock LLaMA.cpp server — responds to POST /v1/chat/completions
with a realistic llama.cpp-shaped JSON (timings block) so that
benchmark.sh / stats_LLAMACPP() parses it correctly.

Responses use pyquotegen.get_quote() as the generated content.

Usage:
    pip install pyquotegen
    python mock/mock_llamacpp_server.py

    # in another terminal:
    HOST_LLAMACPP=http://localhost:4000/v1/chat/completions \
    MODELS_FLM="" \
    ./scripts/benchmark.sh
"""

import json
import random
import time
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer

import pyquotegen

HOST = "localhost"
PORT = 4000


def fake_timings(prompt_text: str) -> dict:
    """Return realistic-looking llama.cpp timing values."""
    prompt_n        = random.randint(8, 60)
    prompt_ms       = round(random.uniform(80, 400), 2)
    prompt_per_sec  = round(prompt_n / (prompt_ms / 1000), 2)

    predicted_n     = random.randint(40, 180)
    predicted_ms    = round(random.uniform(500, 4000), 2)
    predicted_per_sec = round(predicted_n / (predicted_ms / 1000), 2)

    return {
        "prompt_n":          prompt_n,
        "prompt_ms":         prompt_ms,
        "prompt_per_second": prompt_per_sec,
        "predicted_n":       predicted_n,
        "predicted_ms":      predicted_ms,
        "predicted_per_second": predicted_per_sec,
    }


def build_response(model: str, prompt_text: str) -> dict:
    quote   = pyquotegen.get_quote()          # correct public API
    timings = fake_timings(prompt_text)

    return {
        "id":      f"cmpl-{uuid.uuid4().hex[:12]}",
        "object":  "chat.completion",
        "created": int(time.time()),
        "model":   model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role":    "assistant",
                    "content": quote,
                },
                "finish_reason": "stop",
            }
        ],
        # llama.cpp puts timing data at the root level under "timings"
        "timings": timings,
    }


class LlamaCppHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # noqa: N802 – suppress default access log
        print(f"[mock] {self.address_string()} {fmt % args}")

    def do_POST(self):  # noqa: N802
        if self.path != "/v1/chat/completions":
            self.send_error(404, "Not found")
            return

        length  = int(self.headers.get("Content-Length", 0))
        raw     = self.rfile.read(length)

        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        model       = body.get("model", "unknown")
        messages    = body.get("messages", [])
        prompt_text = messages[-1].get("content", "") if messages else ""

        response_body = build_response(model, prompt_text)
        payload       = json.dumps(response_body).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

        # print a summary to stdout for quick visual check
        t = response_body["timings"]
        print(
            f"[mock] model={model!r} "
            f"prompt={t['prompt_n']}tok/{t['prompt_ms']}ms "
            f"gen={t['predicted_n']}tok/{t['predicted_ms']}ms"
        )


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), LlamaCppHandler)
    print(f"[mock] LLaMA.cpp mock listening on http://{HOST}:{PORT}")
    print("[mock] Press Ctrl-C to stop.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[mock] Stopped.")

