#!/bin/bash

#make a dedicate stats funtionc for fmlserver
#promt_speed out ot perfill_speed_tps
#generation_speed out of decode_speed_tps


#Call specify model:MODELS_LLAMACPP/FLM="modelo-or1 modelo-or2" ./benchmark.sh

# Configurable endpoints + prompt (override via env)
HOST_LLAMACPP="${HOST_LLAMACPP:-http://192.168.0.142:4000/v1/chat/completions}"
HOST_FLM="${HOST_FLM:-http://192.168.0.142:52625/v1/chat/completions}"
PROMPT="${PROMPT:-write a terraform snippet that deploys an ec2 instance}"

# distinguish between unset MODELS_FLM and empty MODELS_FLM
if [ -z "${MODELS_FLM+x}" ]; then
  echo "MODELS_FLM is unset, using default models"
  MODELS_FLM="${deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b}"
elif [ -z "$MODELS_FLM" ]; then
  echo "MODELS_FLM is set but empty, no models will be tested"
fi
echo models flm: $MODELS_FLM


if [ -z "${MODELS_LLAMACPP+x}" ]; then
  echo "MODELS_LLAMACPP is unset, using default models"
  MODELS_LLAMACPP="${MODELS_LLAMACPP:-glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-moe lfm2.5-1.2b-q8-k-xl}"
elif [ -z "$MODELS_LLAMACPP" ]; then
  echo "MODELS_LLAMACPP is set but empty, no models will be tested"
fi
echo models llama: $MODELS_LLAMACPP

#MODELS_FLM="deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b"
#MODELS_LLAMACPP="glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-   moe lfm2.5-1.2b-q8-k-xl"

log_json() {
        local model="$1"
        local server="$2"
        local input_prompt="$3"
        local prompt_token_count="$4"
        local prompt_processing_time_ms="$5"
        local generated_token_count="$6"
        local generation_time_ms="$7"
        local generated_tokens_per_second="$8"

        input_prompt=$(echo "$input_prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')

        # Note: prompt_tokens_per_second is included in the schema you requested.
        # If you want it logged too, pass it as an additional argument and add it below.
        echo "{\"model\":\"$model\",\"server\":\"$server\",\"input_prompt\":\"$input_prompt\",\"prompt_token_count\":$prompt_token_count,\"prompt_processing_time_ms\":$prompt_processing_time_ms,\"generation_time_ms\":$generation_time_ms,\"generated_tokens_per_second\":$generated_tokens_per_second,\"generated_token_count\":$generated_token_count}"
}

stats_FLMSERVER() {
  local name="$1" response="$2" input_prompt="$3"

  local prompt_token_count=$(echo "$response" | jq '.usage.prompt_tokens // 0')
  local generated_token_count=$(echo "$response" | jq '.usage.completion_tokens // 0')

  local prompt_processing_time_ms=$(echo "$response" | jq '.usage.prefill_duration_ttft // 0')
  local generation_time_ms=$(echo "$response" | jq '.usage.decoding_duration // 0')

  local prompt_tokens_per_second=$(echo "$response" | jq '.usage.prefill_speed_tps // 0')
  local generated_tokens_per_second=$(echo "$response" | jq '.usage.decoding_speed_tps // 0')

  echo "= $name ="
  echo "Prompt: $input_prompt"
  echo "Prompt processing:     ${prompt_token_count} tokens in ${prompt_processing_time_ms}ms (${prompt_tokens_per_second} t/s)"
  echo "Generation: ${generated_token_count} tokens in ${generation_time_ms}ms (${generated_tokens_per_second} t/s)"
  echo ""

  log_json \
    "$name" \
    "FLMServer" \
    "$input_prompt" \
    "$prompt_token_count" \
    "$prompt_processing_time_ms" \
    "$generated_token_count" \
    "$generation_time_ms" \
    "$generated_tokens_per_second" \
    >> ~/logs/benchmark_FLMSERVER.jsonl
}

stats_LLAMACPP() {

  local name="$1" response="$2" input_prompt="$3"

  local prompt_token_count=$(echo "$response" | jq '.timings.prompt_n // 0')
  local prompt_processing_time_ms=$(echo "$response" | jq '.timings.prompt_ms // 0')
  local prompt_tokens_per_second=$(echo "$response" | jq '.timings.prompt_per_second // 0')

  local generated_token_count=$(echo "$response" | jq '.timings.predicted_n // 0')
  local generation_time_ms=$(echo "$response" | jq '.timings.predicted_ms // 0')
  local generated_tokens_per_second=$(echo "$response" | jq '.timings.predicted_per_second // 0')

  echo "= $name ="
  echo "Prompt: $input_prompt"
  echo "Prompt processing:     ${prompt_token_count} tokens in ${prompt_processing_time_ms}ms (${prompt_tokens_per_second} t/s)"
  echo "Generation: ${generated_token_count} tokens in ${generation_time_ms}ms (${generated_tokens_per_second} t/s)"
  echo ""

  log_json \
    "$name" \
    "LLaMACPP" \
    "$input_prompt" \
    "$prompt_token_count" \
    "$prompt_processing_time_ms" \
    "$prompt_tokens_per_second" \
    "$generated_token_count" \
    "$generation_time_ms" \
    "$generated_tokens_per_second" \
    >> ~/logs/benchmark_LLAMACPP.jsonl
}
echo "= FLMServer ="

for model in $MODELS_FLM; do
  cat > /tmp/payload.json <<EOF
{
  "model": "$model",
  "messages": [
    { "role": "user", "content": "$PROMPT"}
  ]
}
EOF
  curl_response_FLM=$(curl -s -X POST "$HOST_FLM" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats_FLMSERVER "FLMServer ($model)" "$curl_response_FLM" "$PROMPT"
done

echo "= LLaMACPP ="

for model in $MODELS_LLAMACPP; do
  cat > /tmp/payload.json <<EOF

{
  "model": "$model",
  "messages": [
    { "role": "user", "content": "$PROMPT"}
  ]
}
EOF
  curl_response_LLAMA=$(curl -s -X POST "$HOST_LLAMACPP" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats_LLAMACPP "LLaMACPP ($model)" "$curl_response_LLAMA" "$PROMPT"
done

