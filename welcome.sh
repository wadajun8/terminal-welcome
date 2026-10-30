#!/usr/bin/env bash
# ターミナル・ウェルカム画面（リンクスタート風）
#   「WELCOME TO YOUR WORLD」が大きくフェードインするのと同時に、その下の四角が中心から縦と横へ広がる
#   （大きな文字と四角を合わせて、窓の横幅に合わせた 16:9）→ PC の機種名とゲージが出る → ゲージが貯まる → 日付 → ALL SYSTEMS GO
#   （リンクスタート風の光の演出 tunnel_play は、いまは止めている。full() の中のコメントを外せば戻る）
#   16:9 が入らない: 四角だけ（狭ければバーを縮める） / それも無理: 1行の要約
#   演出中に何かキーを押すと、残りを飛ばして最後の画面を即表示する
#   使い方: welcome.sh [--full | --line | --auto]
#     --full（既定）: 演出つき / --line: 1行の要約だけ（軽い。ターミナルを開くたびに出す用）
#     --auto: PC を起動（再起動）して最初の1回だけ --full、2回目以降は --line（~/.cache/terminal-welcome/boot に記録）
#   環境変数: PALETTE=<配色名>（下の一覧から）/ WELCOME_SKIP=1 で演出なし / WELCOME_LINE=1 で --line と同じ
#             BANNER_TEXT=<大きく出す言葉>（| で2行に分ける）/ BOX_TITLE=<四角のタイトル>（空なら線だけ）
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/demo/lib.sh"
SKIP=${WELCOME_SKIP:-0}

# ── 設定 ──────────────────────────────────────
# 配色（256色の番号）: 枠 / ゲージ / ラベル / NOMINAL / タイトルと GO / WARNING
case ${PALETTE:-tron} in
  neon)      read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'93 51 213 87 201 196' ;;
  synthwave) read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'97 208 205 228 199 196' ;;
  matrix)    read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'22 40 28 157 46 196' ;;
  akira)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'88 203 167 255 196 226' ;;
  vapor)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'104 159 218 195 213 203' ;;
  amber)     read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'130 214 172 230 220 196' ;;
  *)         read -r C_FRAME C_BAR C_LABEL C_OK C_TITLE C_WARN <<<'24 45 31 255 51 208' ;;  # tron（採用）
esac
C_DIM=238 C_TEXT=255                 # 空のゲージ・OFFLINE / 数値の文字
W=12                                # ゲージの長さ
WARN_MEM=90 WARN_DISK=90             # 以上で WARNING
WARN_BAT=20                          # 以下かつ AC 電源なしで WARNING
WARN_GPU_TEMP=85                     # 以上で WARNING（℃）
MIN_W=4                              # 狭いときに縮めるゲージの最短の長さ
GAUGE_STEP=0.05                      # ゲージが1マス進む間隔（秒）。光の幅に合わせてバーを伸ばすときは、伸びきる時間が同じになるよう縮める
FX_STEP=0.02                         # 光のコマの間隔（秒）


# 色コードを最初に作っておく（${F[51]} などで使う）。描画のたびに $(...) を起動すると遅いため
F=()
for i in {0..255}; do printf -v "F[$i]" '\033[38;5;%sm' "$i"; done

COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
ROWS=${LINES:-$(tput lines 2>/dev/null || echo 24)}

# ── 値の取得 ──────────────────────────────────
# nvidia-smi は遅いので最初に裏で走らせ、待ち時間を光の演出で隠す
GPU_TMP=$(mktemp)
STTY_SAVED=
trap '[[ -t 1 ]] && tput cnorm 2>/dev/null; [[ -n $STTY_SAVED ]] && stty "$STTY_SAVED" 2>/dev/null; rm -f "$GPU_TMP"' EXIT
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

BANNER_TEXT=${BANNER_TEXT:-WELCOME TO|YOUR WORLD}   # 大きく出す言葉。| で2行に分ける（入りきらなければ1行にする）
pc_name() {  # この PC の機種名（例: THINKPAD X1 CARBON）。取れなければ OS の名前
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
# ゲージごとに ラベル / 割合（-1 は取得できず）/ 右に出す文字 / WARNING なら 1
LABEL=(CPU MEM DISK GPU BAT)
PCT=(100 100 100 100 100) INFO=() WARN=()  # 値を測る前は、四角を「CHECKING」で描くため仮に 100 にしておく
BOX_H=$(( ${#LABEL[@]} + 2 ))
BOX_PAD=(0 0 0 0 0 0)                      # 四角の中の空の行数（上端、各ゲージの下）。16:9 に合わせて増やす

collect() {
  local t1 i1 dt v total avail used tot temp cap ac bat acp

  read -r t1 i1 < <(cpu_sample)
  dt=$((t1 - CPU_T0))
  for _ in 1 2 3 4 5; do  # 測る間隔が短すぎる（1行の要約や、演出を飛ばしたとき）ときだけ、少しずつ待って測り直す
    (( dt >= 16 )) && break
    sleep 0.02
    read -r t1 i1 < <(cpu_sample)
    dt=$((t1 - CPU_T0))
  done
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

gauges() {  # $1=行頭。カーソルを四角の上端に置いて呼ぶ。ゲージを1マスずつ伸ばしながら四角を描き直す
  local s last=$(( W + (${#LABEL[@]} - 1) * 2 ))
  hline TOP_LINE $(( W + 22 - ${#BOX_TITLE} ))
  hline BOTTOM_LINE $(( W + 25 ))
  for ((s = 0; s <= last; s++)); do
    (( SKIP )) && s=$last  # キーが押されたら伸びきった状態へ
    (( s > 0 )) && printf '\033[%dA' "$BOX_H"
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
  local w=$FX_W h=$FX_H k n off=$FX_COL cache gen="$HERE/tools/gen_tunnel.py" fr
  (( w >= 40 && h >= 9 )) && command -v python3 >/dev/null 2>&1 || return 1
  cache=${XDG_CACHE_HOME:-$HOME/.cache}/terminal-welcome/tunnel-${w}x${h}.txt
  if [[ ! -s $cache || $gen -nt $cache ]]; then
    mkdir -p "${cache%/*}" && python3 "$gen" --cols "$w" --rows "$h" >"$cache" 2>/dev/null || return 1
    # 窓の大きさごとに増えるので、新しい 5 つだけ残す
    local old
    mapfile -t old < <(ls -t "${cache%/*}"/tunnel-*.txt 2>/dev/null | tail -n +6)
    (( ${#old[@]} )) && rm -f "${old[@]}"
  fi
  mapfile -t fr <"$cache"
  n=$(( ${#fr[@]} / h ))
  for ((k = 0; k < h; k++)); do echo; done
  for ((k = 0; k < n; k++)); do
    (( SKIP )) && k=$(( n - 1 ))  # キーが押されたら最後のコマへ
    printf '\033[%dA' "$h"
    printf "\033[${off}G%s\n" "${fr[@]:k*h:h}"
    pause "$FX_STEP"
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

intro() {  # $1=四角の左端の列 $2=大きな文字の行頭 $3=文字と四角の間の行数
  # 大きな文字のフェードインと同時に、枠だけの四角を中心から縦と横へ同時に広げる。カーソルは四角の上端に置く
  local n=8 k i fade=(236 238 241 245 "") bw=$(( W + 27 )) ww hh off col gap=0 lines BOX_TITLE= BOTTOM_LINE
  (( ${#BANNER[@]} )) && gap=$3
  lines=$(( ${#BANNER[@]} + gap + BOX_H ))
  for ((i = 0; i < lines; i++)); do echo; done
  printf '\033[%dA' "$lines"
  for ((k = 1; k <= n; k++)); do
    (( SKIP )) && k=$n  # キーが押されたら最後のコマへ
    col=${fade[(k - 1) * 4 / (n - 1)]}
    (( ${#BANNER[@]} )) && banner_draw "$2" "$col"
    ww=$(( 2 + (bw - 2) * k / n )) hh=$(( 2 + (BOX_H - 2) * k / n ))
    off=$(( gap + (BOX_H - hh) / 2 ))  # 四角の上端までの行数（縦も中心から広がるように）
    for ((i = 0; i < off; i++)); do echo; done
    local W=$(( ww - 27 ))  # box_shell は W から幅を決めるので、このコマの幅に合わせる
    hline BOTTOM_LINE $(( ww - 2 ))
    box_shell $'\033['"$(( $1 + (bw - ww) / 2 ))G" $(( hh - 2 )) "$col"
    printf '\033[%dA' $(( ${#BANNER[@]} + off + hh ))  # 次のコマのために一番上へ戻る
    pause 0.03
  done
  for ((i = 0; i < ${#BANNER[@]} + gap; i++)); do echo; done
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

date_line() {  # $1=行頭
  printf '%s%s//%s ── %s%s\n' "$1" "${F[C_BAR]}" "$(date '+%Y-%m-%d %a' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
}

go_line() {  # $1=行頭。崩れた文字から整って出る。WARNING があれば件数を赤で出す
  local n=0 k msg col=$C_TITLE p
  for k in "${!WARN[@]}"; do (( n += WARN[k] )); done
  if (( n > 0 )); then msg="▲ $n WARNING$( (( n > 1 )) && echo S)" col=$C_WARN
  else msg="▲ ALL SYSTEMS GO"; fi
  for p in 70 40 15; do
    printf '\r%s%s%s%s' "$1" "${F[col]}$BOLD" "$(noisy "$msg" $p)" "$R"
    pause 0.06
  done
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
full() {  # 演出つき。光 → 大きな文字 → 四角 → ゲージ → 日付 → GO
  local col pre extra gap=1 rem i
  if (( COLS < 29 + MIN_W || ROWS < ${#LABEL[@]} + 5 )); then  # 四角も入らないほど狭ければ1行の要約
    collect
    one_line
    return
  fi
  # 演出中に打ったキーが画面に出て絵が崩れないよう、文字の表示を止める（終わったら戻す）
  if [[ -t 0 ]]; then
    STTY_SAVED=$(stty -g 2>/dev/null) && stty -echo 2>/dev/null
  fi
  fx_size
  echo
  # if tunnel_play; then  # ソードアート・オンライン風の光の演出（いまは止めている。戻すときはこの行を生かし、下の行を消す）
  if (( FX_W >= 40 && FX_H >= 9 )); then
    # 大きな文字・すき間1行・四角を合わせて、光と同じ FX_W 列 × FX_H 行（16:9）にする。
    # 四角は光と同じ幅にそろえる（バーの長さで調整）。バーが長くても伸びきるまでの時間は変わらないよう、1マスの間隔を縮める
    W=$(( FX_W - 27 ))
    printf -v GAUGE_STEP '0.%03d' $(( 600 / W ))
    col=$FX_COL
    banner_make "$FX_W" $(( FX_H - 1 - BOX_H ))
    # 余った行は、四角の中のすき間（上端・ゲージの間・下端）に上下対称になるよう配る。割り切れない1行は文字と四角の間へ
    extra=$(( FX_H - ${#BANNER[@]} - 1 - BOX_H ))
    for i in "${!BOX_PAD[@]}"; do BOX_PAD[i]=$(( extra / 6 )); done
    rem=$(( extra % 6 ))
    if (( rem >= 4 )); then for i in 1 2 3 4; do (( BOX_PAD[i]++ )); done; rem=$(( rem - 4 )); fi
    if (( rem >= 2 )); then (( BOX_PAD[0]++, BOX_PAD[5]++ )); rem=$(( rem - 2 )); fi
    gap=$(( gap + rem ))
    BOX_H=$(( BOX_H + extra - rem ))
  else  # 16:9 が入らないほど狭いときは四角だけ。大きな文字は入れば出す
    (( COLS - 29 < W )) && W=$(( COLS - 29 ))
    col=3
    banner_make $(( W + 27 )) $(( ROWS - BOX_H - 4 ))
    (( BANNER_W > W + 27 || ROWS < BOX_H + 4 + ${#BANNER[@]} )) && BANNER=()
  fi
  pre=$'\033['"${col}G"
  BOX_TITLE=${BOX_TITLE:0:W+18}  # 四角の幅に入りきらないタイトルは切る
  intro "$col" $'\033['"$(( col + (W + 27 - BANNER_W) / 2 ))G" "$gap"
  collect  # 四角が広がる間に、nvidia-smi と CPU の計測が進む
  gauges "$pre"
  date_line "$pre"
  go_line "$pre"
}

auto_mode() {  # 起動ごとに変わる ID（boot_id）を記録しておき、同じなら2回目以降とみなす
  local stamp=${XDG_CACHE_HOME:-$HOME/.cache}/terminal-welcome/boot boot
  boot=$(</proc/sys/kernel/random/boot_id) 2>/dev/null || { echo full; return; }
  if [[ $(<"$stamp") == "$boot" ]] 2>/dev/null; then
    echo line
  else
    mkdir -p "${stamp%/*}" && echo "$boot" >"$stamp"
    echo full
  fi
}

main() {
  local mode=full
  (( ${WELCOME_LINE:-0} )) && mode=line
  case ${1:-} in
    --full) mode=full ;;
    --line) mode=line ;;
    --auto) mode=$(auto_mode) ;;
    -h | --help) sed -n '2,/^HERE=/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; return ;;
  esac
  if [[ $mode == line ]]; then
    collect
    one_line
  else
    full
  fi
}

main "$@"
