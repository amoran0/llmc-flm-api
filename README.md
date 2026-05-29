# llmc-flm-api-reporter

A small collection of Bash scripts for benchmarking LLM APIs, saving results as JSONL, and turning those results into terminal or image-based bar charts.

This project is useful when you want to compare multiple models exposed through OpenAI-compatible chat completion endpoints such as:

- **FLMServer**
- **LLaMA.cpp**

The scripts focus on collecting performance information like:

- prompt token count
- prompt processing time
- generation token count
- generation time
- tokens per second

---
## Requirements

### Runtime requirements

- `bash`
- `curl`
- `jq`
- `gnuplot`

Some scripts also use standard command-line utilities such as:

- `awk`
- `sort`
- `tr`
- `mktemp`
- `shuf`

### Development / test requirements

- `behave` 
- `requests` 
- `pyquotegen`

```bash
pip3 install requirements-dev.txt
```

---

## What each file does

### `scripts/benchmark.sh`

This is the main benchmark runner.

It sends the same prompt to multiple models on one or two configured servers:

- `HOST_FLM`
- `HOST_LLAMACPP`

For each model, the script:

1. builds a JSON request payload
2. sends it with `curl` to the configured endpoint
3. reads the JSON response
4. extracts timing and token metrics with `jq`
5. prints a summary to the terminal
6. appends one JSON record to a `.jsonl` log file

#### How it handles each backend

The script supports two response formats:

- **FLMServer-style metrics**
- **LLaMA.cpp-style metrics**

Because their JSON responses differ, the script uses two different functions:

- `stats_FLMSERVER()`
- `stats_LLAMACPP()`

#### Output files

Results are appended to:

- `~/logs/benchmark_FLMSERVER.jsonl`
- `~/logs/benchmark_LLAMACPP.jsonl`

Each line is one JSON object representing one benchmark run for one model.

#### Configuration

This script uses environment variables:

- `HOST_FLM` — FLMServer endpoint
- `HOST_LLAMACPP` — LLaMA.cpp endpoint
- `PROMPT` — prompt sent to each model
- `MODELS_FLM` — space-separated FLM model names
- `MODELS_LLAMACPP` — space-separated LLaMA.cpp model names

#### Important behavior

- If `MODELS_FLM` is **unset**, the script uses a built-in default list.
- If `MODELS_FLM` is set but empty, no FLM models are tested.
- If `MODELS_LLAMACPP` is **unset**, the script uses a built-in default list.
- If `MODELS_LLAMACPP` is set but empty, no LLaMA.cpp models are tested.

#### Example

```bash
./scripts/benchmark.sh
```

Run only one LLaMA.cpp model:

```bash
MODELS_LLAMACPP="glm-4.7-flash" MODELS_FLM="" ./scripts/benchmark.sh
```

Run multiple models with a custom prompt:

```bash
PROMPT="Write a Python web server example" \
MODELS_LLAMACPP="glm-4.7-flash qwen3-coder-next" \
MODELS_FLM="llama3.1:8b" \
./scripts/benchmark.sh
```

---

### `scripts/results_bar_chart.sh`

This script prints a text-based bar chart in the terminal.

It reads a JSONL results file, extracts two values for each row:

- `prompt_processing`
- `tokengeneration`

Then it:

1. removes control characters from the file
2. converts JSON lines into tab-separated values with `jq`
3. groups rows by `server | model`
4. calculates the mean of prompt-processing and token-generation values
5. sorts the rows
6. renders an ASCII bar chart using `awk`

#### What it is useful for

This script is useful when you want a quick comparison directly in the terminal without generating an image file.

#### Current limitation

Right now the script reads from a **hardcoded path**:

```bash
~/logs/resultados/out.jsonl
```

So unlike the README’s earlier wording, it does **not currently accept a file argument**.

To use it, you need to either:

- place your input file at that exact location, or
- edit the script to point to your desired JSONL file

#### Example output idea

It prints rows similar to:

- `server | model`
- `PP(mean)` with a bar
- `TG(mean)` with a bar

Where:

- `PP` = prompt processing
- `TG` = token generation

#### Run

```bash
./scripts/results_bar_chart.sh
```

---

### `scripts/render_results_bar_image.sh`

This script generates a PNG image bar chart from a JSONL file.

Unlike the terminal chart script, this one **does require an input filename**.

#### How it works

The script:

1. takes a JSONL input file as the first argument
2. optionally takes an output PNG filename as the second argument
3. filters out invalid JSON lines
4. builds labels in the form `server | model`
5. extracts:
   - `prompt_processing`
   - `tokengeneration`
   - total = prompt processing + token generation
6. sorts the rows according to the selected mode
7. keeps only the top `MAX_ROWS`
8. converts the data into TSV
9. renders a styled PNG chart using `gnuplot`

#### Arguments

```bash
./scripts/render_results_bar_image.sh <input.jsonl> [output.png]
```

- first argument: required input JSONL file
- second argument: optional output filename  
  default: `bars.png`

#### Chart customization

This script supports the following environment variables:

- `WIDTH` — image width in pixels
- `HEIGHT` — image height in pixels
- `TITLE` — title shown on the chart
- `SORT_BY` — one of:
  - `prompt_processing`
  - `tokengeneration`
  - `total`
  - `none`
- `MAX_ROWS` — maximum number of rows to show
- `MAX_LABEL_CHARS` — maximum label length before truncation
- `RIGHT_PAD` — adjusts spacing on the right side of the chart

#### Visual meaning

The chart uses two colored sections per row:

- one section for **PP** = prompt processing
- one section for **TG** = token generation

So each bar visually shows how much time comes from prompt processing versus generation.

#### Example

```bash
./scripts/render_results_bar_image.sh ~/logs/benchmark_LLAMACPP.jsonl bars.png
```

Custom example:

```bash
TITLE="FLM benchmark" SORT_BY=total MAX_ROWS=10 \
./scripts/render_results_bar_image.sh ~/logs/benchmark_FLMSERVER.jsonl flm.png
```

---

### `scripts/benchmark_generate_random_results.sh`

This is a helper script for generating fake benchmark values.

It is useful when you want to test the chart scripts without running real API benchmarks.

#### How it works

The script:

1. reads each line from `fixed.jsonl`
2. generates two random numbers using `shuf`
3. replaces:
   - `.prompt_processing`
   - `.tokengeneration`
4. writes the modified output to `out.jsonl`

#### Input and output

Input file expected:

```bash
fixed.jsonl
```

Output file created:

```bash
out.jsonl
```

#### Default random range

The generated random numbers are between:

- `40`
- `500`

#### Example

```bash
./scripts/benchmark_generate_random_results.sh
```

This is useful if you want sample data for:

- `results_bar_chart.sh`
- `render_results_bar_image.sh`

without calling real model servers.

---

## Typical workflow

### 1. Run the benchmark

```bash
./scripts/benchmark.sh
```

### 2. Generate an image chart from the results

```bash
./scripts/render_results_bar_image.sh ~/logs/benchmark_LLAMACPP.jsonl llamacpp-results.png
```

or:

```bash
./scripts/render_results_bar_image.sh ~/logs/benchmark_FLMSERVER.jsonl flm-results.png
```

### 3. Optionally generate fake data for testing

```bash
./scripts/benchmark_generate_random_results.sh
```

---

## Notes

- `benchmark.sh` writes benchmark results to JSONL files in `~/logs/`
- `results_bar_chart.sh` currently uses a hardcoded input path
- `render_results_bar_image.sh` requires a JSONL input file argument
- `benchmark_generate_random_results.sh` expects `fixed.jsonl` in the current directory
- these scripts assume your endpoints are compatible with OpenAI-style chat completion requests

---

## In short

- `benchmark.sh` → collects benchmark data
- `results_bar_chart.sh` → prints a terminal chart
- `render_results_bar_image.sh` → creates a PNG chart
- `benchmark_generate_random_results.sh` → creates fake data for testing
