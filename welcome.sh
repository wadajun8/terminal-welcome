#!/usr/bin/env bash
# ターミナル・ウェルカム画面（プロトタイプ）
#   マーク（ドット絵のレーダー）がフェードイン → ゲージが実際の値まで伸びる間ビームが回る → 日付 → ALL SYSTEMS GO（ここで止まる）
#   幅 70 列以上: マークの右にゲージ / 狭い: マークの下にゲージ
#   マークが入りきらない: ゲージだけ（狭ければバーを縮める） / それも無理: 1行の要約
#   演出中に何かキーを押すと、残りを飛ばして最後の画面を即表示する
#   環境変数: PALETTE=<配色名>（下の一覧から）/ WELCOME_SKIP=1 で演出なし / WELCOME_LINE=1 で1行の要約だけ
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/demo/lib.sh"
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

# マーク: ドット絵のレーダー。ゲージと最後の文字が出ている間だけビームが回り、文字がすべて出たら止まったときの絵（円と十字線だけ）にする
# 1文字の上下2ドットを、文字色（A〜G）と背景色（a〜g）で塗り分ける。z は背景色の解除
#   A=外周の円 B=内側の円と十字線 C=ビーム D=残像（濃） E=残像（薄） F=ブリップ（反応した直後） G=ブリップ（暗く残る）
# 形を変えるときは tools/gen_radar.py を直して --bash の出力を貼り直す
# tools/gen_radar.py --aspect 1.25 で生成（16 コマ ＋ 止まったときの絵 × 14 行、幅 33）
MARK_FRAMES=(
  '         A▄▄▄d▀▀▀▀c▀z▀▀▀▀▄▄▄         '
  '      A▄e▀d▀zD███████C█       A▀▀▄      '
  '   A▄▀e▀zE▀▄▀fD▀b▀▀▀dB▀▀▀zC█B▀▀▀▄▄▄    A▀▀▄   '
  '  A▄e▀zE▀▄▀▄b▀eB▀zD▀█████C█      B▀▄    A▀▄  '
  ' A█E▀▄▀▄b▀eB▀zE▀▄▀▄D▀█b▀▀zC█B▄▄      ▀▄    A█ '
  'A█   E▀B▄▀E▄▀▄▀▄b▀eB▀zD▀█C█  B▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█bE▀z b▀z C█ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀bG▀z       B▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀d▀▀▀b▀d▀▀▀▀z▄▄▄         '
  '      A▄e▀z▀E▄▀▄▀eD▀z██b▀z████c▀zC▀ A▀▀▄      '
  '   A▄▀e▀zE▀▄▀G▄bE▀zB▄bE▀eB▀d▀▀z█d▀▀▀cD▀bC▀zB▄    A▀▀▄   '
  '  A▄▀  E▀▄b▀eB▀zE▀▄▀▄▀D█b▀z██c▀zC▀  B▀▄    A▀▄  '
  ' A█    B▄▀E▀ ▀▄▀▄b▀D▀▀▀c▀zC▀     B▀▄    A█ '
  'A█    B▄▀     bE▀eB▀zE▀▄bD▀c▀zC▀B▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ cD▀zC▀B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀▄       ▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀e▀z▀e▀b▀e▀z▀d▀▀z▄▄▄         '
  '      A▄▀▀E▄▀▄▀▄▀▄b▀z▄▀D█████dA▀▀z▄      '
  '   A▄▀▀   G▄bE▀zB▄bE▀eB▀z▀e▀z█e▀d▀▀bD▀▀▀f▀z███cA▀z▀▄   '
  '  A▄▀    B▄▀  E▀▄▀▄b▀z▄D█████dB▀cD▀zC▀▀  A▀▄  '
  ' A█    B▄▀      bE▀zB▄bE▀zB▄bD▀z██c▀▀zC▀ B▀▄    A█ '
  'A█    B▄▀     ▄▀E▀▄b▀zD██cB▀bC▀z     B▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ cE▀zC▀b▀z B▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀▄       ▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀e▀b▀e▀z▀e▀z▀▄▄▄         '
  '      A▄▀▀      E▄b▀z▄▀▄▀▄▀▄dA▀▀z▄      '
  '   A▄▀▀   G▄B▄▄▄▀▀e▀z█e▀z▀e▀bE▀zB▄bE▀zF▄D███dA▀▀z▄   '
  '  A▄▀    B▄▀      bE▀z▄▀▄▀D▄█dB▀bD▀z████dA▀z▄  '
  ' A█    B▄▀      ▄▄bE▀zB▄bE▀z▄D█████dB▀cD▀▀▀zC▀▀A█ '
  'A█    B▄▀     ▄▀  bE▀z▄d▀B▀bD▀c▀▀zC▀▀▀B▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ cE▀D▀bC▀z▀b▀zB█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀▄       ▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄   E▀▄▀▄A▀e▀z▄      '
  '   A▄▀▀   G▄B▄▄▄▀▀▀█▀▀e▀bE▀zB▄bE▀zG▄E▀▄▀eA▀z▀▄   '
  '  A▄▀    B▄▀      ▄  E▄▀▄▀eB▀bE▀z▄▀D▄dE▀A▀z▄  '
  ' A█    B▄▀      ▄▄▄▄bE▀z▄▀▄▀▄d▀B▀bD▀z████A█ '
  'A█    B▄▀     ▄▀  ▄E▄▀eB▀bE▀zD▄████dB▀bD▀z████A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄▄cD▀▀▀B▀D▀▀▀▀▀B▀D▀▀▀▀zA█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀▄       ▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄G▄ E▄▀eA▀z▀▄   '
  '  A▄▀    B▄▀      ▄      e▀bE▀z▄▀▄▀eA▀z▄  '
  ' A█    B▄▀      ▄▄▄▄▄  E▄▀▄▀eB▀bE▀z▄▀▄▀A█ '
  'A█    B▄▀     ▄▀  ▄  e▀bE▀z▄▀▄▀▄B▀▄dE▀zD▄dE▀zD▄A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄▄bE▀zD▄bE▀zB█bD▀z█b▀z█b▀zB█bD▀z█b▀z█A█'
  'A█    B█     ▀▄   ▄ C▀▀b▀cB▀D▀z████B█D████A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀   C▀▀▀cB▀D▀▀z██a▀zA▀'
  ' A▀▄    B▀▄       ▄       ▄▀   C▀a▀zA▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄G▄   A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    eA▀z▄  '
  ' A█    B▄▀      ▄▄▄▄▄      e▀z▄E▄▀▄▀A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄E▄ ▄▀▄B▀▄E▀▄▀▄A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄E▄B▄E▄b▀zB█bE▀z▄b▀z▄b▀zB█bE▀z▄b▀z▄A█'
  'A█    B█     ▀▄   ▄C▀▀cD▀b▀dB▀zD██dE▀zD▄dE▀zB█dE▀zD▄dE▀z▄A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀C▀cD▀▀z███B█D████a▀zA▀'
  ' A▀▄    B▀▄       ▄      C▀cF▀dB▀zD████a▀zA▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀ C▀d▀cD▀z█A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄G▄   A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄E▄B▄E▄B▄█▄E▄B▄E▄b▀zB█bE▀z▄b▀z▄A█'
  'A█    B█     ▀▄   ▄C█dE▀zD▄bE▀eB▀zE▀▄▀▄▀B█E▀▄▀▄A█'
  'A▀▄    B█      ▀▄▄▄▄C█dB▀zD██dE▀zD▄E▀▄B█E▄▀▄▀A▄▀'
  ' A▀▄    B▀▄       ▄  C█D████bF▀dB▀E▀zD▄E▀▄a▀zA▀ '
  '   A█     B▀▄▄▄   ▄   C█bD▀▀dB▀zD█████A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀ C█D████a▀zA▀▀    '
  '       A▀▀▄▄▄    B▄    A▄aC▀D▀zA▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   C█D▄E▀▄b▀eB▀z E▄ ▄ B█    A█'
  'A▀▄    B█      ▀▄▄C█bD▀▀dB▀zE▀▄▀▄▀▄B█E▄▀▄ A▄▀'
  ' A▀▄    B▀▄       C█D████▄E▀▄bG▀eB▀zE▀▄▀▄a▀zA▀ '
  '   A█     B▀▄▄▄   C█D███b▀▀▀dB▀zE▀▄▀▄▀A█   '
  '    A▀▀▄      B▀▀▀C█dB▀▀▀zD████dE▀z▄a▀zA▀▀    '
  '       A▀▀▄▄▄    C█D████a▀▀▀zA▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄  C█bD▀zE▄ ▄B▄▀     █    A█'
  'A▀▄    B█      ▀C█bD▀▀zB▄bE▀eB▀zE▀▄    B█    A▄▀'
  ' A▀▄    B▀▄    C█D██b▀z█E▀▄▀▄▀▄bG▀eB▀z    A▄▀ '
  '   A█     B▀▄▄C█D███b▀z█dE▀z▄b▀zB▄bE▀eB▀zE▀▄▀▄ A█   '
  '    A▀▀▄    C█D█dB▀▀▀z█d▀▀e▀zE▀▄▀▄▀▄a▀zA▀▀    '
  '       A▀▀▄aC▀D▀z████b▀z███E▀A▄aE▀zA▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ C▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄C▄d▀▀bE▀z▄  B▄▀     █    A█'
  'A▀▄    B█   C▄▄d▀B▀bD▀▀E▀zB▄bE▀zB▀      █    A▄▀'
  ' A▀▄    B▀C▄d▀zD█████E▄b▀z▄▀▄    bG▀zB▀    A▄▀ '
  '   A█ C▄d▀▀zD█dB▀bD▀▀▀z██E▄b▀z▄▀▄b▀zB▄▄▀     A█   '
  '    A▀▀aD▀z██████dB▀z▀e▀z█e▀z▀e▀zE▀▄▀▄  A▄▀▀    '
  '       A▀▀aD▀▀▀z██E▀▄b▀z▄▀▄▀A▄aE▀zA▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄C▄▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█    C▄cB▀bC▀d▀▀eD▀bE▀z   B▄▀     █    A█'
  'A▀▄  C▄▄cB▀dC▀▀▀zD███eB▀bE▀zB▄bE▀zB▄▄▀      █    A▄▀'
  ' A▀aC▀d▀zD███dB▀bF▀zD███▀E▄▀▄b▀z       bG▀zB▀    A▄▀ '
  '   A█D█████dB▀bD▀zB▄bE▀z▄▀▄b▀z▄  B▄▄▄▀     A█   '
  '    A▀▀aD▀z██E▄▀▄▀eB▀z▀e▀z█e▀z▀▀      A▄▀▀    '
  '       A▀▀▄aE▀zA▄E▀▄▀▄b▀z▄   A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█C▄▄▄▄cB▀zC▄▄▄▄▄cB▀zC▄▄▄▄▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█D████B█D█████dB▀bD▀e▀z▀E▄B▄   ▄▀     █    A█'
  'A▀aD▀z████B█D██e▀z▀E▄▀eB▀bE▀zB▄▄▄▄▀      █    A▄▀'
  ' A▀aD▀z███▀eB▀bF▀zE▄▀▄▀▄▀ B▄       ▄▀    A▄▀ '
  '   A█E▀▄▀▄▀eB▀bE▀zB▄bE▀z▄  B▄   ▄▄▄▀     A█   '
  '    A▀▀aE▀z▄▀▄▀▄▀B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄aE▀zA▄E▀   B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█dC▀▀z▄▄▄B▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█D████b▀dB▀C▀▀▀z▄▄B▄▀  ▄  ▀▄     ▀▄    A█'
  'A█D█b▀z█b▀zB█bD▀z█b▀z█b▀zB█bC▀d▀b▀z▄▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█D████B█D▀e▀z▀e▀z▀eB▀bE▀z▄▀ B▄   ▄▀     █    A█'
  'A▀▄E▀▄▀▄B█E▄▀▄▀▄▀B▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀aE▀z▄▀▄▀eB▀bG▀zE▄▀     B▄       ▄▀    A▄▀ '
  '   A█E▀▄▀▄▀B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀aE▀z      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄d▀c▀zD▄   B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄d▀zD██dC▀▀z▄B▀      ▄      ▀▄    A▀▄  '
  ' A█D████b▀dB▀zD█dC▀z▄▄  B▄▄▄▄▄      ▀▄    A█ '
  'A█eD▀z███b▀dB▀zD█████bC▀cB▀z  ▄  ▀▄     ▀▄    A█'
  'A█E▄b▀z▄b▀zB█bE▀z▄b▀eD▀b▀zB█bD▀e▀bC▀e▀z▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█E▄▀▄▀B█E▀▄▀▄▀eB▀bE▀z   B▄   ▄▀     █    A█'
  'A▀▄E▀▄▀▄B█E▄▀    B▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀aE▀z▄▀  B▀bG▀z       B▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄d▀▀zD█dC▀z▄    B▄       A▀▀▄      '
  '   A▄d▀▀zD███f▀b▀C▀z▄B▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄e▀zD▀███b▀dB▀zD██dC▀z▄  B▄      ▀▄    A▀▄  '
  ' A█E▀▄▀▄b▀eB▀zD▀████dC▀z▄B▄▄▄▄      ▀▄    A█ '
  'A█E▄▀▄▀B▄▀E▄▀▄▀eD▀b▀dB▀C▀z▄B▄  ▀▄     ▀▄    A█'
  'A█E▄b▀z▄b▀zB█bE▀z▄b▀z▄b▀zB█bE▀z▄b▀eC▀z▄ B▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█ E▀ ▀B█E▀    B▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀bG▀z       B▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
  '         A▄▄▄▀▀▀▀b▀z▀▀▀▀▄▄▄         '
  '      A▄▀▀       B▄       A▀▀▄      '
  '   A▄▀▀    B▄▄▄▀▀▀█▀▀▀▄▄▄    A▀▀▄   '
  '  A▄▀    B▄▀      ▄      ▀▄    A▀▄  '
  ' A█    B▄▀      ▄▄▄▄▄      ▀▄    A█ '
  'A█    B▄▀     ▄▀  ▄  ▀▄     ▀▄    A█'
  'A█ B▄ ▄█▄ ▄ ▄█▄ ▄ ▄ ▄ ▄█▄ ▄ ▄█▄ ▄ A█'
  'A█    B█     ▀▄   ▄   ▄▀     █    A█'
  'A▀▄    B█      ▀▄▄▄▄▄▀      █    A▄▀'
  ' A▀▄    B▀▄       ▄       ▄▀    A▄▀ '
  '   A█     B▀▄▄▄   ▄   ▄▄▄▀     A█   '
  '    A▀▀▄      B▀▀▀█▀▀▀      A▄▀▀    '
  '       A▀▀▄▄▄    B▄    A▄▄▄▀▀       '
  '            A▀▀▀▀▀▀▀▀▀            '
)
MARK_N=16 MARK_END=16 MARK_H=14 MARK_W=33
MARK_TONES=("$C_BAR" "$C_FRAME" "$MARK_COLOR" "$C_LABEL" "$C_FRAME" 46 28)  # A〜G の色。ブリップ（反応）はどの配色でも緑

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
LABEL=(CPU MEM DISK GPU BAT)
PCT=() INFO=() WARN=()

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
  local r line i c tone cls=ABCDEFG
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

gauge_frame() {  # $1=ステップ数（序盤ほどタイトルが崩れる） $2=行頭
  local s=$1 pre=$2 p=$(( 60 - $1 * 10 )) k
  (( p < 0 )) && p=0
  printf '%s%s┌─ %s%s%s%s %s┐%s\n' \
    "$pre" "${F[C_FRAME]}" "${F[C_TITLE]}$BOLD" "$(noisy "PRE-FLIGHT CHECK" $p)" "$R" "${F[C_FRAME]}" "$TOP_LINE" "$R"
  for k in "${!LABEL[@]}"; do gauge_row "$k" $(( s - k * 2 )) "$pre"; done
  printf '%s%s└%s┘%s\n' "$pre" "${F[C_FRAME]}" "$BOTTOM_LINE" "$R"
}

gauges() {  # $1=行頭 $2=マークの位置（right: マークの右 / below: マークの下 / none: マークなし）
  # right と below では、呼ぶ前にマークを描き終えてカーソルをその次の行に置いておく。
  # 毎フレーム、マークの上端までカーソルを戻してマークを1コマ進め、続けてゲージを描き直す
  local s last=$(( W + (${#LABEL[@]} - 1) * 2 )) box_h=$(( ${#LABEL[@]} + 2 )) cur=$MARK_H
  hline TOP_LINE $(( W + 6 ))
  hline BOTTOM_LINE $(( W + 25 ))
  for ((s = 0; s <= last; s++)); do
    if [[ $2 == none ]]; then
      (( s > 0 )) && printf '\033[%dA' "$box_h"
    else
      printf '\033[%dA' "$cur"
      MARK_K=$(( s % MARK_N ))
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

date_line() {  # $1=行頭
  printf '%s%s//%s ── %s%s\n' "$1" "${F[C_BAR]}" "$(date '+%Y-%m-%d %a' | tr a-z A-Z)" "$(date +%H:%M:%S)" "$R"
}

go_line() {  # $1=行頭 $2=マークの上端からこの行までの行数（省略時はマークを回さない）。WARNING があれば件数を赤で出す
  # 文字が崩れている間もマークを回し、最後の文字が出たところで止める
  local n=0 k msg col=$C_TITLE p
  for k in "${!WARN[@]}"; do (( n += WARN[k] )); done
  if (( n > 0 )); then msg="▲ $n WARNING$( (( n > 1 )) && echo S)" col=$C_WARN
  else msg="▲ ALL SYSTEMS GO"; fi
  for p in 70 40 15; do
    printf '\r%s%s%s%s' "$1" "${F[col]}$BOLD" "$(noisy "$msg" $p)" "$R"
    [[ -n $2 ]] && spin "$2"
    pause 0.06
  done
  [[ -n $2 ]] && spin "$2" "$MARK_END"  # 止まったときの絵（円と十字線だけ）にする
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
elif (( COLS >= WIDE_COLS && ROWS >= MARK_H + 4 )); then
  # マークの右にゲージ。マークの上から BOX_TOP 行目にゲージ枠の上端をそろえる
  # （以下、マークの上端を 0 行目として、カーソルが何行目にいるかを数えている）
  BOX_TOP=2
  pre=$'\033['"$(( 2 + MARK_W + 3 ))G"
  echo
  mark_fade
  collect
  gauges "$pre" right                    # → BOX_TOP + 7 行目
  echo
  date_line "$pre"
  go_line "$pre" $(( BOX_TOP + 9 ))      # → BOX_TOP + 10 行目
  printf '\033[%dB\n' $(( MARK_H - BOX_TOP - ${#LABEL[@]} - 5 ))
elif (( COLS >= NARROW_COLS && ROWS >= MARK_H + ${#LABEL[@]} + 10 )); then
  # マークの下にゲージ
  echo
  mark_fade
  collect
  gauges "  " below                      # → MARK_H + 8 行目
  echo
  date_line "  "
  go_line "  " $(( MARK_H + 10 ))        # → MARK_H + 11 行目
  echo
elif (( COLS >= 29 + MIN_W && ROWS >= ${#LABEL[@]} + 5 )); then
  # マークが入りきらないのでゲージだけ。幅が足りなければバーを縮める
  (( COLS - 29 < W )) && W=$(( COLS - 29 ))
  collect
  gauges "  " none
  date_line "  "
  go_line "  "
else
  collect
  one_line
fi
