#!/usr/bin/env bash
# ターミナル・ウェルカム画面：リンクスタート風の演出のデモ（welcome.sh をもとにしている）
#   窓の横幅に合わせた 16:9 の範囲で、虹色の輪と白い光の筋が中心から外へ加速しながら広がる（前へ進む感覚）
#   → 白い光で真っ白になって消える → その場所に「WELCOME TO YOUR WORLD」が大きく四角と同じ色でフェードイン
#   → その下に、細い長方形（上下の線だけ）が出る。大きな文字と四角を合わせた大きさは、光と同じ 16:9 → 長方形が縦に伸びる
#   → ゲージと文字が出る → ゲージが貯まる → 日付 → ALL SYSTEMS GO
#   トンネルのコマは tools/gen_tunnel.py が窓の大きさごとに作り、~/.cache/terminal-welcome/ に保存して使い回す
#   幅 70 列以上: マークの右にゲージ / 狭い: マークの下にゲージ
#   マークが入りきらない: ゲージだけ（狭ければバーを縮める） / それも無理: 1行の要約
#   演出中に何かキーを押すと、残りを飛ばして最後の画面を即表示する
#   環境変数: PALETTE=<配色名>（下の一覧から）/ WELCOME_SKIP=1 で演出なし / WELCOME_LINE=1 で1行の要約だけ
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib.sh"
SKIP=${WELCOME_SKIP:-0}

# ── 設定 ──────────────────────────────────────
# 配色（256色の番号）: 枠 / ゲージ / ラベル / NOMINAL / タイトルと GO / WARNING / マーク
case ${PALETTE:-tron} in
  neon)      read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'93 51 213 87 201 196 213' ;;
  synthwave) read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'97 208 205 228 199 196 214' ;;
  matrix)    read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'22 40 28 157 46 196 46' ;;
  akira)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'88 203 167 255 196 226 196' ;;
  vapor)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'104 159 218 195 213 203 219' ;;
  amber)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'130 214 172 230 220 196 208' ;;
  *)         read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN MARK_COLOR <<<'24 45 31 255 51 208 51' ;;  # tron（採用）
esac
C_DIM=238 C_TEXT=255                 # 空のゲージ・OFFLINE / 数値の文字
W=12                                # ゲージの長さ
WARN_MEM=90 WARN_DISK=90             # 以上で WARNING
WARN_BAT=20                          # 以下かつ AC 電源なしで WARNING
WARN_GPU_TEMP=85                     # 以上で WARNING（℃）
WIDE_COLS=77                         # 横並びにする最小の幅
NARROW_COLS=45                       # 縦並びにする最小の幅
MIN_W=4                              # 狭いときに縮めるゲージの最短の長さ
GAUGE_STEP=0.05                      # ゲージが1マス進む間隔（秒）。大きいほどゆっくり


# 色コードを最初に作っておく（${F[51]} などで使う）。描画のたびに $(...) を起動すると遅いため
F=() BG=()
for i in {0..255}; do printf -v "F[$i]" '\033[38;5;%sm' "$i"; printf -v "BG[$i]" '\033[48;5;%sm' "$i"; done
BG_OFF=$'\033[49m'
MARK_K=0                             # 今のマークのコマ

COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
ROWS=${LINES:-$(tput lines 2>/dev/null || echo 24)}

# ── 値の取得 ──────────────────────────────────
# nvidia-smi は遅いので最初に裏で走らせ、待ち時間をマークの演出で隠す
GPU_TMP=$(mktemp)
trap '[[ -t 1 ]] && tput cnorm 2>/dev/null; rm -f "$GPU_TMP"' EXIT
GPU_PID=
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu \
    --format=csv,noheader,nounits >"$GPU_TMP" 2>/dev/null &
  GPU_PID=$!
fi

cpu_sample() {  # 合計と待機の jiffies
  local _ u n s i w q sq st
  read -r _ u n s i w q sq st _ </proc/stat
  echo "$((u + n + s + i + w + q + sq + st)) $((i + w))"
}
read -r CPU_T0 CPU_I0 < <(cpu_sample)

# ゲージごとに ラベル / 割合（-1 は取得できず）/ 右に出す文字 / WARNING なら 1
BANNER_TEXT=${BANNER_TEXT:-WELCOME TO|YOUR WORLD}   # 大きく出す言葉。| で2行に分ける（入りきらなければ1行にする）
pc_name() {  # この PC の機種名（例: ROG FLOW X13）。取れなければ OS の名前
  local f n
  for f in /sys/class/dmi/id/product_family /sys/class/dmi/id/product_name; do
    n=""
    [[ -r $f ]] && n=$(<"$f")
    case ${n,,} in  # メーカーが埋めていない値は使わない
      "" | *"to be filled"* | *"default string"* | *"system product name"* | *"not specified"* | none) n="" ;;
    esac
    [[ -n $n ]] && break
  done
  [[ -z $n && -r /etc/os-release ]] && n=$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")
  echo "${n^^}"
}
BOX_TITLE=${BOX_TITLE-$(pc_name)}          # 四角のタイトル。既定はこの PC の機種名。BOX_TITLE= で線だけ
LABEL=(CPU MEM DISK GPU BAT)
PCT=(100 100 100 100 100) INFO=() WARN=()  # 値を測る前は、四角を「CHECKING」で描くため仮に 100 にしておく
BOX_H=$(( ${#LABEL[@]} + 2 ))
BOX_PAD=(0 0 0 0 0 0)                      # 四角の中の空の行数（上端、各ゲージの下）。16:9 に合わせて増やす

collect() {
  local t1 i1 dt v total avail used tot temp cap ac bat acp

  read -r t1 i1 < <(cpu_sample)
  dt=$((t1 - CPU_T0))
  if (( dt < 16 )); then  # 演出を飛ばして間隔が短すぎたときは少し待って測り直す
    sleep 0.1
    read -r t1 i1 < <(cpu_sample)
    dt=$((t1 - CPU_T0))
  fi
  v=0; (( dt > 0 )) && v=$(( (dt - (i1 - CPU_I0)) * 100 / dt ))
  PCT[0]=$v INFO[0]="$v%" WARN[0]=0

  read -r total avail < <(awk '/^MemTotal/ {t = $2} /^MemAvailable/ {a = $2} END {print t, a}' /proc/meminfo)
  v=$(( (total - avail) * 100 / total ))
  PCT[1]=$v INFO[1]="$v%" WARN[1]=$(( v >= WARN_MEM ))

  v=$(df -P / | awk 'NR == 2 {sub("%", "", $5); print $5}')
  PCT[2]=$v INFO[2]="$v%" WARN[2]=$(( v >= WARN_DISK ))

  if [[ -n $GPU_PID ]]; then
    for _ in {1..20}; do kill -0 "$GPU_PID" 2>/dev/null || break; sleep 0.05; done
    kill "$GPU_PID" 2>/dev/null
  fi
  IFS=', ' read -r used tot temp <"$GPU_TMP"
  if [[ $used =~ ^[0-9]+$ && $tot =~ ^[0-9]+$ ]] && (( tot > 0 )); then
    [[ $temp =~ ^[0-9]+$ ]] || temp=0
    PCT[3]=$(( used * 100 / tot )) INFO[3]="${temp}C" WARN[3]=$(( temp >= WARN_GPU_TEMP ))
  else
    PCT[3]=-1 INFO[3]="N/A" WARN[3]=0
  fi

  bat=$(compgen -G '/sys/class/power_supply/BAT*' | head -1)
  acp=$(compgen -G '/sys/class/power_supply/A[CD]*/online' | head -1)
  if [[ -n $bat && -r $bat/capacity ]]; then
    cap=$(<"$bat/capacity") ac=0
    [[ -n $acp ]] && ac=$(<"$acp")
    PCT[4]=$cap INFO[4]="$cap%"
    (( ac == 1 )) && INFO[4]+=" AC"
    WARN[4]=$(( cap <= WARN_BAT && ac != 1 ))
  else
    PCT[4]=-1 INFO[4]="N/A" WARN[4]=0
  fi
}

# ── 描画 ──────────────────────────────────────
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

mark_draw() {  # $1=コマ番号 $2=すべてのクラスをこの色で描く（省略すると MARK_TONES の色）。MARK_H 行描く
  local r line i c tone cls=ABCDEFGHI
  for ((r = 0; r < MARK_H; r++)); do
    line=${MARK_FRAMES[$1 * MARK_H + r]}
    for ((i = 0; i < ${#cls}; i++)); do
      c=${cls:i:1} tone=${2:-${MARK_TONES[i]}}
      line=${line//$c/${F[tone]}}
      line=${line//${c,}/${BG[tone]}}
    done
    line=${line//z/$BG_OFF}
    printf '  %s%s\n' "$line" "$R"
  done
}

mark_fade() {  # 暗い灰色から順に塗り直してフェードインさせる
  local col first=1
  for col in 236 238 240 243; do
    (( first )) || printf '\033[%dA' "$MARK_H"
    first=0
    mark_draw 0 "$col"
    pause 0.06
  done
  printf '\033[%dA' "$MARK_H"
  mark_draw 0
}

move_rows() {  # $1 行だけカーソルを上へ（負なら下へ）
  if (( $1 > 0 )); then printf '\033[%dA' "$1"
  elif (( $1 < 0 )); then printf '\033[%dB' $(( -$1 ))
  fi
}

spin() {  # $1=マークの上端から今のカーソルまでの行数 $2=描くコマ（省略すると1コマ進める）。カーソルを元の行の先頭に戻す
  MARK_K=${2:-$(( (MARK_K + 1) % MARK_N ))}
  printf '\r'  # 行の途中から上へ移ると、マークの1行目が右にずれて描かれるため
  move_rows "$1"
  mark_draw "$MARK_K"
  move_rows $(( MARK_H - $1 ))
}

gauge_row() {  # $1=番号 $2=今の埋まり具合 $3=行頭（字下げかカーソル位置）
  local k=$1 f=$2 pre=$3 target=0 on="" off="" st col bold="" bar=$C_BAR info="" i
  if (( PCT[k] >= 0 )); then
    target=$(( (PCT[k] * W + 50) / 100 ))
    (( PCT[k] > 0 && target == 0 )) && target=1
  fi
  (( f > target )) && f=$target
  (( f < 0 )) && f=0
  for ((i = 0; i < W; i++)); do (( i < f )) && on+="■" || off+="□"; done
  if (( PCT[k] < 0 )); then st=OFFLINE col=$C_DIM info=${INFO[k]}
  elif (( f < target )); then st=CHECKING col=$C_LABEL
  elif (( WARN[k] )); then st=WARNING col=$C_WARN bar=$C_WARN bold=$BOLD info=${INFO[k]}
  else st=NOMINAL col=$C_OK bold=$BOLD info=${INFO[k]}; fi
  printf '%s%s│%s %s%-4s%s %s%s%s%s%s  %s%-7s%s %s%-8s%s %s│%s\n' \
    "$pre" "${F[C_FRAME]}" "$R" "${F[C_LABEL]}" "${LABEL[k]}" "$R" \
    "${F[bar]}" "$on" "${F[C_DIM]}" "$off" "$R" "${F[C_TEXT]}" "$info" "$R" \
    "${F[col]}$bold" "$st" "$R" "${F[C_FRAME]}" "$R"
}

hline() {  # $1=変数名 $2=本数。横線を並べて変数に入れる
  local i out=""
  for ((i = 0; i < $2; i++)); do out+="─"; done
  printf -v "$1" '%s' "$out"
}

box_pad() {  # $1=行頭 $2=何番目のすき間か。BOX_PAD の数だけ空の行を描く
  local i
  for ((i = 0; i < ${BOX_PAD[$2]:-0}; i++)); do printf '%s%s│%*s│%s\n' "$1" "${F[C_FRAME]}" $(( W + 25 )) "" "$R"; done
}

gauge_frame() {  # $1=ステップ数（序盤ほどタイトルが崩れる） $2=行頭
  local s=$1 pre=$2 p=$(( 60 - $1 * 10 )) k
  (( p < 0 )) && p=0
  box_top "$pre" "$(noisy "$BOX_TITLE" $p)"
  box_pad "$pre" 0
  for k in "${!LABEL[@]}"; do gauge_row "$k" $(( s - k * 2 )) "$pre"; box_pad "$pre" $(( k + 1 )); done
  printf '%s%s└%s┘%s\n' "$pre" "${F[C_FRAME]}" "$BOTTOM_LINE" "$R"
}

gauges() {  # $1=行頭 $2=マークの位置（right: マークの右 / below: マークの下 / none: マークなし）
  # right と below では、呼ぶ前にマークを描き終えてカーソルをその次の行に置いておく。
  # 毎フレーム、マークの上端までカーソルを戻してマークを1コマ進め、続けてゲージを描き直す
  # $3=呼んだときのカーソルの行（マークの上端から数える。省略すると MARK_H）
  local s last=$(( W + (${#LABEL[@]} - 1) * 2 )) box_h=$BOX_H cur=${3:-$MARK_H}
  hline TOP_LINE $(( W + 22 - ${#BOX_TITLE} ))
  hline BOTTOM_LINE $(( W + 25 ))
  for ((s = 0; s <= last; s++)); do
    if [[ $2 == none ]]; then
      (( s > 0 )) && printf '\033[%dA' "$box_h"
    else
      printf '\033[%dA' "$cur"
      MARK_K=$(( s * MARK_N / (last + 1) ))  # トンネルは1回だけ流す
      mark_draw "$MARK_K"
      if [[ $2 == right ]]; then  # ゲージ枠はマークの BOX_TOP 行目から
        printf '\033[%dA' $(( MARK_H - BOX_TOP ))
        cur=$(( BOX_TOP + box_h ))
      else
        echo
        cur=$(( MARK_H + 1 + box_h ))
      fi
    fi
    gauge_frame "$s" "$1"
    pause "$GAUGE_STEP"
  done
}

fx_size() {  # 光の範囲 FX_W 列 × FX_H 行と、その左端の列 FX_COL を決める
  # 窓の横幅に合わせた 16:9（1文字は縦2ドット、ドットの縦横比 1.25 で補正）。
  # 光が消えたあと、同じ範囲に大きな文字と四角が入り、その下に日付などが出る。高さが足りなければ幅を縮める
  local room=$(( ROWS - 4 ))
  FX_W=$(( COLS - 4 ))
  FX_H=$(( FX_W * 9 / 40 ))
  if (( FX_H > room )); then FX_H=$room FX_W=$(( room * 40 / 9 )); fi
  FX_COL=$(( (COLS - FX_W) / 2 + 1 ))
}

tunnel_play() {  # 光のトンネルを流し、流した範囲を消してその先頭にカーソルを置く。流せなければ 1 を返す
  local w=$FX_W h=$FX_H k n off=$FX_COL cache gen="$HERE/../tools/gen_tunnel.py" fr
  (( w >= 40 && h >= 9 )) && command -v python3 >/dev/null 2>&1 || return 1
  cache=${XDG_CACHE_HOME:-$HOME/.cache}/terminal-welcome/tunnel-${w}x${h}.txt
  if [[ ! -s $cache || $gen -nt $cache ]]; then
    mkdir -p "${cache%/*}" && python3 "$gen" --cols "$w" --rows "$h" >"$cache" 2>/dev/null || return 1
  fi
  mapfile -t fr <"$cache"
  n=$(( ${#fr[@]} / h ))
  for ((k = 0; k < h; k++)); do echo; done
  for ((k = 0; k < n; k++)); do
    (( SKIP )) && k=$(( n - 1 ))  # キーが押されたら最後のコマへ
    printf '\033[%dA' "$h"
    printf "\033[${off}G%s\n" "${fr[@]:k*h:h}"
    pause 0.02  # 加速の演出は短めに（0.04 秒の半分）
  done
  printf '\033[%dA\033[J' "$h"
}

banner_make() {  # $1=使える幅 $2=使える行数。大きな文字を BANNER（行の配列）と BANNER_W（幅）に入れる
  # toilet の大きい書体で2行 → 細い書体で1行 → 普通の文字、の順に、入るものを使う
  local font text lines line w
  BANNER=() BANNER_W=0
  if command -v toilet >/dev/null 2>&1; then
    for font in mono9 future; do
      lines=()
      if [[ $font == mono9 ]]; then
        IFS='|' read -ra parts <<<"$BANNER_TEXT"
        for text in "${parts[@]}"; do
          (( ${#lines[@]} )) && lines+=("")
          while IFS= read -r line; do [[ $line == *[^\ ]* ]] && lines+=("${line%"${line##*[^ ]}"}"); done \
            < <(toilet -f "$font" -w 1000 "$text" 2>/dev/null)
        done
      else
        while IFS= read -r line; do [[ $line == *[^\ ]* ]] && lines+=("${line%"${line##*[^ ]}"}"); done \
          < <(toilet -f "$font" -w 1000 "${BANNER_TEXT//|/ }" 2>/dev/null)
      fi
      w=0
      for line in "${lines[@]}"; do (( ${#line} > w )) && w=${#line}; done
      if (( w > 0 && w <= $1 && ${#lines[@]} <= $2 )); then BANNER=("${lines[@]}") BANNER_W=$w; return; fi
    done
  fi
  BANNER=("${BANNER_TEXT//|/ }") BANNER_W=${#BANNER[0]}
}

banner_draw() {  # $1=行頭 $2=色（省略すると四角のタイトルと同じ色）
  local line
  for line in "${BANNER[@]}"; do printf '%s%s%s%s%s\n' "$1" "${F[${2:-$C_TITLE}]}" "$BOLD" "$line" "$R"; done
}

banner_fade() {  # $1=行頭。大きな文字を暗い灰色から順に塗り直してフェードインさせる。カーソルは文字の下に置く
  local col first=1
  for col in 236 238 241 245 ""; do
    (( first )) || printf '\033[%dA' "${#BANNER[@]}"
    first=0
    banner_draw "$1" "$col"
    pause 0.05
  done
}

box_grow() {  # $1=行頭。細い長方形（タイトルがあればタイトルだけ）をフェードインさせ、中身の行数まで縦に伸ばす。カーソルは四角の上端に戻す
  local col k i
  hline TOP_LINE $(( W + 22 - ${#BOX_TITLE} ))
  hline BOTTOM_LINE $(( W + 25 ))
  for col in 236 238 240 243 "" ; do       # 細い長方形（上下の線だけ）のフェードイン
    box_shell "$1" 0 "$col"
    printf '\033[2A'
    pause 0.05
  done
  for ((k = 1; k <= BOX_H - 2; k++)); do  # 1行ずつ縦に伸びる
    box_shell "$1" "$k"
    printf '\033[%dA' $(( k + 2 ))
    pause 0.04
  done
}

box_top() {  # $1=行頭 $2=タイトル（崩した文字でもよい）。BOX_TITLE が空なら線だけ
  if [[ -z $BOX_TITLE ]]; then
    printf '%s%s┌%s┐%s\n' "$1" "${F[C_FRAME]}" "$BOTTOM_LINE" "$R"
  else
    printf '%s%s┌─ %s%s%s%s %s┐%s\n' "$1" "${F[C_FRAME]}" "${F[C_TITLE]}$BOLD" "$2" "$R" "${F[C_FRAME]}" "$TOP_LINE" "$R"
  fi
}

box_shell() {  # $1=行頭 $2=中の空の行数 $3=色（省略すると本来の色）。タイトルと枠だけの四角を描く
  local i
  if [[ -n $3 ]]; then local C_FRAME=$3 C_TITLE=$3; fi
  box_top "$1" "$BOX_TITLE"
  for ((i = 0; i < $2; i++)); do printf '%s%s│%*s│%s\n' "$1" "${F[C_FRAME]}" $(( W + 25 )) "" "$R"; done
  printf '%s%s└%s┘%s\n' "$1" "${F[C_FRAME]}" "$BOTTOM_LINE" "$R"
}

box_draw() {  # $1=行頭 $2=色（省略すると本来の色）。中身が空のゲージの四角を描く
  if [[ -n $2 ]]; then local C_FRAME=$2 C_TITLE=$2 C_LABEL=$2 C_BAR=$2 C_DIM=$2 C_TEXT=$2 C_OK=$2; fi
  hline TOP_LINE $(( W + 22 - ${#BOX_TITLE} ))
  hline BOTTOM_LINE $(( W + 25 ))
  gauge_frame 0 "$1"
}

date_line() {  # $1=行頭
  printf '%s%s//%s ── %s%s\n' "$1" "${F[C_BAR]}" "$(date '+%Y-%m-%d %a' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
}

go_line() {  # $1=行頭 $2=マークの上端からこの行までの行数（省略時はマークを回さない）。WARNING があれば件数を赤で出す
  # 文字が崩れている間もマークを回し、最後の文字が出たところで止める
  local n=0 k msg col=$C_TITLE p i=0
  for k in "${!WARN[@]}"; do (( n += WARN[k] )); done
  if (( n > 0 )); then msg="▲ $n WARNING$( (( n > 1 )) && echo S)" col=$C_WARN
  else msg="▲ ALL SYSTEMS GO"; fi
  for p in 70 40 15; do
    printf '\r%s%s%s%s' "$1" "${F[col]}$BOLD" "$(noisy "$msg" $p)" "$R"
    [[ -n $2 ]] && spin "$2" $(( MARK_FLASH + i++ ))  # 中心から白い光が広がる
    pause 0.06
  done
  [[ -n $2 ]] && spin "$2" "$MARK_END"  # 止まったときの絵（虹色の同心の輪）にする
  printf '\r%s%s%s%s\n' "$1" "${F[col]}$BOLD" "$msg" "$R"
}

one_line() {
  local k out col
  for k in "${!LABEL[@]}"; do
    if (( PCT[k] < 0 )); then col=$C_DIM
    elif (( WARN[k] )); then col=$C_WARN
    else col=$C_BAR; fi
    out+="${F[C_LABEL]}${LABEL[k]}$R ${F[col]}${INFO[k]}$R  "
  done
  printf '%s▲%s %s%s%s\n' "${F[C_TITLE]}$BOLD" "$R" "$out" "${F[C_FRAME]}" "$(date '+%m/%d %H:%M')$R"
}

# ── 本体 ──────────────────────────────────────
if (( ${WELCOME_LINE:-0} )); then
  collect
  one_line
elif (( COLS >= 29 + MIN_W && ROWS >= ${#LABEL[@]} + 5 )); then
  # 四角は光と同じ幅にそろえる（バーの長さで調整）。バーが長くても伸びきるまでの時間は変わらないよう、1マスの間隔を縮める
  fx_size
  echo
  if tunnel_play; then
    # 大きな文字・すき間1行・四角を合わせて、光と同じ FX_W 列 × FX_H 行（16:9）にする
    W=$(( FX_W - 27 ))
    printf -v GAUGE_STEP '0.%03d' $(( 600 / W ))
    col=$FX_COL
    banner_make "$FX_W" $(( FX_H - 1 - BOX_H ))
    # 余った行は、四角の中のすき間（上端・ゲージの間・下端）に上下対称になるよう配る。割り切れない1行は文字と四角の間へ
    extra=$(( FX_H - ${#BANNER[@]} - 1 - BOX_H )) gap=1
    for i in "${!BOX_PAD[@]}"; do BOX_PAD[i]=$(( extra / 6 )); done
    rem=$(( extra % 6 ))
    if (( rem >= 4 )); then for i in 1 2 3 4; do (( BOX_PAD[i]++ )); done; rem=$(( rem - 4 )); fi
    if (( rem >= 2 )); then (( BOX_PAD[0]++, BOX_PAD[5]++ )); rem=$(( rem - 2 )); fi
    gap=$(( gap + rem ))
    BOX_H=$(( BOX_H + extra - rem ))
  else  # 光を流せない（狭い、python3 がない）ときは四角だけ。大きな文字は入れば出す
    (( COLS - 29 < W )) && W=$(( COLS - 29 ))
    col=3
    banner_make $(( W + 27 )) $(( ROWS - BOX_H - 4 ))
    (( BANNER_W > W + 27 || ROWS < BOX_H + 4 + ${#BANNER[@]} )) && BANNER=()
  fi
  pre=$'\033['"${col}G"
  BOX_TITLE=${BOX_TITLE:0:W+18}  # 四角の幅に入りきらないタイトルは切る
  if (( ${#BANNER[@]} )); then
    banner_fade $'\033['"$(( col + (W + 27 - BANNER_W) / 2 ))G"
    for ((i = 0; i < ${gap:-1}; i++)); do echo; done
  fi
  collect
  box_grow "$pre"
  gauges "$pre" none
  date_line "$pre"
  go_line "$pre"
else
  collect
  one_line
fi
