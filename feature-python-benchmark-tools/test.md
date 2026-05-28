# Mock server for local testing

## Requirements

To run the mock server, install:

```test
pyquotegen
requests
```

Install them with pip:

```bash
pip3 install requirements_test.txt
```
---

This document explains the purpose of the **mock server** included in this project.

The main idea is to provide a local test server that mimics a `/v1/chat/completions` compatible endpoint, so benchmarks and request flows can be tested without sending real requests to an external API.

---

# What was added

A new file called `mock_server.py` was created to act as a **local fake server**.

This server:

- listens for local HTTP requests
- accepts `POST` requests to `/v1/chat/completions`
- returns a response shaped like a **LLaMA.cpp** completion response
- generates simulated timing and token values
- returns sample text using `pyquotegen`

In short, it allows benchmark scripts to run **without starting a real model server** and **without calling a real API**.

---

# What it is useful for

This mock server is meant for development and testing.

It is useful when you want to:

- verify that the benchmark script works correctly
- confirm that logs are written as expected
- test the full request/response flow
- develop locally without using real inference resources
- avoid real calls to an external API
- run quick functional tests

---

# What it simulates

The mock server simulates a compatible endpoint at:

`/v1/chat/completions`

The response includes:

- an `id`
- a `model`
- a `choices` array
- a `timings` block

The `timings` block is shaped to match what `benchmark.py` and `benchmark_request.py` expect when working with a **LLaMA.cpp-style** response.

It also generates random values to simulate:

- prompt tokens
- prompt processing time
- generated tokens
- generation time
- tokens per second

This makes it possible to verify that the benchmark:
- sends requests correctly
- parses the response correctly
- prints metrics
- saves results to log files

---

# What this mock server does not do

This server **does not run real inference**.

It does not:

- load real models
- generate real LLM answers
- measure actual hardware performance
- provide real quality or speed results

Because of that, it should be treated as a **testing and development tool**, not as a real benchmark environment.

---

# How to use it

## 1. Start the mock server

```bash
python3 mock_server.py
```

By default, it listens on:

```text
http://localhost:4000
```

and responds at:

```text
http://localhost:4000/v1/chat/completions
```

## 2. Run the benchmark against the mock server

For example:

```bash
HOST_LLAMACPP=http://localhost:4000/v1/chat/completions MODELS_FLM="" python3 benchmark_request.py
```

Or with the other benchmark script:

```bash
HOST_LLAMACPP=http://localhost:4000/v1/chat/completions MODELS_FLM="" python3 benchmark.py
```

---

# What this example does

In this setup:

- `HOST_LLAMACPP` points to the local mock server
- `MODELS_FLM=""` disables FLMServer tests
- the benchmark uses only the mock server as its test backend

This lets you validate the flow without touching a real API.

---

# Recommended use case

This mock server is especially useful when someone:

- wants to try the scripts for the first time
- does not have access to a real server
- does not want to run real tests against an external API
- wants to debug the benchmark locally
- wants to verify logging and response parsing before using a real backend

---

# Summary

The goal of this mock server is to provide a **safe, fast, and local** way to test the benchmark flow without depending on real services.

It is a practical option for development and early validation, especially when real API calls are unnecessary or undesirable.
