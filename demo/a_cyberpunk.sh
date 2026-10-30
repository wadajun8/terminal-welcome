#!/usr/bin/env bash
# A. サイバーパンク: ネオン多色 + グリッチ
source "$(dirname "$0")/lib.sh"
CY=51 MG=201 PU=93

glitch() {  # $1=最終文字列 $2=色
  local s=$1 col=$2 noise='!@#$%&*/\|<>?=+~^' i k out
  for k in 1 2 3; do
    out=""
    for ((i = 0; i < ${#s}; i++)); do
      if (( RANDOM % 3 < 3 - k )) && [[ ${s:i:1} != " " ]]; then
        out+=${noise:RANDOM%${#noise}:1}
      else
        out+=${s:i:1}
      fi
    done
    printf '\r  %s%s%s' "$(c "$col")$BOLD" "$out" "$R"; pause 0.07
  done
  printf '\r  %s%s%s\n' "$(c "$col")$BOLD" "$s" "$R"
}

echo
glitch "//// JACK IN ////" $MG
for item in "neural link" "ice breaker" "uplink"; do
  printf '  %s> %-12s' "$(c $CY)" "$item"
  typeout "........" 0.012
  printf ' %s[ OK ]%s\n' "$(c $MG)$BOLD" "$R"
done
echo
printf '  %s%s%s\n' "$(c $PU)" "╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱" "$R"
printf '            %s┌──────────────┐%s\n' "$(c 51)" "$R"
printf '            %s│   ( MARK )   │%s\n' "$(c 135)" "$R"
printf '            %s└──────────────┘%s\n' "$(c 201)" "$R"
printf '     %s//%s ── %s //%s\n' "$(c $CY)" "$(date '+%a.%d.%b.%Y' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
printf '  %s%s%s\n' "$(c $PU)" "╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱" "$R"
pause 0.1
printf '  %s▲ ONLINE_%s\n\n' "$(c $MG)$BOLD" "$R"
