#!/usr/bin/env python3
"""噛み合う2つの歯車を、回転の各コマごとにブロック文字で描く（参考: 12122.png）。

使い方:
  python3 gen_gears.py --bash          # welcome.sh に貼る bash 配列を出力する
  python3 gen_gears.py --png OUT.png   # 全コマを tron の色で画像にして確認する

1文字 = 横1ピクセル × 縦2ピクセル（端末の文字は縦長なので、ほぼ正方形のピクセルになる）。
上のピクセルは「▀」の文字色、下のピクセルは背景色で塗るので、1文字に2色まで使える。

各ピクセルは歯車の層（本体・円盤・リング・ハブ）のどれかに分類する。bash 用の出力では
文字色を A〜D、背景色を a〜d、背景色の解除を z で表し、welcome.sh 側で色コードに置き換える。
  A/a = 本体（明るい） B/b = 円盤（暗い） C/c = リング（明るい） D/d = ハブ（暗い）
"""
import math
import sys
from collections import Counter

W, H = 33, 32          # 横の文字数, 縦のピクセル数（= 16 行）
FRAMES = 8             # 歯1枚分回る間のコマ数（多いほどなめらかで、ゆっくりに見える）
SS = 4                 # 1ピクセルを SS×SS 点で判定して多数決をとる（縁のガタつきを減らす）

# 中心, ピッチ半径, 歯数, 歯の高さ
# 参考画像は 12枚歯/8枚歯だが、この解像度では歯がつぶれるので 8枚/6枚にしている（teeth_compare.png で比較）
# 中心はピクセルの角（整数の座標）に置く。半端な位置だと同心円が左右非対称になり、中心の穴が汚く見える
G1 = dict(cx=12.0, cy=12.0, rp=8.4, n=8, a=2.4)
G2_N = 6
G2 = dict(cx=24.0, cy=23.0, rp=G1["rp"] * G2_N / G1["n"], n=G2_N, a=2.4)   # 半径は歯数の比で決める
CONTACT = math.atan2(-(G2["cy"] - G1["cy"]), G2["cx"] - G1["cx"])       # 大きい歯車から見た小さい歯車の方向
# 中心の距離（約16.3）はピッチ半径の和（14.7）より少し広い。低解像度でも2つに見えるようにするため

# 歯の形: 谷の深さ（歯の高さに対する比）、根元と先端の歯の幅（歯1枚分の角度に対する比）
# 斜めの歯が丸く見えないよう、歯を高く・谷を深く・先を細くし、塗る基準を少し厳しくしている
DED = 0.8
TW_ROOT, TW_TIP = 0.30, 0.13
FILL = 0.6             # ピクセルのこの割合以上が歯車にかかっていたら塗る（大きいほど縁が細く鋭くなる）

# 層の境目（ピッチ半径に対する比）。外から 本体 → 円盤 → リング → ハブ → 穴
LAYERS = [(0.56, "A"), (0.38, "B"), (0.23, "C"), (0.11, "D")]


def layer(g, phase, x, y):
    """(x, y) が歯車 g のどの層か。外なら None"""
    dx, dy = x - g["cx"], y - g["cy"]
    d = math.hypot(dx, dy)
    rp, a = g["rp"], g["a"]
    if d > rp + a:
        return None
    if d > rp - a * DED:
        # 歯の部分。台形にするため、根元ほど歯の幅を広くする
        ang = math.degrees(math.atan2(-dy, dx)) - phase
        pitch = 360 / g["n"]
        t = (ang % pitch) / pitch - 0.5            # -0.5〜0.5。0 が歯の中心
        h = (d - (rp - a * DED)) / (a * (1 + DED))  # 0=根元 〜 1=先端
        if abs(t) > TW_ROOT - (TW_ROOT - TW_TIP) * h:
            return None
        return "A"
    for ratio, name in LAYERS:
        if d > rp * ratio:
            return name
    return None                                     # 中心の穴


def phases(k):
    a0 = math.degrees(CONTACT)
    p1_0 = a0 - 180 / G1["n"]                      # 大きい歯車の歯の谷を接点に向ける
    p2_0 = a0 + 180                                 # 小さい歯車の歯を接点に向ける
    p1 = p1_0 + k * (360 / G1["n"]) / FRAMES
    p2 = p2_0 - (p1 - p1_0) * G1["n"] / G2["n"]    # 逆向きに、歯数の比で回る
    return p1, p2


def pixels(k):
    p1, p2 = phases(k)
    grid, owner = [], []
    for y in range(H):
        row, own = [], []
        for x in range(W):
            # 歯車の中か外かは多数決で決め（縁をなめらかにする）、中なら層はピクセル中心で決める
            # （中心で決めると、同心円が上下左右に対称になる）
            votes, n1, n2 = Counter(), 0, 0
            for i in range(SS):
                for j in range(SS):
                    px, py = x + (i + 0.5) / SS, y + (j + 0.5) / SS
                    c1, c2 = layer(G1, p1, px, py), layer(G2, p2, px, py)
                    votes[c1 or c2] += 1
                    n1 += bool(c1)
                    n2 += bool(c2 and not c1)
            if SS * SS - votes[None] < FILL * SS * SS:
                row.append(None)
                own.append(0)
            else:
                center = layer(G1, p1, x + 0.5, y + 0.5) or layer(G2, p2, x + 0.5, y + 0.5)
                row.append(center or max((v, k) for k, v in votes.items() if k)[1])
                own.append(1 if n1 >= n2 else 2)
        grid.append(row)
        owner.append(own)
    # 同じ色の歯車どうしが接すると1つの塊に見えるので、大きい歯車に隣接する小さい歯車のピクセルを消して
    # 1ピクセルのすき間（参考画像の黒い輪郭の代わり）を作る
    for y in range(H):
        for x in range(W):
            if owner[y][x] == 2 and any(
                    0 <= y + dy < H and 0 <= x + dx < W and owner[y + dy][x + dx] == 1
                    for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                grid[y][x] = None
    return grid


def bash_lines(grid):
    lines = []
    for r in range(0, H, 2):
        out, fg, bg = "", None, None
        for x in range(W):
            t, b = grid[r][x], grid[r + 1][x]
            if t and b and t == b:
                ch, want_fg, want_bg = "█", t, None
            elif t:
                ch, want_fg, want_bg = "▀", t, b
            elif b:
                ch, want_fg, want_bg = "▄", b, None
            else:
                ch, want_fg, want_bg = " ", fg, None
            if want_bg != bg:
                out += want_bg.lower() if want_bg else "z"
                bg = want_bg
            if want_fg != fg:
                out += want_fg
                fg = want_fg
            out += ch
        if bg:
            out += "z"
        lines.append(out)
    return lines


TRON = {"A": (0, 255, 255), "B": (0, 95, 135), "C": (0, 215, 255), "D": (0, 95, 135)}


def save_png(path):
    from PIL import Image, ImageDraw
    s = 6                                            # 1ピクセルの大きさ
    img = Image.new("RGB", (FRAMES * (W + 3) * s, H * s), (12, 12, 16))
    d = ImageDraw.Draw(img)
    for k in range(FRAMES):
        grid = pixels(k)
        ox = k * (W + 3) * s
        for y in range(H):
            for x in range(W):
                if grid[y][x]:
                    d.rectangle([ox + x * s, y * s, ox + x * s + s - 1, y * s + s - 1], fill=TRON[grid[y][x]])
    img.save(path)


if __name__ == "__main__":
    if "--png" in sys.argv:
        save_png(sys.argv[sys.argv.index("--png") + 1])
    else:
        print(f"# tools/gen_gears.py で生成（{FRAMES} コマ × {H // 2} 行、幅 {W}）")
        print("GEAR_FRAMES=(")
        for k in range(FRAMES):
            for line in bash_lines(pixels(k)):
                print(f"  '{line}'")
        print(")")
        print(f"GEAR_N={FRAMES} MARK_H={H // 2} MARK_W={W}")
