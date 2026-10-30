# 端末への出力（ANSI）を、色つきの画像として再現する（検証用）
import os, re, sys
from PIL import Image, ImageDraw, ImageFont
def xterm(n):
    base = [(0,0,0),(205,0,0),(0,205,0),(205,205,0),(0,0,238),(205,0,205),(0,205,205),(229,229,229),
            (127,127,127),(255,0,0),(0,255,0),(255,255,0),(92,92,255),(255,0,255),(0,255,255),(255,255,255)]
    if n < 16: return base[n]
    if n < 232:
        n -= 16; v = [0, 95, 135, 175, 215, 255]
        return (v[n // 36], v[n // 6 % 6], v[n % 6])
    g = 8 + (n - 232) * 10; return (g, g, g)
data = open(sys.argv[1], encoding="utf-8", errors="ignore", newline="").read()
scr, r, c, fg, bg = {}, 0, 0, (229,229,229), None
tok = re.compile(r'\x1b\[(\??)([0-9;]*)([A-Za-z])|(\r)|(\n)|(\x08)|(.)', re.S)
for m in tok.finditer(data):
    q, n, cmd, cr, nl, bs, ch = m.groups()
    if cmd:
        if q: continue
        k = int(n) if n.isdigit() else 1
        if cmd == 'A': r = max(0, r - k)
        elif cmd == 'B': r += k
        elif cmd == 'G': c = k - 1
        elif cmd == 'K':  # 行の消去（2=行全体 / 0・省略=カーソルから右）
            for key in [key for key in scr if key[0] == r and (n == '2' or key[1] >= c)]: del scr[key]
        elif cmd == 'J':  # カーソルから画面の下まで消す
            for key in [key for key in scr if key[0] > r or (key[0] == r and key[1] >= c)]: del scr[key]
        elif cmd == 'm':
            ps = [int(x) for x in n.split(';') if x] or [0]
            i = 0
            while i < len(ps):
                p = ps[i]
                if p == 0: fg, bg = (229,229,229), None
                elif p == 49: bg = None
                elif p in (38, 48) and i + 2 < len(ps) + 1 and ps[i+1] == 5:
                    if p == 38: fg = xterm(ps[i+2])
                    else: bg = xterm(ps[i+2])
                    i += 2
                i += 1
    elif cr: c = 0
    elif nl: r += 1; c = 0
    elif bs: c = max(0, c - 1)
    elif ch:
        scr[(r, c)] = (ch, fg, bg); c += 1
rows = max(k[0] for k in scr) + 1; cols = max(k[1] for k in scr) + 1
cw = 10
chh = round(cw * 2 * float(os.environ.get("ASPECT", "1.25")))  # 文字の高さ。ユーザーの端末に合わせる
img = Image.new("RGB", (cols * cw, rows * chh), (12, 12, 16)); d = ImageDraw.Draw(img)
font = ImageFont.truetype(sys.argv[3], 16) if len(sys.argv) > 3 else ImageFont.load_default()
for (y, x), (ch, f, b) in scr.items():
    X, Y = x * cw, y * chh
    if b: d.rectangle([X, Y, X + cw - 1, Y + chh - 1], fill=b)
    if ch == '█': d.rectangle([X, Y, X + cw - 1, Y + chh - 1], fill=f)
    elif ch == '▀': d.rectangle([X, Y, X + cw - 1, Y + chh // 2 - 1], fill=f)
    elif ch == '▄': d.rectangle([X, Y + chh // 2, X + cw - 1, Y + chh - 1], fill=f)
    elif ch == '■': d.rectangle([X + 1, Y + 6, X + cw - 2, Y + 14], fill=f)
    elif ch == '□': d.rectangle([X + 1, Y + 6, X + cw - 2, Y + 14], outline=f)
    elif ch != ' ': d.text((X, Y + 1), ch, fill=f, font=font)
img.save(sys.argv[2])
