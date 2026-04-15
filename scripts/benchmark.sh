#!/bin/bash

#make a dedicate stats funtionc for fmlserver
#promt_speed out ot perfill_speed_tps
#generation_speed out of decode_speed_tps

log_json() {
        local model="$1"
        local server="$2"
        local prompt="$3"
        local prompt_tokens="$4"
        local prompt_processing="$5"
        local generation_tokens="$6"
        local tokengeneration="$7"

        prompt=$(echo "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')

          echo "{\"model\":\"$model\",\"server\":\"$server\",\"prompt\":\"$prompt\",\"prompt_tokens\":$prompt_tokens,\"prompt_processing\":$prompt_processing,\"tokengeneration\":$tokengeneration,\"generation_tokens\":$generation_tokens}" >> ~/logs/benchmark.jsonl

}

stats_FLMSERVER() {
  local name="$1" response="$2" prompt="$3"

  local prompt_tokens=$(echo "$response" | jq '.usage.prompt_tokens // 0')
  local completion_tokens=$(echo "$response" | jq '.usage.completion_tokens // 0')
  local prefill_seconds=$(echo "$response" | jq '.usage.prefill_duration_ttft // 0')
  local decoding_seconds=$(echo "$response" | jq '.usage.decoding_duration // 0')
  local prompt_speed=$(echo "$response" | jq '.usage.prefill_speed_tps // 0')
  local generation_speed=$(echo "$response" | jq '.usage.decoding_speed_tps // 0')


  echo "=== $name ==="
  echo "Prompt: $prompt"
  echo "Prompt:     ${prompt_tokens} tokens in ${prefill_ms}ms (${prompt_speed} t/s)"
  echo "Generation: ${completion_tokens} tokens in ${decoding_ms}ms (${generation_speed} t/s)"
  echo ""


   local model_name=$(echo "$name" | sed 's/.*(\(.*\))/\1/')
  log_json "$model_name" "FLMServer" "$prompt" "$pn" "$prompt_speed" "$gn" "$generation_speed"

}
stats_LLAMACPP() {

  local name="$1" response="$2" prompt="$3"
  local pn=$(echo "$response" | jq '.timings.prompt_n // 0')
  local pms=$(echo "$response" | jq '.timings.prompt_ms // 0')
  local pps=$(echo "$response" | jq '.timings.prompt_per_second // 0')
  local gn=$(echo "$response" | jq '.timings.predicted_n // 0')
  local gms=$(echo "$response" | jq '.timings.predicted_ms // 0')
  local gps=$(echo "$response" | jq '.timings.predicted_per_second // 0')

  echo "=== $name ==="
  echo "Prompt: $prompt"
  echo "Prompt:     $pn tokens in ${pms}ms (${pps} t/s)"
  echo "Generation: $gn tokens in ${gms}ms (${gps} t/s)"
  echo ""

  local model_name=$(echo "$name" | sed 's/.*(\(.*\))/\1/')
  log_json "$model_name" "LLaMACPP" "$prompt" "$pn" "$pps" "$gn" "$gps"


}

HOST_LLAMACPP="http://192.168.0.142:4000/v1/chat/completions"
HOST_FLM="http://192.168.0.142:52625/v1/chat/completions"
PROMPT_FLM="write a terraform snippet that deploys an ec2 instance"
PROMPT_LCPP="write a terraform snippet that deploys an ec2 instance"

MODELS_LLAMACPP=${MODELS_LLAMACPP:-glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-moe lfm2.5-1.2b-q8-k-xl}
MODELS_FLM=${MODELS_FLM:-deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b}


# MODELS_FLM="deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b"
# MODELS_LLAMACPP="glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-   moe lfm2.5-1.2b-q8-k-xl"

echo "=== FLMServer ==="
for model in $MODELS_FLM; do
  cat > /tmp/payload.json <<EOF
{
  "model": "$model",
  "messages": [
    { "role": "user", "content": "$PROMPT_FLM"}
  ]
}
EOF
  F=$(curl -s -X POST "$HOST_FLM" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats_FLMSERVER "FLMServer ($model)" "$F" "$PROMPT_FLM"
done

echo "=== LLaMACPP ==="
for model in $MODELS_LLAMACPP; do
  cat > /tmp/payload.json <<EOF

{
  "model": "$model",
  "messages": [
    { "role": "user", "content": "$PROMPT_LCPP"}
  ]
}
EOF
  L=$(curl -s -X POST "$HOST_LLAMACPP" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats_LLAMACPP "LLaMACPP ($model)" "$L" "$PROMPT_LCPP"
done

