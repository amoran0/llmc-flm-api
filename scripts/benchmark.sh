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
  MODELS_FLM="deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b"
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
        local prompt="$3"
        local prompt_tokens="$4"
        local prompt_processing="$5"
        local generation_tokens="$6"
        local tokengeneration="$7"

        prompt=$(echo "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')

          echo "{\"model\":\"$model\",\"server\":\"$server\",\"prompt\":\"$prompt\",\"prompt_tokens\":$prompt_tokens,\"prompt_processing\":$prompt_processing,\"tokengeneration\":$tokengeneration,\"generation_tokens\":$generation_tokens}" 
}

stats_FLMSERVER() {
  local name="$1" response="$2" prompt="$3"
  local prompt_tokens=$(:wqecho "$response" | jq '.usage.prompt_tokens // 0')
  local completion_tokens=$(echo "$response" | jq '.usage.completion_tokens // 0')
  local prefill_seconds=$(echo "$response" | jq '.usage.prefill_duration_ttft // 0')
  local decoding_seconds=$(echo "$response" | jq '.usage.decoding_duration // 0')
  local prompt_speed=$(echo "$response" | jq '.usage.prefill_speed_tps // 0')
  local generation_speed=$(echo "$response" | jq '.usage.decoding_speed_tps // 0')


  echo "= $name ="
  echo "Prompt: $prompt"
  echo "Prompt generation:     ${prompt_tokens} tokens in ${prefill_seconds}ms (${prompt_speed} t/s)"
  echo "Generation: ${completion_tokens} tokens in ${decoding_seconds}ms (${generation_speed} t/s)"
  echo ""

  log_json "$name" "FLMServer" "$prompt" "$prompt_tokens" "$prefill_seconds" "$decoding_seconds" "$generation_speed" >> ~/logs/benchmark_FLMSERVER.jsonl

}
stats_LLAMACPP() {

  local name="$1" response="$2" prompt="$3"
  local prompt_number=$(echo "$response" | jq '.timings.prompt_n // 0')
  local prompt_processing_time=$(echo "$response" | jq '.timings.prompt_ms // 0')
  local prompt_per_second=$(echo "$response" | jq '.timings.prompt_per_second // 0')
  local token_generated=$(echo "$response" | jq '.timings.predicted_n // 0')
  local token_generated_time=$(echo "$response" | jq '.timings.predicted_ms // 0')
  local generated_tokens_per_second=$(echo "$response" | jq '.timings.predicted_per_second // 0')

  echo "= $name ="
  echo "Prompt: $prompt"
  echo "Prompt:     $prompt_number tokens in ${prompt_processing_time}ms (${prompt_per_second} t/s)"
  echo "Generation: $token_generated tokens in ${token_generated_time}ms (${generated_tokens_per_second} t/s)"
  echo ""

  log_json "$name" "LLaMACPP" "$prompt" "$prompt_number" "$prompt_per_second" "$token_generated" "$generated_tokens_per_second" >> ~/logs/benchmark_LLAMACPP.jsonl


}

echo "=== FLMServer ==="

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

echo "=== LLaMACPP ==="

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

