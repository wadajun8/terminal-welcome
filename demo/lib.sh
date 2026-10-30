# デモ共通: 色・待機（キー入力でスキップ）・タイプ表示
export LC_TIME=C
SKIP=0
R=$'\033[0m'; BOLD=$'\033[1m'
c() { printf '\033[38;5;%sm' "$1"; }

# 指定秒だけ待つ。キーが押されたら以降の待機をすべて飛ばす
pause() {
  (( SKIP )) && return 0
  if [[ -t 0 ]]; then
    read -rsn1 -t "$1" _ && SKIP=1
  else
    sleep "$1"
  fi
  return 0
}

typeout() {  # $1=文字列 $2=1文字あたりの秒数
  local s=$1 d=$2 i
  for ((i = 0; i < ${#s}; i++)); do printf '%s' "${s:i:1}"; pause "$d"; done
}

if [[ -t 1 ]]; then
  tput civis 2>/dev/null
  trap 'tput cnorm 2>/dev/null' EXIT
fi
