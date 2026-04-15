#!/bin/bash

stats() {
    local name="$1" response="$2" prompt="$3"
  local pn=$(echo "$response" | jq '.timings.prompt_n // 0')
  local pms=$(echo "$response" | jq '.timings.prompt_ms // 0')
  local pps=$(echo "$response" | jq '.timings.prompt_per_second // 0')
  local gn=$(echo "$response" | jq '.timings.predicted_n // 0')
  local gms=$(echo "$response" | jq '.timings.predicted_ms // 0')
  local gps=$(echo "$response" | jq '.timings.predicted_per_second // 0')
  echo "=== $name ==="
  echo "Prompt:     $pn tokens in ${pms}ms (${pps} t/s)"
  echo "Generation: $gn tokens in ${gms}ms (${gps} t/s)"
  echo ""
}

PFLM="Hello world"
PLLM="Hello world"

MFLM="lfm2-24b-a2b-bf16"
MLLM="lfm2-24b-a2b-bf16 "
 
F=$(curl -s -X POST "http://192.168.0.142:4000/v1/chat/completions" -H "Content-Type: application/json" -d "{\"model\":\"$MFLM\",\"messages\":[{\"role\":\"user\",\"content\":\"$PFLM\"}]}")
L=$(curl -s -X POST "http://192.168.0.142:4000/v1/chat/completions" -H "Content-Type: application/json" -d "{\"model\":\"$MllM\",\"messages\":[{\"role\":\"user\",\"content\":\"$PLLM\"}]}")

stats "FLMServer (lfm2.5-1.2b-q8-k-xl)" "$F" "$PFLM"
stats "LLaMACPP (lfm2.5-1.2b-q8-k-xl)" "$L" " $PLLM"
