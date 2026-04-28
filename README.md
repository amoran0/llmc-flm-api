# llmc-flm-api-reporter

Bash scripts to benchmark multiple LLM models (OpenAI-compatible `chat/completions` style), collect token/timing metrics, and render the results as terminal charts or images.

## Requirements

- `gnuplot`
- `jq`

(Chart scripts may require additional tools depending on how they render images; see each script header.)

## Project structure

- `scripts/` — main scripts you’ll run day-to-day

## Scripts

- `benchmark.sh` → runs the benchmark tests
- `results_bar_chart.sh` → shows results in a terminal bar chart
- `render_results_bar_image.sh` → generates an image chart
- `benchmark_generate_random_results.sh` → lets you edit the JSON results manually

## Usage

### 1) Run the benchmark

Make executable (once):

```bash
chmod +x scripts/*.sh
```

Run:

```bash
./scripts/benchmark.sh
```

#### Override model lists (example)

Model lists are **space-separated** strings.

Run a single model:

```bash
MODELS_LLAMACPP="glm-4.7-flash" ./scripts/benchmark.sh
```

Run multiple models:

```bash
MODELS_LLAMACPP="glm-4.7-flash qwen3-coder-next" ./scripts/benchmark.sh
```

### 2) View results as a terminal bar chart

```bash
./scripts/results_bar_chart.sh 
```

<pass the name of the JSON result as a parameter> ~/logs/benchmark_LLAMACPP.jsonl or benchmark_FLMSERVER.jsonl

### 3) Render results as an image

```bash
./scripts/render_results_bar_image.sh  
```
<pass the name of the JSON result as a parameter> ~/logs/benchmark_LLAMACPP.jsonl or benchmark_FLMSERVER.jsonl

### 4) Generate/edit sample JSON results

This is useful to test the chart scripts without running real benchmarks:

```bash
./scripts/benchmark_generate_random_results.sh 
```

## Configuration (environment variables)

Common environment variables used by the benchmark scripts:

- `HOST_FLM` — FLMServer endpoint (example: `http://<ip>:52625/v1/chat/completions`)
- `HOST_LLAMACPP` — LLaMA.cpp endpoint (example: `http://<ip>:4000/v1/chat/completions`)
- `PROMPT_FLM` — prompt for FLMServer
- `PROMPT_LCPP` — prompt for LLaMA.cpp
- `MODELS_FLM` — FLM model list (space-separated)
- `MODELS_LLAMACPP` — LLaMA.cpp model list (space-separated)

## Notes

- Ensure you run the correct script path (for example `./scripts/benchmark.sh`).
- The benchmark script will save results in `~/logs/benchmark_FLMSERVER.jsonl` and `~/logs/benchmark_LLAMACPP.jsonl` by default.

