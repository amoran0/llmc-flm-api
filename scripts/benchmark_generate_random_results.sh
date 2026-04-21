MIN_NUM=40 MAX_NUM=500;
while IFS= read -r line; 
do pp=$(shuf -i ${MIN_NUM}-${MAX_NUM} -n1); tg=$(shuf -i ${MIN_NUM}-${MAX_NUM} -n1); 
jq -c --argjson pp "$pp" --argjson tg "$tg" '.prompt_processing=$pp | .tokengeneration=$tg' <<<"$line"; done < fixed.jsonl > out.jsonl
