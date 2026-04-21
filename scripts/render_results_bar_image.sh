#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export LANG=C

in="${1:?JSONL input file required}"
out="${2:-bars.png}"

WIDTH="${WIDTH:-2400}"
HEIGHT="${HEIGHT:-1000}"
TITLE="${TITLE:-Latency per model }"
SORT_BY="${SORT_BY:-total}"          # prompt_processing|tokengeneration|total|none
MAX_ROWS="${MAX_ROWS:-20}"
MAX_LABEL_CHARS="${MAX_LABEL_CHARS:-52}"
RIGHT_PAD="${RIGHT_PAD:-0.18}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

clean="$tmpdir/clean.jsonl"
tsv="$tmpdir/data.tsv"

while IFS= read -r line; do
  printf '%s\n' "$line" | jq -e . >/dev/null 2>&1 && printf '%s\n' "$line" >> "$clean"
done < "$in"

jq -r --argjson ml "$MAX_LABEL_CHARS" '
  def trunc($s; $n):
    if ($s|length) <= $n then $s else ($s[0:($n-1)] + "…") end;

  .label = trunc((.server + " | " + .model); $ml) |
  .pp = (.prompt_processing // 0) |
  .tg = (.tokengeneration // 0) |
  .total = (.pp + .tg) |
  [ .label, .pp, .tg, .total ] | @tsv
' "$clean" > "$tsv.raw"

case "$SORT_BY" in
  prompt_processing) sort -t$'\t' -k2,2nr "$tsv.raw" -o "$tsv.raw" ;;
  tokengeneration)   sort -t$'\t' -k3,3nr "$tsv.raw" -o "$tsv.raw" ;;
  total)             sort -t$'\t' -k4,4nr "$tsv.raw" -o "$tsv.raw" ;;
  none)              : ;;
  *) echo "SORT_BY must be prompt_processing|tokengeneration|total|none" >&2; exit 2 ;;
esac

head -n "$MAX_ROWS" "$tsv.raw" > "$tsv.raw.top" && mv "$tsv.raw.top" "$tsv.raw"
awk -F'\t' 'BEGIN{OFS="\t"} {print NR-1, $1, $2+0, $3+0, $4+0}' "$tsv.raw" > "$tsv"

rows=$(awk 'END{print NR}' "$tsv")
[[ -z "$rows" || "$rows" -eq 0 ]] && { echo "No rows to plot"; exit 1; }

max_total=$(awk -F'\t' '($5>m){m=$5} END{print (m?m:1)}' "$tsv")

gnuplot <<GP
set terminal pngcairo size ${WIDTH},${HEIGHT} font "DejaVu Sans Mono,16"
set output "${out}"
set datafile separator "\t"

set object 1 rect from screen 0,0 to screen 1,1 behind fillcolor rgb "#0b0f14" fillstyle solid 1.0 noborder

set title "${TITLE}" textcolor rgb "#e5e7eb"
unset key
unset xtics
unset ytics
set border lc rgb "#111827"

set xrange [0:1]
set yrange [-1:${rows}]
set lmargin 2
set rmargin 2
set tmargin 3
set bmargin 2

h = 0.36

RIGHT_PAD = ${RIGHT_PAD}
BAR_X0 = 0.02
BAR_X1 = 1.0 - RIGHT_PAD
BAR_W  = BAR_X1 - BAR_X0

set style fill solid 1.0 border -1
set style line 1 lc rgb "#a78bfa"
set style line 2 lc rgb "#60a5fa"
txt = "#e5e7eb"

# indicator on top: violet=PP, blue=TG
ind_y0 = -0.85
ind_y1 = -0.55

set object 10 rect from 0.02, ind_y0 to 0.06, ind_y1 fc rgb "#a78bfa" fs solid 1.0 noborder
set label 10 "PP" at 0.065, (ind_y0+ind_y1)/2 left tc rgb txt font "DejaVu Sans Mono,14"

set object 11 rect from 0.12, ind_y0 to 0.16, ind_y1 fc rgb "#60a5fa" fs solid 1.0 noborder
set label 11 "TG" at 0.165, (ind_y0+ind_y1)/2 left tc rgb txt font "DejaVu Sans Mono,14"

plot \
  "${tsv}" using (0):( \$1 ):(BAR_X0):(BAR_X0 + BAR_W*( \$3/${max_total} )):( \$1-h ):( \$1+h ) with boxxyerror ls 1 notitle, \
  "${tsv}" using (0):( \$1 ):(BAR_X0 + BAR_W*( \$3/${max_total} )):(BAR_X0 + BAR_W*( (\$3+\$4)/${max_total} )):( \$1-h ):( \$1+h ) with boxxyerror ls 2 notitle, \
  "${tsv}" using (BAR_X0 + 0.008):( \$1 ):( \$2 ) with labels left tc rgb txt font "DejaVu Sans Mono,14" notitle, \
  "${tsv}" using (0.98):( \$1 ):(sprintf("PP %.1f  TG %.1f", \$3, \$4)) with labels right tc rgb txt font "DejaVu Sans Mono,14" notitle
GP

echo "${out}"
