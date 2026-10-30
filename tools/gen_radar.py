#!/usr/bin/env python3
"""レーダーのマークを、回転の各コマごとにドット絵として描く。

使い方:
  python3 gen_radar.py --bash          # welcome.sh に貼る bash 配列を出力する
  python3 gen_radar.py --png OUT.png   # 全コマを tron の色で画像にして確認する

1文字 = 横1ドット × 縦2ドット（端末の文字は縦長なので、ほぼ正方形のドットになる）。
上のドットは「▀」の文字色、下のドットは背景色で塗るので、1文字に2色まで使える。

ドット絵らしくするため、なめらかに塗る処理はせず、円はミッドポイント円、線はブレゼンハムの直線で
1ドット幅に描く。各ドットはクラスに分類し、bash 用の出力では文字色を A〜G、背景色を a〜g、
背景色の解除を z で表す（welcome.sh 側で色コードに置き換える）。
  A=外周の円 B=内側の円と十字線 C=ビーム D=残像（濃） E=残像（薄） F=ブリップ（反応した直後） G=ブリップ（暗く残る）
"""
import math
import sys

# 1ドットの「縦÷横」。端末のフォントによって、文字の高さが幅のちょうど2倍にならず、ドットが正方形に
# ならない。その分だけ横方向を伸び縮みさせて、画面上で丸く見えるようにする（demo/aspect.sh で測る）
ASPECT = 1.25          # ユーザーの端末（GNOME Terminal、Ubuntu Mono 13）で真円に見えた値
for _i, _a in enumerate(sys.argv):
    if _a == "--aspect":
        ASPECT = float(sys.argv[_i + 1])

R_OUT = 13             # 外周の半径（縦方向のドット数）
RX = round(R_OUT * ASPECT)                      # 外周の横の半径（ドット数）
W, H = 2 * RX + 1, 28  # 横のドット数（=文字数）, 縦のドット数（= 14 行。最下段は空き）
CX, CY = RX, 13        # 中心。ドットの中央に置いて上下左右対称にする
R_IN = (9, 4)          # 内側の同心円の半径
FRAMES = 16            # 1周のコマ数。ドット絵の直線は角度が細かいほどガタつくので 16 方向に絞る
TRAIL = (35, 75)       # ビームの後ろの残像の範囲（度）。ここまでが濃い残像、その先が薄い残像
# ブリップ（半径, 角度）。ビームが通過した直後だけ明るく、少しの間暗く残って消える
BLIPS = [(8, 35), (8, 145), (10, 235), (10, 305)]
BLIP_LIT, BLIP_DIM = 50, 140   # 通過してからこの角度までは明るい / 暗い


def ellipse(r, cx=None, cy=None):
    """縦の半径 r の円を、横に ASPECT 倍した楕円として描く（ミッドポイント楕円の輪郭のドット）"""
    cx, cy = (CX if cx is None else cx), (CY if cy is None else cy)
    rx, ry = round(r * ASPECT), r
    pts = set()

    def plot(x, y):
        for sx in (1, -1):
            for sy in (1, -1):
                pts.add((cx + sx * x, cy + sy * y))

    rx2, ry2 = rx * rx, ry * ry
    x, y = 0, ry
    px, py = 0, 2 * rx2 * y
    plot(x, y)
    p = ry2 - rx2 * ry + 0.25 * rx2              # 傾きが緩い部分
    while px < py:
        x += 1
        px += 2 * ry2
        if p < 0:
            p += ry2 + px
        else:
            y -= 1
            py -= 2 * rx2
            p += ry2 + px - py
        plot(x, y)
    p = ry2 * (x + 0.5) ** 2 + rx2 * (y - 1) ** 2 - rx2 * ry2   # 傾きが急な部分
    while y > 0:
        y -= 1
        py -= 2 * rx2
        if p > 0:
            p += rx2 - py
        else:
            x += 1
            px += 2 * ry2
            p += rx2 - py + px
        plot(x, y)
    return pts


def line(x0, y0, x1, y1):
    """ブレゼンハムの直線のドット"""
    pts = set()
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.add((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def behind(beam, ang):
    """ビームの角度 beam から見て、ang がどれだけ後ろ（反時計回り）にあるか（0〜360度）"""
    return (beam - ang) % 360


def frame(k):
    """k = 0〜FRAMES-1 は回転のコマ。k = FRAMES は止まったときの絵（円と十字線だけ。ビーム・残像・ブリップなしで左右対称）"""
    final = k == FRAMES
    beam = -90 + k * 360 / FRAMES                   # 真上から時計回り（画面の y は下向き）
    grid = [[None] * W for _ in range(H)]

    def put(pts, c):
        for x, y in pts:
            if 0 <= x < W and 0 <= y < H:
                grid[y][x] = c

    # 残像（扇形）。薄い方は市松模様のディザで表す
    for y in range(H if not final else 0):
        for x in range(W):
            dx, dy = (x - CX) / ASPECT, y - CY        # 横の伸び縮みを戻した、本来の位置
            if 0 < math.hypot(dx, dy) < R_OUT - 0.5:
                b = behind(beam, math.degrees(math.atan2(dy, dx)))
                if b <= TRAIL[0]:
                    grid[y][x] = "D"
                elif b <= TRAIL[1] and (x + y) % 2 == 0:
                    grid[y][x] = "E"
    # 内側の円と、点線の十字線
    for r in R_IN:
        put(ellipse(r), "B")
    put({(CX + i, CY) for i in range(-RX + 1, RX) if i % 2 == 0}, "B")
    put({(CX, CY + i) for i in range(-R_OUT + 1, R_OUT) if i % 2 == 0}, "B")
    put(ellipse(R_OUT), "A")
    if final:
        return grid
    # ビーム
    ex = CX + round((R_OUT - 1) * ASPECT * math.cos(math.radians(beam)))
    ey = CY + round((R_OUT - 1) * math.sin(math.radians(beam)))
    put(line(CX, CY, ex, ey), "C")
    # ブリップ（1ドット）
    for r, a in BLIPS:
        b = behind(beam, a)
        if b <= BLIP_LIT:
            c = "F"
        elif b <= BLIP_DIM:
            c = "G"
        else:
            continue
        bx = CX + round(r * ASPECT * math.cos(math.radians(a)))
        by = CY + round(r * math.sin(math.radians(a)))
        put({(bx, by)}, c)
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


TRON = {"A": (0, 215, 255), "B": (0, 95, 135), "C": (0, 255, 255),
        "D": (0, 135, 175), "E": (0, 95, 135), "F": (0, 255, 0), "G": (0, 135, 0)}


def save_png(path):
    """全コマを画像にする。ドットは縦を ASPECT 倍にして、ユーザーの端末での見え方に合わせる"""
    from PIL import Image, ImageDraw
    sx = 8                                           # 1ドットの幅
    sy = round(sx * ASPECT)                          # 1ドットの高さ
    cols = 4
    rows = (FRAMES + 1 + cols - 1) // cols
    img = Image.new("RGB", (cols * (W + 2) * sx, rows * (H + 2) * sy), (40, 40, 48))
    d = ImageDraw.Draw(img)
    for k in range(FRAMES + 1):
        grid = frame(k)
        ox, oy = (k % cols) * (W + 2) * sx, (k // cols) * (H + 2) * sy
        d.rectangle([ox, oy, ox + W * sx - 1, oy + H * sy - 1], fill=(12, 12, 16))
        for y in range(H):
            for x in range(W):
                if grid[y][x]:
                    d.rectangle([ox + x * sx, oy + y * sy, ox + x * sx + sx - 2, oy + y * sy + sy - 2],
                                fill=TRON[grid[y][x]])
    img.save(path)


def aspect_test():
    """縦横比を変えた円を並べて端末に出す。一番丸く見えるものの数字を ASPECT にする"""
    cands = [0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25]
    r, per_row, cell = 8, 3, 23
    for i in range(0, len(cands), per_row):
        row = cands[i:i + per_row]
        g = [[False] * (cell * len(row)) for _ in range(2 * r + 2)]
        for j, a in enumerate(row):
            pts = set()
            rx, ry = r * a, r                        # 比率の違いが出るよう、半径は丸めない
            for t in range(720):                     # 試し描きなので角度で細かく点を打つ
                th = math.radians(t / 2)
                pts.add((round(rx * math.cos(th)), round(ry * math.sin(th))))
            for k in range(-round(rx), round(rx) + 1):
                pts.add((k, 0))
            for k in range(-ry, ry + 1):
                pts.add((0, k))
            for x, y in pts:
                g[r + y][j * cell + cell // 2 + x] = True
        for y in range(0, len(g), 2):
            print("  " + "".join("█" if g[y][x] and g[y + 1][x] else "▀" if g[y][x] else "▄" if g[y + 1][x] else " "
                                 for x in range(len(g[0]))))
        print("  " + "".join(f"{a:^{cell}.2f}" for a in row))
        print()


if __name__ == "__main__":
    if "--aspect-test" in sys.argv:
        aspect_test()
    elif "--png" in sys.argv:
        save_png(sys.argv[sys.argv.index("--png") + 1])
    else:
        print(f"# tools/gen_radar.py --aspect {ASPECT} で生成（{FRAMES} コマ ＋ 止まったときの絵 × {H // 2} 行、幅 {W}）")
        print("MARK_FRAMES=(")
        for k in range(FRAMES + 1):
            for ln in bash_lines(frame(k)):
                print(f"  '{ln}'")  # 右の空白も残す（前のコマを上書きで消すため）
        print(")")
        print(f"MARK_N={FRAMES} MARK_END={FRAMES} MARK_H={H // 2} MARK_W={W}")
