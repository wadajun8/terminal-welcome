# terminal-welcome

ターミナルを開くと、「WELCOME TO YOUR WORLD」と、**今のマシンの状態（CPU・メモリ・ディスク・GPU・バッテリー）を示すゲージ**が出るウェルカム画面です。bash だけで動きます。

## クイックスタート

```bash
# 1. 取ってくる
git clone https://github.com/wadajun8/terminal-welcome.git ~/terminal-welcome

# 2. 試しに表示する
bash ~/terminal-welcome/welcome.sh

# 3. ターミナルを開いたときに出るようにする（~/.bashrc の末尾に1行足す）
echo '[[ $- == *i* && -t 1 && ${SHLVL:-1} -le 1 ]] && bash ~/terminal-welcome/welcome.sh --auto' >> ~/.bashrc
```

3 の設定では、**PC を起動して最初に開いたときだけ演出つき**、2回目以降は1行の要約だけが出ます（何度開いても待たされません）。演出中は**何かキーを押すとすぐ最後の画面に飛びます**。

## 画面の例

```

        ╻ ╻┏━╸╻  ┏━╸┏━┓┏┳┓┏━╸   ╺┳╸┏━┓   ╻ ╻┏━┓╻ ╻┏━┓   ╻ ╻┏━┓┏━┓╻  ╺┳┓
        ┃╻┃┣╸ ┃  ┃  ┃ ┃┃┃┃┣╸     ┃ ┃ ┃   ┗┳┛┃ ┃┃ ┃┣┳┛   ┃╻┃┃ ┃┣┳┛┃   ┃┃
        ┗┻┛┗━╸┗━╸┗━╸┗━┛╹ ╹┗━╸    ╹ ┗━┛    ╹ ┗━┛┗━┛╹┗╸   ┗┻┛┗━┛╹┗╸┗━╸╺┻┛

  ┌─ LAPTOP MODEL  ───────────────────────────────────────────────────────────┐
  │                                                                          │
  │ CPU  ■□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□  2%      NOMINAL  │
  │                                                                          │
  │ MEM  ■■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□  20%     NOMINAL  │
  │                                                                          │
  │ DISK ■■■■■■■■■■■■■■■■■■■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□  56%     NOMINAL  │
  │                                                                          │
  │ GPU  ■■■■□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□  52C     NOMINAL  │
  │                                                                          │
  │ BAT  ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■□  98% AC  NOMINAL  │
  │                                                                          │
  └──────────────────────────────────────────────────────────────────────────┘
  //2026-10-30 FRI ── 22:14:27
  ▲ ALL SYSTEMS GO
```

実際は色つきで、文字がフェードインするのと同時に四角が中心から広がり、ゲージが貯まる、という順に動きます（約1.4秒）。四角のタイトルにはその PC の機種名が入ります。

2回目以降に出る1行の要約：

```
▲ CPU 3%  MEM 16%  DISK 56%  GPU 50C  BAT 95%  10/30 15:02
```

## 表示されるもの

| 項目 | ゲージ | CAUTION（黄）になる条件 | WARNING（赤）になる条件 |
|---|---|---|---|
| CPU | 使用率 | — | — |
| MEM | 使用率 | 80% 以上 | 90% 以上 |
| DISK | `/` の使用率 | 80% 以上 | 90% 以上 |
| GPU | VRAM の使用率（右に温度） | 75℃ 以上 | 85℃ 以上 |
| BAT | 残量（AC 電源につながっていれば `AC`） | 30% 以下で AC 電源なし | 20% 以下で AC 電源なし |

ゲージと値の色は、ふだんはシアン、CAUTION で黄、WARNING で赤になります（1行の要約では、黄・赤のときに項目名も同じ色になります）。WARNING があると最後の行が赤で `▲ N WARNING(S)`、CAUTION だけなら黄で `▲ N CAUTION(S)` になります。GPU やバッテリーがない PC では、その行は `OFFLINE` になります。

## 必要なもの

- **bash**（Linux。値は `/proc` や `/sys` から読みます）
- あるとよいもの（なくても、その部分を省いて動きます）
  - `python3` と numpy：光の演出（いまは止めているので不要）
  - `toilet`：大きな文字（なければ普通の文字）
  - `nvidia-smi`：GPU のゲージ

```bash
sudo apt install python3-numpy toilet   # Ubuntu の場合
```

窓が狭いときは、自動で「四角だけ」→「1行の要約」に切り替わります。

## 使い方

```bash
bash ~/terminal-welcome/welcome.sh           # 演出つき（--full と同じ）
bash ~/terminal-welcome/welcome.sh --line    # 1行の要約だけ
bash ~/terminal-welcome/welcome.sh --auto    # 起動して最初の1回だけ演出、以降は1行
bash ~/terminal-welcome/welcome.sh --help    # 使い方
```

`--auto` で、再起動せずにもう一度フル演出を出したいときは、起動の記録を消します（次に開いたターミナルでフル演出になります）。

```bash
rm -f ~/.cache/terminal-welcome/boot
```

### カスタマイズ

環境変数で変えられます。

| 環境変数 | 内容 | 例 |
|---|---|---|
| `PALETTE` | 配色。`tron`（既定）/ `neon` / `synthwave` / `matrix` / `akira` / `vapor` / `amber` | `PALETTE=matrix` |
| `BANNER_TEXT` | 大きく出す言葉（`\|` で2行に分ける） | `BANNER_TEXT='HELLO\|WORLD'` |
| `BOX_TITLE` | 四角のタイトル（空なら線だけ） | `BOX_TITLE='MY PC'` |
| `WELCOME_SKIP` | `1` で演出なし（最後の画面だけ） | `WELCOME_SKIP=1` |

```bash
PALETTE=matrix bash ~/terminal-welcome/welcome.sh   # 配色を変えて見る
bash ~/terminal-welcome/demo/palettes.sh            # 配色を順に見比べる
```

`~/.bashrc` で使うときは、`--auto` の前に書きます（例：`PALETTE=matrix bash ~/terminal-welcome/welcome.sh --auto`）。CAUTION・WARNING のしきい値やゲージの速さは、`welcome.sh` の先頭の「設定」で変えられます。

## アンインストール

1. `~/.bashrc` から、クイックスタートで足した `welcome.sh --auto` の行を消す
2. ファイルとキャッシュを消す

```bash
rm -rf ~/terminal-welcome ~/.cache/terminal-welcome
```

## ライセンス

[MIT License](LICENSE)
