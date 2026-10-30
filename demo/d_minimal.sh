#!/usr/bin/env bash
# D. モダンSF・ミニマル: 白とグレー + 差し色1色
source "$(dirname "$0")/lib.sh"
WH=255 GR=245 ACC=117

fadein() {  # $1=字下げ $2=文字列 $3=最終色
  local col
  for col in 236 239 242 "$3"; do
    printf '\r%s%s%s%s' "$1" "$(c "$col")" "$2" "$R"; pause 0.05
  done
  echo
}

echo
for item in kernel network shell; do
  fadein "   " "$(printf '· %-9s ──────────── ok' "$item")" $GR
done
echo; echo
fadein "                " "( MARK )" $WH
echo
fadein "            " "$(date '+%d · %m · %Y')" $WH
fadein "                " "$(date +%H:%M)" $ACC
echo
