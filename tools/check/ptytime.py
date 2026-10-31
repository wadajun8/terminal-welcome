# 疑似端末で welcome.sh を動かし、キーを押す/押さないで所要時間を測る（検証用）
import os, pty, time, select, struct, fcntl, termios
def run(key_at=None, cols=100, rows=40):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("bash", ["bash", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "welcome.sh")])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    t0 = time.time(); sent = False; out = b""
    while True:
        if key_at is not None and not sent and time.time() - t0 >= key_at:
            os.write(fd, b"x"); sent = True
        r, _, _ = select.select([fd], [], [], 0.01)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: break
            if not d: break
            out += d
    os.waitpid(pid, 0)
    return time.time() - t0, out.decode(errors="ignore")
for label, k, c, r in [("横並び キーなし", None, 100, 40), ("横並び 0.3秒でキー", 0.3, 100, 40),
                       ("縦並び キーなし", None, 60, 40), ("ゲージだけ キーなし", None, 40, 20),
                       ("ゲージだけ 0.3秒でキー", 0.3, 40, 20)]:
    t, out = run(k, c, r)
    print(f"{label:22s} {t:.2f}秒  GO: {'あり' if 'ALL SYSTEMS GO' in out or 'WARNING' in out or 'CAUTION' in out else 'なし'}")
