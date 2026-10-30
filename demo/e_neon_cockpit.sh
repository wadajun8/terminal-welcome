#!/usr/bin/env bash
# E. 計器（B）を骨組みに、ネオン配色 + タイトルと最終行だけグリッチ（A）
source "$(dirname "$0")/lib.sh"
CY=51 BC=87 MG=201 PK=213 PU=93 OFF=238
W=12  # ゲージの長さ

noisy() {  # $1=文字列 $2=ノイズ率(0〜100)
  local s=$1 p=$2 noise='!@#$%&*/\|<>?=+~^' i out=""
  for ((i = 0; i < ${#s}; i++)); do
    if (( RANDOM % 100 < p )) && [[ ${s:i:1} != " " ]]; then
      out+=${noise:RANDOM%${#noise}:1}
    else
      out+=${s:i:1}
    fi
  done
  printf '%s' "$out"
}

gauge() {  # $1=ラベル $2=埋まった数
  local n=$1 f=$2 on="" off="" st col i
  (( f < 0 )) && f=0; (( f > W )) && f=$W
  for ((i = 0; i < W; i++)); do (( i < f )) && on+="■" || off+="□"; done
  if (( f == W )); then st=NOMINAL; col=$BC$'m\033[1'
  elif (( f == 0 )); then st=STANDBY; col=$OFF
  else st=CHECKING; col=$PK; fi
  printf '%s│%s %s%-4s%s %s%s%s%s%s  %s%-8s%s   %s│%s\n' \
    "$(c $PU)" "$R" "$(c $PK)" "$n" "$R" "$(c $CY)" "$on" "$(c $OFF)" "$off" "$R" \
    "$(c "$col")" "$st" "$R" "$(c $PU)" "$R"
}

frame() {  # $1=ステップ数（序盤ほどタイトルが崩れる）
  local p=$(( 60 - $1 * 10 ))
  (( p < 0 )) && p=0
  printf '%s┌─ %s%s%s%s ────────────┐%s\n' \
    "$(c $PU)" "$(c $MG)$BOLD" "$(noisy "PRE-FLIGHT CHECK" $p)" "$R" "$(c $PU)" "$R"
  gauge PWR $(( $1 ))
  gauge NAV $(( $1 - 3 ))
  gauge COM $(( $1 - 6 ))
  printf '%s└───────────────────────────────┘%s\n' "$(c $PU)" "$R"
}

echo
last=$(( W + 6 ))
for ((s = 0; s <= last; s++)); do
  (( s > 0 )) && printf '\033[5A'
  frame "$s"
  pause 0.045
done
echo
printf '          %s( MARK )%s\n' "$(c $MG)$BOLD" "$R"
echo
printf '  %s//%s ── %s%s\n' "$(c $CY)" "$(date '+%Y-%m-%d %a' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
for p in 70 40 15; do
  printf '\r  %s%s%s' "$(c $MG)$BOLD" "$(noisy "▲ ALL SYSTEMS GO" $p)" "$R"; pause 0.06
done
printf '\r  %s▲ ALL SYSTEMS GO%s\n\n' "$(c $MG)$BOLD" "$R"
