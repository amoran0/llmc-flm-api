# AI Benchmark Scripts

This repo contains some Bash scripts to run simple AI benchmarks and visualize the results.

## Scripts

- `benchmark_ai_tokens.sh` → runs the benchmark tests
- `results_bar_chart.sh` → shows results in a terminal bar chart
- `render_results_bar_image.sh` → generates an image chart
- `benchmarkl_generate_random_results.sh` → lets you edit the JSON results manually

## Usage

Run the benchmark:

# Provide prompt as env var
PROMPT="whatever you wanna benchmark"
# Provide a list of models for...
MODELS_LLAMACPP="daksdkasd dkasdkaksa"
./benchmark.sh


Run render_results_bar_image.sh:

./render_results_bar_image.sh results.json 

```
