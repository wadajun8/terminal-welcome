#!/usr/bin/env bash
# C. レトロUNIX・CRT: グリーン単色 + 1文字ずつ打ち出し
source "$(dirname "$0")/lib.sh"
DG=28 G=46

echo
printf '%s' "$(c $DG)"
typeout "BIOS v2.06  (C) 1986" 0.008; echo
typeout "MEMORY TEST ...... 640K OK" 0.008; echo
typeout "LOADING SHELL ............ OK" 0.008; echo
printf '%s\n' "$R"
printf '          %s( MARK )%s\n\n' "$(c $G)$BOLD" "$R"
printf '%s' "$(c $G)"
typeout "$(date '+%a %b %d %H:%M:%S %Y' | tr a-z A-Z)" 0.006; echo
typeout "READY." 0.02; echo
for i in 1 2 3; do
  printf '█'; pause 0.12
  printf '\b \b'; pause 0.12
done
printf '%s\n' "$R"
