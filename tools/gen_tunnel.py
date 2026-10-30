#!/usr/bin/env python3
"""リンクスタート風の光のトンネルを、指定の大きさ（窓に合わせた 16:9）でコマごとに描き、ANSI の文字列として出力する。

使い方:
  python3 gen_tunnel.py --cols 96 --rows 21                 # 1コマ rows 行 × cols 列。全コマを続けて出力する
  python3 gen_tunnel.py --cols 96 --rows 21 --png OUT.png   # 全コマを画像にして確認する

前へ進んでいる感覚を出すため、虹色の輪と白い光の筋は中心の奥から現れ、だんだん速くなりながら外へ広がる。
最初から画面全体に輪が並んだ状態で始まり、最後は中心から白い光が広がって真っ白になり、暗くなって消える
（最後のコマは空）。
1文字 = 横1ドット × 縦2ドット（上は「▀」の文字色、下は背景色）。ドットは縦長なので、横を ASPECT 倍して円に見せる。
"""
import argparse

import numpy as np

ASPECT = 1.25          # 1ドットの縦÷横（gen_radar.py と同じ。ユーザーの端末に合わせた値）
TUNNEL = 24            # トンネルのコマ数
TRAVEL = 0.6           # 輪が進む量（1 = 中心から画面の外まで1回分）。大きいと1コマで輪の間隔近く進み、逆に戻って見える
DENSITY = 8            # 同時に見える輪の数
GROW = 1.6             # 奥行きを半径にするときの指数。大きいほど中心では遅く、外側で速く広がる（遠近感）
STREAKS = 16           # 光の筋の本数（左右対称になるよう等間隔）
RAINBOW = [196, 208, 226, 46, 51, 33, 129]   # 赤 橙 黄 緑 水 青 紫（256色の番号）
WHITE, TAIL = 231, 240
FADE = [254, 250, 244, 238]                  # 真っ白から消えるまで


def progress(k):
    """k コマ目までに進んだ量。2乗の項でだんだん速くする（最初から少しは動かす）"""
    t = k / (TUNNEL - 1)
    return TRAVEL * (0.25 * t + 0.75 * t * t)


def frames(cols, rows):
    h = rows * 2
    ys, xs = np.mgrid[0:h, 0:cols]
    cx, cy = (cols - 1) / 2, (h - 1) / 2
    dist = np.hypot((xs - cx) / ASPECT, ys - cy)   # 横の伸び縮みを戻した、中心からの距離
    rmax = dist.max() + 1
    radius = lambda ph: rmax * np.clip(ph, 0, None) ** GROW
    width = lambda r: 0.45 + 0.04 * r             # 輪の太さの半分。遠近感で外ほど太い
    out = []

    def rings_at(p):
        """進んだ量 p のときの虹色の輪。j 番目の輪は p = j / DENSITY のときに中心に現れ、色は赤→橙→…→紫→赤と続く"""
        g = np.full((h, cols), -1)
        j = np.round(DENSITY * (p - (dist / rmax) ** (1 / GROW)))
        ph = p - j / DENSITY
        r = radius(ph)
        on = (np.abs(dist - r) <= width(r)) & (r > 0.8)
        for c, tone in enumerate(RAINBOW):
            g[on & (j % len(RAINBOW) == c)] = tone
        return g

    for k in range(TUNNEL):
        p = progress(k)
        speed = progress(k + 1) - p
        g = rings_at(p)
        # 光の筋：中心から外へ。速くなるほど長く伸びる（先が白、尾は灰色）
        for i in range(STREAKS):
            a = (i + 0.5) * 2 * np.pi / STREAKS
            q = (p * 1.6 + (i % 2) * 0.5) % 1
            r1, r0 = radius(q), radius(q - 0.1 - speed * 2)
            for r in np.arange(r0, r1, 0.4):
                x, y = round(cx + r * ASPECT * np.cos(a)), round(cy + r * np.sin(a))
                if 0 <= x < cols and 0 <= y < h:
                    g[y, x] = WHITE if r > (r0 + r1) / 2 else TAIL
        out.append(g)

    # 中心から白い光が広がって真っ白になる
    for frac in (0.15, 0.4, 0.75, 1.1):
        g = rings_at(progress(TUNNEL - 1))
        g[dist <= rmax * frac] = WHITE
        out.append(g)
    for tone in FADE:
        out.append(np.full((h, cols), tone))
    out.append(np.full((h, cols), -1))
    return out


def ansi(g):
    lines = []
    for r in range(0, g.shape[0], 2):
        s, fg, bg = "", None, None
        for t, b in zip(g[r], g[r + 1]):
            t, b = int(t), int(b)
            if t >= 0 and t == b:
                ch, want_fg, want_bg = "█", t, -1
            elif t >= 0:
                ch, want_fg, want_bg = "▀", t, b
            elif b >= 0:
                ch, want_fg, want_bg = "▄", b, -1
            else:
                ch, want_fg, want_bg = " ", fg, -1
            if want_bg != bg:
                s += "\033[49m" if want_bg < 0 else f"\033[48;5;{want_bg}m"
                bg = want_bg
            if want_fg != fg:
                s += f"\033[38;5;{want_fg}m"
                fg = want_fg
            s += ch
        lines.append(s + "\033[0m")
    return lines


def xterm(n):
    if n < 16:
        return (255, 255, 255)
    if n < 232:
        v = [0, 95, 135, 175, 215, 255]
        n -= 16
        return (v[n // 36], v[n // 6 % 6], v[n % 6])
    g = 8 + (n - 232) * 10
    return (g, g, g)


def save_png(gs, path):
    from PIL import Image, ImageDraw
    h, w = gs[0].shape
    sx, sy, per = 3, round(3 * ASPECT), 4
    img = Image.new("RGB", (per * (w + 2) * sx, ((len(gs) + per - 1) // per) * (h + 2) * sy), (40, 40, 48))
    d = ImageDraw.Draw(img)
    for k, g in enumerate(gs):
        ox, oy = (k % per) * (w + 2) * sx, (k // per) * (h + 2) * sy
        d.rectangle([ox, oy, ox + w * sx - 1, oy + h * sy - 1], fill=(12, 12, 16))
        for y, x in zip(*np.nonzero(g >= 0)):
            d.rectangle([ox + x * sx, oy + y * sy, ox + x * sx + sx - 1, oy + y * sy + sy - 1], fill=xterm(int(g[y, x])))
    img.save(path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, required=True)
    ap.add_argument("--png")
    a = ap.parse_args()
    gs = frames(a.cols, a.rows)
    if a.png:
        save_png(gs, a.png)
    else:
        print("\n".join(line for g in gs for line in ansi(g)))
