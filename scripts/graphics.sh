#!/usr/bin/env bash
set -euo pipefail

W=36

# Strip control chars, parse JSONL, aggregate means, sort, then render fixed-width ASCII bars.
LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' < ~/logs/resultados/out.jsonl|
jq -r '[.server,.model,(.prompt_processing|tostring),(.tokengeneration|tostring)]|@tsv' |
awk -F'\t' '
  $3!="null" && $4!="null" {
    key=$1" | "$2
    pp[key]+=$3; tg[key]+=$4; n[key]++
  }
  END{
    for (k in n) print k "\t" (pp[k]/n[k]) "\t" (tg[k]/n[k])
  }
' |
LC_ALL=C sort -t $'\t' -k2,2nr |
awk -F'\t' -v W="$W" '
  function gbar(v, max,    units,full,i,s) {
    if (max<=0) max=1
    units = (v/max)*W
    if (units < 0) units = 0
    if (units > W) units = W

    full = int(units + 0.5)   # round
    if (full < 0) full = 0
    if (full > W) full = W

    s=""
    for(i=0;i<full;i++) s=s"#"   # change "#" to "=" or "|" if you want
    while(length(s) < W) s=s" "
    return s
  }

  { rows[++R]=$0; if($2>maxPP) maxPP=$2; if($3>maxTG) maxTG=$3 }

  END{
    printf "%-55s | %10s %*s | %10s %*s\n", "server | model", "PP(mean)", W, "prompt_processing", "TG(mean)", W, "tokengeneration"
    printf "%s\n", "------------------------------------------------------------------------------------------------------------------------------------------"
    for(i=1;i<=R;i++){
      split(rows[i],a,"\t")
      printf "%-55s | %10.3f %s | %10.3f %s\n", a[1], a[2], gbar(a[2],maxPP), a[3], gbar(a[3],maxTG)
    }
  }
'
~
