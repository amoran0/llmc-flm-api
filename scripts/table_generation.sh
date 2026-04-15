#!/usr/bin/env bash
set -euo pipefail

infile="${1:-/dev/stdin}"

printf "%-32s %18s %16s\n" "model" "avg_prompt_processing" "avg_tokengeneration"
printf "%-32s %18s %16s\n" "--------------------------------" "------------------" "----------------"

declare -A sum_pp sum_tg count

while IFS= read -r line; do
  [[ -z "${line//[[:space:]]/}" ]] && continue

  row="$(
    jq -r '
      [
        (.model // empty),
        (.prompt_processing // empty),
        (.tokengeneration // empty)
      ] | @tsv
    ' <<<"$line" 2>/dev/null
  )" || continue

  [[ -z "$row" ]] && continue

  IFS=$'\t' read -r model pp tg <<<"$row"

  [[ -z "$model" ]] && continue

  # initialize if needed
  sum_pp["$model"]=${sum_pp["$model"]:-0}
  sum_tg["$model"]=${sum_tg["$model"]:-0}
  count["$model"]=${count["$model"]:-0}

  # accumulate only numeric values
  [[ "$pp" =~ ^[0-9]+(\.[0-9]+)?$ ]] && sum_pp["$model"]=$(awk "BEGIN {print ${sum_pp["$model"]} + $pp}")
  [[ "$tg" =~ ^[0-9]+(\.[0-9]+)?$ ]] && sum_tg["$model"]=$(awk "BEGIN {print ${sum_tg["$model"]} + $tg}")

  count["$model"]=$((count["$model"] + 1))

done < "$infile"

# print averages
for model in "${!count[@]}"; do
  c=${count["$model"]}
    avg_pp=$(awk "BEGIN { if ($c > 0) print ${sum_pp["$model"]} / $c; else print 0 }")
  avg_tg=$(awk "BEGIN { if ($c > 0) print ${sum_tg["$model"]} / $c; else print 0 }")

  printf "%-32s %18.4f %16.4f\n" "$model" "$avg_pp" "$avg_tg"
done
