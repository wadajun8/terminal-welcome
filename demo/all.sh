#!/usr/bin/env bash
# A〜D を順番に表示する。各デモのあとキー入力で次へ
D=$(dirname "$0")
next() {
  printf '\n\033[38;5;240m  ── %s ──  [何かキーを押すと次へ]\033[0m\n' "$1"
  if [[ -t 0 ]]; then read -rsn1 _; else sleep 2; fi
}
for s in "a_cyberpunk:A. サイバーパンク" "b_cockpit:B. 航空・宇宙船の計器" \
         "c_crt:C. レトロUNIX・CRT" "d_minimal:D. モダンSF・ミニマル" \
         "e_neon_cockpit:E. 計器＋ネオン（採用）"; do
  clear
  bash "$D/${s%%:*}.sh"
  next "${s#*:}"
done
clear
