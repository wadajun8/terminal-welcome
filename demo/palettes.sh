#!/usr/bin/env bash
# welcome.sh の配色案を1つずつ表示して見比べる
#   Enter など: 次の案へ / a: その配色を演出つきで見る / q: 終了
D=$(cd "$(dirname "$0")/.." && pwd)
DESC=(
  "neon       今の配色。紫の枠にシアンのゲージ、マゼンタの見出し"
  "synthwave  夕焼けのレトロフューチャー。オレンジのゲージにピンクと黄色"
  "tron       青一色の電子回路。白の NOMINAL、注意は黄、警告は赤"
  "matrix     緑一色の端末。警告だけ赤"
  "akira      赤いネオンの夜の街。警告は黄色"
  "vapor      パステルのヴェイパーウェイヴ。淡い水色とピンク"
  "amber      B案の計器の色。アンバーと白"
)
n=${#DESC[@]}
for ((i = 0; i < n; i++)); do
  name=${DESC[i]%% *}
  while :; do
    clear
    printf '\n  \033[1m%d/%d  %s\033[0m\n' $((i + 1)) "$n" "${DESC[i]}"
    PALETTE=$name WELCOME_SKIP=1 bash "$D/welcome.sh"
    printf '\033[38;5;240m  [Enter: 次へ  a: 演出つきで見る  q: 終了]\033[0m'
    read -rsn1 key
    case $key in
      a) clear; PALETTE=$name bash "$D/welcome.sh"; read -rsn1 -t 3 _ ;;
      q) echo; exit 0 ;;
      *) break ;;
    esac
  done
done
clear
