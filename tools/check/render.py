# ANSI のカーソル移動を再現して最終画面をテキストで出す（検証用）
import re, sys
data = sys.stdin.read()
scr, r, c = {}, 0, 0
tok = re.compile(r'\x1b\[(\??)([0-9;]*)([A-Za-z])|(\r)|(\n)|(\x08)|(.)', re.S)
for m in tok.finditer(data):
    q, n, cmd, cr, nl, bs, ch = m.groups()
    if cmd:
        k = int(n) if n and q == '' and n.isdigit() else 1
        if cmd == 'A': r = max(0, r - k)
        elif cmd == 'B': r += k
        elif cmd == 'G': c = k - 1
        elif cmd == 'K':  # 行の消去（2=行全体 / 0・省略=カーソルから右）
            row = scr.get(r, {})
            for j in [j for j in row if n == '2' or j >= c]: del row[j]
        elif cmd == 'J':  # カーソルから画面の下まで消す
            for i in [i for i in scr if i > r]: del scr[i]
            for j in [j for j in scr.get(r, {}) if j >= c]: del scr[r][j]
    elif cr: c = 0
    elif nl: r += 1; c = 0
    elif bs: c = max(0, c - 1)
    elif ch:
        scr.setdefault(r, {})[c] = ch; c += 1
last = max(scr) if scr else 0
for i in range(last + 1):
    row = scr.get(i, {})
    print(''.join(row.get(j, ' ') for j in range(max(row) + 1 if row else 0)).rstrip())
print(f'[cursor row={r} col={c}]')
