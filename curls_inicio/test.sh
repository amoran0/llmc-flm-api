#!/bin/bash

stats() {
  local name="$1" response="$2" prompt="$3"
  local pn=$(echo "$response" | jq '.timings.prompt_n // 0')
  local pms=$(echo "$response" | jq '.timings.prompt_ms // 0')
  local pps=$(echo "$response" | jq '.timings.prompt_per_second // 0')
  local gn=$(echo "$response" | jq '.timings.predicted_n // 0')
  local gms=$(echo "$response" | jq '.timings.predicted_ms // 0')
  local gps=$(echo "$response" | jq '.timings.predicted_per_second // 0')
  
  jq -n --arg name "$name" --arg prompt "$prompt" --arg pn "$pn" --arg pms "$pms" --arg pps "$pps" --arg gn "$gn" --arg gms "$gms" --arg gps "$gps" \
    '{name: $name, prompt: $prompt, prompt_tokens: $pn, prompt_ms: $pms, prompt_per_second: $pps, generation_tokens: $gn, generation_ms: $gms, generation_per_second: $gps}'
}

HOST="http://192.168.0.142:4000/v1/chat/completions"
PROMPT_FLM="Hello world"
PROMPT_LCPP="Hello world"

MODELS_FLM="deepseek-r1:8b gpt-oss:20b llama3.1:8b qwen3.5:9b"
MODELS_LLAMACPP="glm-4.7-flash qwen3-coder-next gpt-oss-20b-q4-k-m gpt-oss-120b lfm2-24b-a2b-mxfp4-moe lfm2.5-1.2b-q8-k-xl"

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
  F=$(curl -s -X POST "$HOST" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats "FLMServer ($model)" "$F" "$PROMPT_FLM"
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
  L=$(curl -s -X POST "$HOST" -H "Content-Type: application/json" -d @/tmp/payload.json)
  stats "LLaMACPP ($model)" "$L" "$PROMPT_LCPP"
done
