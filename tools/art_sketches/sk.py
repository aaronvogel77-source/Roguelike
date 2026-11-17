import pathlib
"""Tiny pixel sketch helper: shapes with 4-tone shading (light from top left)."""
class C:
    def __init__(s, w, h): s.w, s.h = w, h; s.g = [['.'] * w for _ in range(h)]
    def put(s, x, y, ch):
        if 0 <= x < s.w and 0 <= y < s.h: s.g[y][x] = ch
    def rect(s, x, y, w, h, ch):
        for yy in range(y, y + h):
            for xx in range(x, x + w): s.put(xx, yy, ch)
    def ell(s, cx, cy, rx, ry, ramp, cut=None):
        for y in range(-ry, ry + 1):
            for x in range(-rx, rx + 1):
                d = (x * x) / (rx * rx + .5) + (y * y) / (ry * ry + .5)
                if d > 1: continue
                if cut and not cut(x, y): continue
                v = -x / (rx + .5) - y / (ry + .5) + (1 - d) * .6
                t = 3 if v > 1.0 else 2 if v > .25 else 1 if v > -.55 else 0
                s.put(cx + x, cy + y, ramp[t])
    def box(s, x, y, w, h, ramp):
        s.rect(x, y, w, h, ramp[1]); s.rect(x, y, 1, h, ramp[2]); s.rect(x, y, w, 1, ramp[2])
        s.rect(x + w - 1, y, 1, h, ramp[0]); s.rect(x, y + h - 1, w, 1, ramp[0]); s.put(x, y, ramp[3])
    def line(s, x0, y0, x1, y1, ch):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1): s.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), ch)
    def tri(s, a, b, c, ch, only_empty=False):
        """Fills a triangle (points as (x, y))."""
        xs = range(min(a[0], b[0], c[0]), max(a[0], b[0], c[0]) + 1)
        ys = range(min(a[1], b[1], c[1]), max(a[1], b[1], c[1]) + 1)
        def side(p, q, r): return (p[0] - r[0]) * (q[1] - r[1]) - (q[0] - r[0]) * (p[1] - r[1])
        for y in ys:
            for x in xs:
                p = (x + .5, y + .5)
                d1, d2, d3 = side(p, a, b), side(p, b, c), side(p, c, a)
                if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
                    if not only_empty or s.g[y][x] == '.': s.put(x, y, ch)
    def rows(s): return [''.join(r) for r in s.g]
    def text(s, x, y, rows):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != ' ': s.put(x + i, y + j, ch)
def write(name, palette, c, feet, hand):
    out = ['kind = creature', '[palette]'] + [f'{k} = {v}' for k, v in palette.items()]
    out.append(f'[sprite feet={feet[0]},{feet[1]} hand={hand[0]},{hand[1]}]')
    out += c.rows()
    open(pathlib.Path(__file__).resolve().parents[2] / 'art' / f'{name}.txt', 'w').write('\n'.join(out) + '\n')
