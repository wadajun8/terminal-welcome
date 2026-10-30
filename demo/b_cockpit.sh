#!/usr/bin/env bash
# B. 航空・宇宙船の計器: アンバー + 白（赤は警告用）
source "$(dirname "$0")/lib.sh"
AM=214 WH=255 DIM=94
W=12  # ゲージの長さ

gauge() {  # $1=ラベル $2=埋まった数
  local n=$1 f=$2 bar="" st col i
  (( f < 0 )) && f=0; (( f > W )) && f=$W
  for ((i = 0; i < W; i++)); do (( i < f )) && bar+="■" || bar+="□"; done
  if (( f == W )); then st=NOMINAL; col=$WH
  elif (( f == 0 )); then st=STANDBY; col=$DIM
  else st=CHECKING; col=$AM; fi
  printf '%s│%s %-4s %s%s%s  %s%-8s%s   %s│%s\n' \
    "$(c $AM)" "$R" "$n" "$(c $AM)" "$bar" "$R" "$(c $col)" "$st" "$R" "$(c $AM)" "$R"
}

frame() {  # $1=ステップ数
  printf '%s┌─ PRE-FLIGHT CHECK ────────────┐%s\n' "$(c $AM)$BOLD" "$R"
  gauge PWR $(( $1 ))
  gauge NAV $(( $1 - 3 ))
  gauge COM $(( $1 - 6 ))
  printf '%s└───────────────────────────────┘%s\n' "$(c $AM)" "$R"
}

echo
last=$(( W + 6 ))
for ((s = 0; s <= last; s++)); do
  (( s > 0 )) && printf '\033[5A'
  frame "$s"
  pause 0.045
done
echo
printf '          %s( MARK )%s\n' "$(c $AM)$BOLD" "$R"
echo
printf '  %sT+ %s ▕ %s JST%s\n' "$(c $WH)" "$(date '+%Y-%m-%d %a' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
pause 0.15
printf '  %s▲ ALL SYSTEMS GO%s\n\n' "$(c $AM)$BOLD" "$R"
