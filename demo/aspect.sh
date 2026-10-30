#!/usr/bin/env bash
# 端末の1文字の縦横比を調べ、レーダーが丸く見える ASPECT（1ドットの縦÷横）を選ぶ
#   1. 端末に文字の大きさ（ピクセル）を問い合わせて、計算した ASPECT を出す（対応していない端末もある）
#   2. 縦横比を変えた円を並べて出す。一番丸く見える円の数字を選ぶ
D=$(cd "$(dirname "$0")/.." && pwd)

ask() {  # $1=問い合わせ $2=返事の末尾の文字。返事の数字を空白区切りで出す
  local reply
  printf '%s' "$1" >/dev/tty
  IFS= read -rs -t 0.5 -d "$2" reply </dev/tty || return 1
  reply=${reply#*[}
  echo "${reply//;/ }"
}

if [[ -t 0 && -t 1 ]]; then
  cw="" ch=""
  # 16t: 1文字の大きさ（ピクセル）。返事は ESC[6;高さ;幅t
  if read -r _ ch cw < <(ask $'\033[16t' t) && [[ $ch =~ ^[0-9]+$ && $cw =~ ^[0-9]+$ ]] && (( cw > 0 )); then
    :
  # 16t に対応していなければ、画面全体の大きさ（14t）と文字数（18t）から割り出す
  elif read -r _ ph pw < <(ask $'\033[14t' t) && read -r _ rows cols < <(ask $'\033[18t' t) \
       && [[ $ph =~ ^[0-9]+$ && $rows =~ ^[0-9]+$ ]] && (( rows > 0 && cols > 0 && pw > 0 )); then
    ch=$(( ph / rows )) cw=$(( pw / cols ))
  fi
  if [[ -n $cw && -n $ch ]] && (( cw > 0 )); then
    printf '\n  1文字の大きさ: 幅 %dpx × 高さ %dpx → 計算上の ASPECT = %s\n' "$cw" "$ch" \
      "$(awk -v h="$ch" -v w="$cw" 'BEGIN { printf "%.2f", h / 2 / w }')"
  else
    printf '\n  この端末は文字の大きさを教えてくれませんでした。下の円を見て選んでください。\n'
  fi
fi

printf '\n  一番「真円」に見えるものの数字を教えてください。\n\n'
python3 "$D/tools/gen_radar.py" --aspect-test
