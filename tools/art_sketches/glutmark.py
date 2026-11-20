from sk import C, write
import math
# Glutmark (wands region): ash, soot and embers. Light from the top left, four-tone
# ramps (shadows cooler/violet, lights warmer/yellow); bodies stay dark and
# desaturated, only embers, flames and eyes glow. All face right.
# Detail pass: broken silhouettes, glowing seams in three light steps, drips,
# rivets, chains, straps, frayed cloth, smoke and sparks.

EMBER = {'o': '7a1e08', 'O': 'c8480e', 'f': 'f89028', 'F': 'ffe48a'}
ASH = {'a': '2e2a2e', 'A': '57514f', 'b': '8a827c', 'B': 'c2b9ae'}
SOOT = {'q': '161216', 'Q': '2c242a', 'r': '4a3e44', 'R': '6e6066'}
SKIN = {'d': '3a2014', 's': '7a4630', 'm': 'c2825a', 'l': 'eab288'}
WOOD = {'w': '2e1a0e', 'W': '5a3418', 'x': '86562a', 'X': 'b07a40'}
IRON = {'i': '1e1c22', 'I': '3e3a42', 'j': '6a646c', 'J': 'a49c9e'}
BRASS = {'g': '6a4a14', 'G': 'c89a3a'}
BONE = {'y': '9a9078', 'Y': 'e0d8c0'}


def pal(*parts, **extra):
    out = {}
    for p in parts:
        out.update(p)
    out.update(extra)
    return out


def robe(c, cx, y0, y1, half, ramp, folds=0, ragged=0):
    """A cloth body lit from the left: light edge, mid, dark right side, folds and a hem."""
    for y in range(y0, y1):
        h = half(y)
        for x in range(-h, h + 1):
            if ragged and y > y1 - 3 and (x + y) % ragged == 0:
                continue
            u = (x + h) / max(1, 2 * h)
            ch = ramp[2] if u < .2 else ramp[0] if u > .76 else ramp[1]
            if folds and y > y0 + 6 and (x + h) % folds == folds - 1 and u < .8:
                ch = ramp[0]
                if (x + h) % (folds * 2) == folds - 1 and u < .5:
                    c.put(cx + x - 1, y, ramp[2])   # light catches the fold's edge
            c.put(cx + x, y, ch)
        c.put(cx - h, y, ramp[3] if y < y0 + 4 else ramp[2])


def poly(pts):
    """Pixels inside a polygon (even-odd rule)."""
    ys = [p[1] for p in pts]
    out = []
    for y in range(min(ys), max(ys) + 1):
        xs = []
        for i in range(len(pts)):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
            if (y0 <= y + .5 < y1) or (y1 <= y + .5 < y0):
                xs.append(x0 + (y + .5 - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            for x in range(round(xs[k]), round(xs[k + 1])):
                out.append((x, y))
    return out


def shade(c, pts, ramp):
    """Fills pixels with a ramp, lit from the top left: light rim top/left, dark rim bottom/right."""
    S = set(pts)
    for (x, y) in S:
        left, top = (x - 1, y) not in S, (x, y - 1) not in S
        right, bottom = (x + 1, y) not in S, (x, y + 1) not in S
        if left and top: ch = ramp[3]
        elif (left or top) and not (right or bottom): ch = ramp[2]
        elif (right or bottom) and not (left or top): ch = ramp[0]
        else: ch = ramp[1]
        c.put(x, y, ch)


def plate(c, pts, ramp):
    shade(c, poly(pts), ramp)


def seam(c, path):
    """A glowing seam in three light steps: dark-red halo, orange line, yellow core."""
    for (x0, y0), (x1, y1) in zip(path, path[1:]):
        c.line(x0 + 1, y0, x1 + 1, y1, 'o')
    for (x0, y0), (x1, y1) in zip(path, path[1:]):
        c.line(x0, y0, x1, y1, 'O')
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(1, n, 2):
            c.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), 'f')
    mx, my = path[len(path) // 2]
    c.put(mx, my, 'F')


def drip(c, x, y, n):
    """Molten metal running down and gathering in a hot drop."""
    for i in range(n):
        c.put(x, y + i, 'O' if i < n - 1 else 'f')
    c.put(x, y + n, 'F')
    if n > 2:
        c.put(x - 1, y + n, 'O')


def rivet(c, x, y, light='J', dark='i'):
    c.put(x, y, light); c.put(x + 1, y + 1, dark)


def chain(c, x0, y0, x1, y1, a='j', b='I'):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        if i % 3 == 2: continue
        c.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), a if i % 3 == 0 else b)


def smoke(c, pts):
    for k, (x, y) in enumerate(pts):
        c.text(x, y, ['bA', 'AA'] if k % 2 == 0 else ['A'])


def flame(c, x, y, size, seed=0):
    """A small flame rising from (x, y): hot core low, orange, red tip."""
    for i in range(size):
        w = max(0, (size - i) // 2 - (1 if i < 2 else 0))
        sway = round(math.sin(i * 0.9 + seed) * 0.8)
        for dx in range(-w, w + 1):
            t = i / max(1, size - 1)
            core = abs(dx) <= w // 2 and t < .5
            ch = 'F' if core and t < .3 else 'f' if t < .55 or core else 'O' if t < .8 else 'o'
            c.put(x + dx + sway, y - i, ch)


def sparks(c, pts):
    for k, (x, y) in enumerate(pts):
        c.put(x, y, 'F' if k % 3 == 0 else 'f' if k % 3 == 1 else 'O')


def cracks(c, lines, glow='O', core='f'):
    for (x0, y0, x1, y1) in lines:
        c.line(x0, y0, x1, y1, glow)
        c.put((x0 + x1) // 2, (y0 + y1) // 2, core)


# --- Glutnovize: a small novice in a patched brown cassock, swinging a censer of embers on a chain
c = C(34, 44)
robe(c, 13, 17, 42, lambda y: 4 + (y - 17) // 4, 'aAbB', folds=4, ragged=3)
c.box(9, 33, 4, 4, 'aaAA'); c.text(9, 33, ['b b', ' b ', 'b b'])   # stitched patch
c.rect(9, 26, 9, 1, 'W'); c.rect(9, 26, 9, 1, 'X'); c.put(13, 27, 'W'); c.text(12, 28, ['X X', 'W W', 'X X'])  # rope belt, tassels
c.ell(13, 13, 6, 6, 'aAbB')                  # hood
c.ell(14, 12, 4, 4, 'aaaa')                  # inner shadow of the hood
c.ell(15, 14, 4, 4, 'dsml')                  # young face
c.text(15, 13, ['k k']); c.text(14, 15, ['d']); c.put(16, 16, 's')   # eyes, ash smudge, mouth
c.text(13, 6, [' a', 'aA'])                  # hood tip
for k, x in enumerate(range(11, 18)):        # wooden prayer beads at the neck
    c.put(x, 19 + (1 if 12 < x < 17 else 0), 'X' if k % 2 else 'W')
c.line(17, 22, 22, 25, 'A'); c.line(17, 23, 22, 26, 'a')          # arm forward
c.text(22, 25, ['ml', 'sm'])                 # hand
chain(c, 24, 26, 27, 32, 'J', 'j')           # censer chain
c.ell(27, 35, 3, 3, 'iIjJ')                  # censer bowl
c.text(25, 32, ['jJJj']); c.put(26, 31, 'J')                      # lid and finial
c.text(25, 35, ['f O']); c.put(29, 34, 'o')  # embers glowing through the holes
for i, (x, y) in enumerate(((28, 29), (29, 26), (28, 23), (30, 20), (29, 17), (31, 14))):   # curling smoke
    c.put(x, y, 'A' if i % 2 else 'b'); c.put(x + 1, y - 1, 'A')
sparks(c, ((31, 33), (24, 30), (30, 38)))
c.text(10, 42, ['WW  WW'])                   # sandals
write('ember_acolyte', pal(ASH, SKIN, EMBER, IRON, WOOD, a='2e2018', A='54402e', b='7e6448', B='a88a64', k='120a0c'),
      c, (13, 43), (14, -8))

# --- Aschehülle: a charred hollow body, ribs around a glowing hollow chest, rags of an old robe
c = C(36, 48)
B = 'qQrR'
shade(c, poly([(10, 18), (22, 17), (25, 24), (24, 36), (19, 39), (11, 38), (8, 30)]), B)   # gaunt torso
c.ell(17, 25, 4, 6, 'kkoo')                  # hollow chest
c.ell(17, 26, 2, 4, 'oOfF')                  # embers inside
for y in (21, 24, 27, 30):                   # charred ribs across the hollow
    c.line(13, y, 21, y + 1, 'Q'); c.put(14, y, 'R')
drip(c, 17, 31, 3)                           # embers trickling out
shade(c, poly([(15, 9), (22, 8), (25, 12), (24, 17), (19, 19), (15, 16)]), B)   # head sunk forward
c.text(20, 12, ['F f']); c.text(19, 12, ['o']); c.text(21, 15, ['kkk', ' k'])   # ember eyes, gaping mouth
seam(c, [(12, 20), (13, 25), (12, 29)]); seam(c, [(22, 30), (20, 34)]); seam(c, [(18, 9), (19, 11)])
c.line(10, 20, 6, 32, 'Q'); c.line(11, 21, 7, 33, 'r')            # arms hanging
c.line(23, 20, 26, 31, 'Q'); c.line(24, 20, 27, 31, 'r')
c.text(4, 32, ['rQ', 'Q Q']); c.text(26, 31, ['QrQ', ' Q'])        # claws
for (x, y) in ((9, 19), (11, 18), (22, 18), (24, 19)): c.put(x, y, 'B')   # flaking ash on the shoulders
for y in range(36, 41):                       # rags of an old dark-red robe round the waist
    for x in range(10, 25):
        if y > 38 and (x * 3 + y) % 4 == 0: continue
        c.put(x, y, 'v' if (x + y) % 5 else 'V')
c.rect(12, 40, 3, 6, 'Q'); c.rect(12, 40, 1, 6, 'R')             # legs
c.rect(18, 40, 3, 6, 'Q'); c.rect(18, 40, 1, 6, 'R')
seam(c, [(19, 41), (20, 44)])
c.text(11, 46, ['qqqq  qqqq'])
for (x, y) in ((8, 6), (11, 3), (26, 4), (29, 8), (4, 12)): c.put(x, y, 'b')   # ash flakes drifting
sparks(c, ((14, 4), (28, 16), (31, 22)))
write('ash_husk', pal(SOOT, EMBER, ASH, v='3a1014', V='5a1a1a', k='08060a'), c, (16, 47), (11, -16))

# --- Aschehund: a lean black hound with glowing cracks, a spiked collar and a broken chain
c = C(48, 36)
B = 'qQrR'
shade(c, poly([(8, 15), (14, 12), (26, 12), (31, 14), (32, 20), (27, 24), (12, 24), (7, 20)]), B)   # body
shade(c, poly([(28, 9), (35, 8), (38, 11), (44, 13), (44, 17), (37, 18), (31, 17)]), B)   # head and muzzle
c.text(32, 5, ['Qr', 'QQr', ' QQ'])           # ears
c.text(36, 11, ['F', 'o']); c.put(35, 11, 'f')                     # glowing eye
c.text(38, 17, ['FkFkF']); c.text(39, 19, ['f', ' O', 'F'])        # fangs, drool of embers
c.rect(29, 14, 2, 5, 'I'); c.put(29, 14, 'J')                      # spiked iron collar
c.text(28, 13, ['J']); c.text(31, 13, ['J']); c.text(30, 19, ['J'])
chain(c, 29, 19, 24, 27)                      # broken chain dangling
for (x, y, s) in ((26, 12, 4), (22, 12, 5), (18, 12, 5), (14, 12, 4), (30, 9, 3)):   # smouldering mane
    flame(c, x, y, s, x)
for (x, top, k) in ((11, 22, 0), (15, 23, 1), (25, 22, 0), (29, 21, 1)):   # legs with glowing paws
    c.rect(x, top, 2, 31 - top, 'Q'); c.put(x, top, 'R'); c.text(x, 31, ['qO' if k else 'Oq'])
seam(c, [(11, 16), (14, 19), (17, 18)]); seam(c, [(20, 15), (23, 21)]); seam(c, [(26, 16), (28, 20)])
for x in range(13, 27, 3): c.put(x, 13, 'R')  # ridge of the spine
c.line(8, 17, 2, 10, 'Q'); c.line(8, 18, 3, 11, 'r'); flame(c, 2, 9, 4)   # tail ending in fire
sparks(c, ((6, 4), (41, 22), (20, 6)))
write('cinder_hound', pal(SOOT, EMBER, IRON, k='08060a'), c, (21, 32), (19, -15))

# --- Scheiterhaufenprediger: a gaunt preacher, buttoned cassock, embroidered stole, a burning book held high
c = C(38, 58)
robe(c, 14, 18, 56, lambda y: 5 + (y - 18) // 6, 'qQrR', folds=4, ragged=3)
for y in range(20, 56, 3): c.put(16, y, 'J')  # buttons down the front
for y in range(20, 54):                       # crimson stole embroidered with small flames
    c.put(13, y, 'v'); c.put(14, y, 'V' if y % 6 else 'f')
for x in range(9, 21):                        # burnt, glowing hem
    if x % 3: c.put(x, 55, 'o')
c.rect(9, 30, 11, 1, 'w'); c.text(19, 31, ['B', 'B', 'b'])         # belt with a hanging scroll
c.ell(15, 13, 5, 6, 'dsml')                   # gaunt bald head
c.text(13, 15, ['d']); c.text(16, 10, ['dd'])                      # hollow cheek, brow
c.text(16, 12, ['k k']); c.text(16, 13, ['f f'])                   # burning eyes
c.text(17, 16, ['dd'])                        # grim mouth
c.text(9, 18, ['QQQQQQQQQQ']); c.text(11, 19, ['bb  bb'])           # collar with ash on the shoulders
c.line(19, 22, 25, 15, 'Q'); c.line(19, 23, 25, 16, 'r')          # arm raised
c.text(24, 12, ['ml', 'sm'])                  # hand
c.box(21, 6, 11, 6, 'wWxX'); c.rect(22, 7, 9, 3, 'B'); c.line(26, 6, 26, 11, 'W')   # open book
c.text(22, 8, ['o O ', '  o o']); c.text(27, 8, ['O o'])           # glowing letters
c.text(21, 12, ['W W']); c.text(30, 12, ['W'])                     # page edges, a ribbon
for k, x in enumerate((22, 25, 28, 31)):
    flame(c, x, 5, 5 + k % 2, k)
c.line(7, 22, 5, 36, 'Q'); c.text(4, 36, ['ml'])                  # back arm
c.rect(4, 30, 1, 26, 'W'); c.rect(3, 30, 1, 26, 'x')              # staff
c.text(1, 24, [' jJ ', 'jfOj', 'jOoj', ' ii '])                     # iron fire cage on the staff
flame(c, 3, 23, 3, 1)
sparks(c, ((34, 2), (20, 1), (36, 9)))
c.text(10, 56, ['qqq   qqq'])
write('pyre_preacher', pal(SOOT, SKIN, EMBER, WOOD, IRON, B='d8ccb0', b='8a827c', v='5a1418', V='8a2a20',
      k='120a0c'), c, (14, 57), (12, -49))

# --- Blasebalg-Kobold: a squat soot-red imp in a leather apron, pumping riveted bellows that spit sparks
c = C(42, 36)
I = 'tTuU'  # imp skin ramp: dark red-brown to warm
c.ell(13, 22, 7, 7, I)                        # pot belly
for (x, y) in ((10, 20), (14, 25), (9, 26)): c.put(x, y, 'd')      # soot spots
c.ell(14, 11, 6, 6, I)                        # big head
c.text(10, 3, ['J', 'jJ', 'gj']); c.text(17, 3, [' J', 'Jj', 'jg'])   # horns with brass rings
c.text(7, 9, ['UT', ' T']); c.text(20, 9, ['TU'])                  # pointed ears
c.text(15, 10, ['FkF']); c.text(15, 9, ['t t'])                    # eyes, brows
c.text(15, 14, ['kFkFk']); c.text(16, 15, ['kkk'])                 # grin with fangs
c.text(19, 11, ['UT'])                        # nose
for y in range(18, 29):                       # leather apron with straps
    for x in range(10, 18):
        c.put(x, y, 'N' if x < 12 else 'n')
c.line(10, 18, 15, 13, 'n'); c.put(14, 20, 'G'); c.put(14, 26, 'G')   # strap, rivets
c.ell(26, 20, 7, 5, 'wWxX')                   # bellows (wood boards)
for x in range(21, 31, 2): c.line(x, 18, x, 22, 'n')                # leather pleats
c.text(21, 17, ['G']); c.text(29, 17, ['G']); c.text(21, 23, ['G']); c.text(29, 23, ['G'])   # brass rivets
c.text(33, 19, ['gGg', 'ggg'])                # brass nozzle
sparks(c, ((36, 18), (37, 20), (39, 17), (38, 22), (41, 19), (40, 15), (36, 23)))
c.line(20, 19, 21, 15, 'T'); c.text(20, 14, ['UU'])               # hands on the handles
c.line(7, 20, 4, 24, 'T'); c.text(2, 24, ['tTU'])                  # back arm with claws
c.rect(9, 28, 3, 6, 'T'); c.rect(15, 28, 3, 6, 'T')               # stubby legs
c.text(8, 34, ['tUtt  tUtt'])                 # clawed feet
c.line(6, 26, 1, 30, 't'); flame(c, 0, 30, 3)                      # tail with a flame tip
write('bellows_imp', pal(EMBER, WOOD, IRON, BRASS, t='3a1410', T='6e2418', u='9a3a22', U='c86a3a', n='3a2418',
      N='5e3c24', d='2a0c0a', k='100608'), c, (13, 35), (22, -16))

# --- Aschepriesterin: a veiled priestess, lace-edged veil, ember circlet, keys at the belt, a banded urn of ash
c = C(38, 58)
robe(c, 15, 18, 56, lambda y: 4 + (y - 18) // 4, 'aAbB', folds=5, ragged=3)
for y in range(22, 55):                       # ember-red under-robe at the front
    c.put(18, y, 'v'); c.put(17, y, 'V' if y % 7 else 'v')
for x in range(8, 24, 2): c.put(x, 54, 'B')   # lace on the hem
c.rect(10, 31, 11, 1, 'I'); c.text(12, 32, ['j', 'J', ' j', ' J'])  # belt with keys
c.ell(15, 12, 6, 7, 'aAbB')                   # veil
for (x, y) in ((9, 12), (9, 15), (10, 18), (21, 8), (11, 6)): c.put(x, y, 'B')   # lace edge
c.ell(17, 13, 3, 4, 'dsml')                   # face under the veil (always visible)
c.put(17, 12, 'k'); c.put(19, 12, 'k'); c.text(17, 16, ['s']); c.put(16, 14, 'b')   # eyes, mouth, ash mark
c.text(12, 7, ['jOj', ' F']); c.line(11, 8, 20, 8, 'j')            # circlet with an ember gem
c.text(8, 9, ['A', 'A', 'a', 'a', 'a', 'a'])  # veil falling down the back
c.line(19, 23, 23, 27, 'A'); c.line(19, 24, 23, 28, 'a')          # arms holding the urn
c.text(17, 22, ['BB']); c.text(23, 29, ['BB'])                     # sleeve tassels
c.ell(26, 30, 4, 4, 'iIjJ'); c.rect(23, 25, 7, 2, 'I'); c.rect(24, 24, 5, 1, 'j')   # urn with a lid rim
c.rect(22, 30, 9, 1, 'g'); c.put(24, 30, 'G'); c.put(28, 30, 'G')   # brass band
c.rect(25, 24, 3, 1, 'o')                     # embers at its mouth
for i in range(9):                            # ash spiralling up
    c.put(27 + round(math.sin(i * 1.0) * 3), 22 - i * 2, 'b' if i % 2 else 'B')
sparks(c, ((30, 13), (22, 4), (33, 20)))
c.text(11, 56, ['qq   qq'])
write('ash_priestess', pal(ASH, SKIN, EMBER, IRON, BRASS, v='3a0e10', V='6a1a18', q='120c10', k='120a0c'),
      c, (15, 57), (11, -32))

# --- Schlackeriese: a hulking giant of uneven slag plates, lava in the seams, molten drips, a chained wrist
c = C(52, 62)
S = 'qQrR'
plate(c, [(12, 18), (22, 15), (35, 16), (39, 22), (37, 34), (29, 38), (16, 37), (11, 28)], S)   # chest
plate(c, [(15, 36), (34, 37), (35, 44), (25, 46), (14, 44)], S)                                # hips
plate(c, [(3, 16), (12, 13), (15, 20), (13, 29), (5, 28)], S)                                  # back shoulder
plate(c, [(37, 14), (47, 15), (49, 24), (45, 29), (38, 26)], S)                                # front shoulder
plate(c, [(2, 29), (12, 30), (14, 40), (10, 45), (3, 43), (1, 36)], S)                         # back fist
plate(c, [(38, 29), (48, 28), (50, 37), (47, 45), (39, 43)], S)                                # front fist
plate(c, [(15, 45), (24, 46), (25, 58), (14, 58)], S); plate(c, [(27, 46), (36, 45), (38, 58), (27, 58)], S)   # legs
plate(c, [(19, 4), (29, 2), (33, 7), (32, 15), (21, 16), (18, 10)], S)                         # head
c.text(22, 8, ['FO  Of']); c.text(22, 7, ['o    o'])               # molten eyes under a heavy brow
c.text(22, 12, ['oOfOo']); drip(c, 24, 13, 3)                      # glowing mouth seam, dripping
seam(c, [(16, 20), (19, 25), (23, 28)]); seam(c, [(30, 18), (33, 24), (31, 30)])
seam(c, [(24, 31), (26, 36), (24, 40)]); seam(c, [(5, 32), (9, 37), (7, 41)])
seam(c, [(41, 32), (45, 36), (43, 41)]); seam(c, [(18, 48), (20, 54)]); seam(c, [(30, 48), (32, 55)])
seam(c, [(7, 18), (10, 24)]); seam(c, [(41, 17), (44, 23)])
c.ell(26, 26, 3, 3, 'oOfF'); c.text(22, 22, ['F      F'])         # molten core with two glints
drip(c, 6, 45, 4); drip(c, 44, 45, 5); drip(c, 30, 38, 2)          # drips from fists and belly
for (x, y) in ((14, 22), (34, 20), (17, 40), (31, 41)): rivet(c, x, y, 'R', 'q')   # embedded bolts
chain(c, 38, 34, 50, 36, 'J', 'j'); chain(c, 39, 38, 49, 47, 'J', 'j')                  # chains round the wrist
for (x, y) in ((20, 1), (28, 0), (6, 12), (44, 11)): c.text(x, y, [' R', 'rQ'])         # rock spikes
smoke(c, ((4, 7), (46, 6), (8, 3)))
c.text(14, 58, ['qqqqqqqqqqq  qqqqqqqqqqq'])
write('slag_giant', pal(SOOT, EMBER, IRON, A='57514f', b='8a827c', k='080608'), c, (25, 59), (19, -24))

# --- Rußkardinal: soot-black robes in many folds, a tall mitre with an ember cross and lappets,
# a skull rosary, an embroidered ember hem, ash dust, a burning lantern staff
c = C(46, 66)
robe(c, 19, 25, 63, lambda y: 6 + (y - 25) // 4, 'qQrR', folds=3)
for y in range(27, 63):                       # ember trim down the front
    c.put(22, y, 'O' if y % 4 else 'f'); c.put(21, y, 'o')
for x in range(10, 30):                       # embroidered zigzag on the hem
    c.put(x, 60 + (x % 2), 'O' if x % 4 else 'f')
for (x, y) in ((12, 40), (26, 46), (15, 52), (24, 34), (11, 57), (27, 56)): c.put(x, y, 'b')   # ash dust
c.ell(19, 28, 10, 4, 'vvVV')                  # dark red mozzetta
for x in (17, 19, 21): c.put(x, 30, 'f')      # ember buttons
c.ell(20, 21, 5, 6, 'dsml')                   # stern old face
c.text(21, 20, ['k k']); c.text(21, 21, ['o o']); c.text(19, 18, ['ddd'])   # ember-lit eyes, brow
c.text(22, 24, ['s']); c.text(19, 25, ['bBBb'])                    # mouth, grey beard
c.text(14, 0, ['     qq     ', '    qQRq    ', '   qQRfRq   ', '   qQRfRq   ', '  qQfffffq  ',
               '  qQRRfRRq  ', ' qQRRRfRRRq ', ' qQRRRfRRRq ', ' qQRRRRRRRq ', 'qQRRRRRRRRRq',
               'oOOOOOOOOOOo', 'qGgGgGgGgGgq'])     # tall soot mitre: ember cross, brass band
c.text(13, 12, ['O', 'o', 'O', 'o']); c.text(26, 12, ['o', 'O', 'o'])   # lappets hanging behind
for k, (x, y) in enumerate(((15, 31), (16, 34), (18, 36), (20, 37), (22, 36))):   # skull rosary
    c.put(x, y, 'Y' if k % 2 else 'y')
c.text(22, 37, ['Y', 'y'])                    # cross of the rosary
c.line(27, 32, 33, 28, 'Q'); c.line(27, 33, 33, 29, 'r'); c.text(33, 27, ['ml', 'sm'])   # arm with staff
c.rect(36, 10, 2, 53, 'i'); c.rect(36, 10, 1, 53, 'I')            # iron staff
for y in (20, 34, 48): c.text(35, y, ['jJj'])  # staff rings
c.text(32, 1, ['   JJ   ', '  J  J  ', ' JjJJjJ ', ' J oF J ', ' J fF J ', ' J FfOJ ', ' JjjjjJ ',
               '   ii   ', '   ii   '])   # burning lantern
flame(c, 36, 0, 2)
smoke(c, ((41, 0), (43, 4)))
c.text(14, 63, ['qqqq    qqqq'])
write('soot_cardinal', pal(SOOT, SKIN, EMBER, IRON, BRASS, BONE, A='57514f', b='8a827c', B='c2b9ae',
      v='3a0c10', V='6a1a1a', k='100808'), c, (19, 64), (16, -60))

# --- Aschenherold: a herald in blackened plate, crest and visor, pauldrons, a herald's horn,
# raising a fringed ash banner with an ember sigil and burnt holes
c = C(46, 62)
c.rect(31, 2, 2, 58, 'w'); c.rect(31, 2, 1, 58, 'W')              # banner pole
c.text(30, 0, [' JJ', 'JjJ', ' j'])           # finial
c.rect(15, 3, 16, 1, 'I'); c.put(15, 3, 'J')  # cross bar
for y in range(4, 28):                        # tattered banner hanging left of the pole
    for x in range(16):
        if y > 22 and (x * 5 + y * 3) % 7 < (y - 22): continue   # torn, burnt hem
        ch = 'b' if x > 13 else 'a' if x < 2 else 'A'
        if y > 22 and (x * 5 + y * 3) % 7 == (y - 22): ch = 'o'   # glowing burnt edge
        c.put(30 - x, y, ch)
for x in range(16, 31, 2): c.put(x, 4, 'B')   # fringe along the top
c.text(18, 15, ['ko', 'o']); c.text(25, 20, ['ok'])                # burnt holes
c.text(20, 8, ['  o  ', ' oOo ', 'oOfOo', ' OFO ', '  o  ', '  o  '])   # ember sigil (a wand flame)
robe(c, 16, 36, 58, lambda y: 5 + (y - 36) // 5, 'qQrR', ragged=3)   # tabard skirt
for y in range(36, 57): c.put(16, y, 'v')     # stripe down the tabard
c.box(10, 24, 14, 12, 'iIjJ')                 # breastplate
for (x, y) in ((11, 25), (22, 25), (11, 34), (22, 34)): rivet(c, x, y)
c.text(15, 28, ['oOo', ' O ']); c.put(16, 29, 'F')                 # ember emblem
c.ell(9, 24, 4, 3, 'iIjJ'); c.ell(23, 24, 4, 3, 'iIjJ')           # pauldrons
c.ell(18, 16, 5, 6, 'iIjJ')                   # open helm
c.rect(14, 12, 9, 2, 'I'); c.rect(14, 12, 9, 1, 'J')              # raised visor
c.ell(20, 18, 3, 3, 'dsml')                   # face inside it
c.text(20, 17, ['k k']); c.text(21, 20, ['d'])
c.text(13, 7, ['  bB', ' bA ', 'bA  ', 'A   ']); c.text(16, 9, ['vVv'])   # ash plume and red crest
c.line(23, 27, 30, 23, 'I'); c.text(29, 22, ['jJ', 'Ij'])         # arm on the pole
c.line(10, 27, 7, 36, 'I'); c.text(6, 36, ['jI'])                  # back arm
c.rect(10, 36, 14, 2, 'n'); c.put(17, 36, 'G')                    # belt
c.text(4, 37, [' YY', 'YyyY', 'y  ', ' g'])   # herald's horn on the belt
c.box(12, 48, 4, 11, 'iIjJ'); c.box(18, 48, 4, 11, 'iIjJ')       # greaves
c.put(13, 49, 'J'); c.put(19, 49, 'J')        # knee cops
c.text(11, 59, ['qqqq  qqqq'])
write('ash_herald', pal(SOOT, IRON, SKIN, EMBER, WOOD, BONE, a='2e2a2e', A='57514f', b='8a827c', B='c2b9ae',
      v='5a1418', V='8a2a20', n='2a1a10', g='6a4a14', G='c89a3a', k='100808'), c, (17, 60), (14, -38))

# --- Feuerschlucker: a burly fire-eater - topknot, moustache, earring, flame tattoos, leather bracers,
# an oil flask on the belt - blowing a jet of fire over his torch
c = C(54, 58)
for y in range(20, 42):                       # torso: broad shoulders tapering to the belly
    half = 10 - (y - 20) // 4 if y < 32 else 8 + (y - 32) // 5
    for x in range(-half, half + 1):
        u = (x + half) / (2 * half)
        ch = 'l' if u < .18 and y < 30 else 'm' if u < .5 else 's' if u < .85 else 'd'
        c.put(17 + x, y, ch)
c.text(12, 24, ['s  s', ' ss']); c.text(16, 33, ['d', 'd'])       # chest and belly lines
c.text(9, 26, ['d', ' d', 'd']); c.text(22, 29, ['d', ' d'])       # soot streaks
c.text(13, 30, ['o', 'oo', ' o'])             # flame tattoo on the chest
c.line(10, 21, 24, 38, 'v'); c.line(11, 21, 25, 38, 'V')          # sash across the chest
c.rect(8, 41, 20, 3, 'n'); c.rect(8, 41, 20, 1, 'N'); c.rect(15, 41, 4, 3, 'G'); c.put(16, 42, 'g')   # belt
c.text(23, 43, ['jJ', 'II', 'II', 'Ij'])      # oil flask
c.box(9, 44, 8, 12, 'vvVV'); c.box(19, 44, 8, 12, 'vvVV')       # baggy trousers
c.text(10, 47, ['v  v']); c.text(20, 49, [' v  v'])                 # cloth folds
c.rect(9, 52, 8, 1, 'N'); c.rect(19, 52, 8, 1, 'N')              # leg wraps
c.text(8, 56, ['qqqqqqqqq qqqqqqqq'])
c.ell(5, 27, 3, 6, 'dsml'); c.ell(4, 35, 3, 4, 'dsml')            # back arm, upper and fore
c.text(3, 25, ['o', 'Oo', 'o']); c.rect(2, 33, 5, 2, 'n')         # tattoo, leather bracer
c.text(2, 38, ['ms', 'sd'])
c.ell(20, 13, 5, 6, 'dsml')                   # head in profile
c.text(17, 4, [' dd', 'dssd', ' d']); c.put(18, 7, 'G')           # topknot with a brass ring
c.text(22, 11, ['k']); c.text(19, 10, ['ddd'])                     # eye, brow
c.text(23, 15, ['ddd', 'd  '])                # moustache
c.text(25, 13, ['m', 'ko'])                   # nose and open mouth
c.text(18, 14, ['G']); c.text(17, 12, ['s'])  # earring, ear
c.text(16, 19, ['ssssss'])                    # thick neck
c.ell(27, 24, 3, 4, 'dsml'); c.text(26, 23, ['o', 'O'])           # front upper arm with tattoo
c.line(28, 27, 31, 22, 's'); c.line(29, 28, 32, 23, 'm')          # forearm raised
c.rect(29, 24, 3, 2, 'n')                     # bracer
c.text(31, 20, ['lm', 'ms'])                  # fist
c.rect(32, 14, 2, 7, 'w'); c.rect(32, 14, 1, 7, 'x'); c.text(31, 13, ['bBb'])   # torch with wrapped cloth
flame(c, 33, 12, 4, 2)
for i in range(20):                           # jet of fire from the mouth, widening, smoke at its edge
    x = 27 + i
    w = 1 + i // 5
    for dy in range(-w, w + 1):
        t = i / 19
        ch = 'F' if abs(dy) < w and t < .45 else 'f' if t < .7 else 'O'
        if t > .82 and abs(dy) == w: ch = 'o'
        c.put(x, 13 + dy + round(math.sin(i * 0.8) * 0.6), ch)
smoke(c, ((46, 7), (49, 18), (51, 10)))
write('fire_eater', pal(SKIN, EMBER, WOOD, IRON, n='2a1a10', N='4a3020', G='dca42c', g='8a6418', v='2a1a24',
      V='4a3040', A='57514f', b='8a827c', B='c2b9ae', q='120c10', k='120a0c'), c, (18, 57), (26, -44))

# --- Der Scheiterhaufen-Abt: a towering abbot on his own pyre - a halo of holy fire behind his hood,
# a robe with embroidered trim, a skull rosary, a crozier, layered logs with charred ends and hot cores
c = C(76, 90)
logs = [(4, 84, 70, 79), (2, 79, 72, 85), (8, 75, 66, 80), (6, 80, 68, 75), (12, 71, 62, 76), (16, 76, 58, 71)]
for (x0, y0, x1, y1) in logs:                  # crossed logs of the pyre, lit on top
    for d in range(3):
        c.line(x0, y0 + d, x1, y1 + d, 'X' if d == 0 else 'w' if d == 2 else 'W')
    for (ex, ey) in ((x0, y0), (x1, y1)):      # charred log ends with hot cores
        c.text(ex - 1, ey - 1, ['qwq', 'wOw', 'qwq'])
        c.put(ex, ey, 'f')
for (x0, x1, y) in ((14, 30, 82), (40, 60, 78), (20, 50, 74)):   # glowing cores between the logs
    for x in range(x0, x1, 3): c.put(x, y, 'O'); c.put(x + 1, y, 'f')
for x in range(5, 71, 5):
    flame(c, x, 74, 7 + (x * 7) % 6, x)       # flames licking up between the logs
chain(c, 22, 66, 26, 76, 'J', 'j'); chain(c, 46, 66, 42, 76, 'J', 'j')   # chains binding him to the pyre
for (hx, hy) in [(36 + round(math.cos(a) * 13), 17 + round(math.sin(a) * 12)) for a in [i * math.tau / 28 for i in range(28)]]:
    if hy < 26: c.put(hx, hy, 'f' if (hx + hy) % 3 else 'F')          # halo of holy fire
for a in [i * math.tau / 10 for i in range(10)]:
    if math.sin(a) < 0.3: flame(c, 36 + round(math.cos(a) * 14), 17 + round(math.sin(a) * 13), 3, a)
robe(c, 35, 30, 72, lambda y: 8 + (y - 30) // 3, 'qQrR', folds=4)
for y in range(34, 72):                       # scapular with embroidered ember trim
    c.put(34, y, 'v'); c.put(35, y, 'v'); c.put(36, y, 'v')
    c.put(33, y, 'O' if y % 3 else 'f'); c.put(37, y, 'o' if y % 3 else 'O')
for x in range(24, 48):                       # embroidered hem band
    c.put(x, 69, 'g' if x % 2 else 'G'); c.put(x, 70, 'O' if x % 4 == 0 else 'v')
c.rect(26, 40, 19, 2, 'n'); c.rect(26, 40, 19, 1, 'N')           # rope belt
c.line(31, 42, 29, 54, 'n'); c.text(28, 55, ['N', 'nN'])          # hanging rope end with a knot
for k, (x, y) in enumerate(((28, 33), (30, 36), (33, 38), (36, 39), (39, 38), (42, 36))):   # skull rosary
    c.text(x, y, ['Y'] if k % 2 else ['y'])
c.text(41, 37, ['YY', 'kY']); c.text(36, 40, ['y', 'Y'])           # a small skull and the cross
c.ell(35, 28, 10, 6, 'qQrR')                  # shoulders
c.ell(35, 18, 9, 10, 'qQrR')                  # hood up
for (x, y) in ((27, 14), (28, 22), (30, 9)): c.put(x, y, 'R')     # hood folds lit from the left
c.ell(37, 19, 5, 7, 'kkkk')                   # hood opening
c.ell(38, 19, 4, 6, 'dsml')                   # old gaunt face inside, visible
c.text(38, 17, ['k k']); c.text(38, 18, ['f f']); c.text(37, 16, ['ddd'])   # burning eyes, brow
c.text(37, 23, ['BbBb', ' bB', '  b'])        # ash-white beard
c.line(45, 32, 53, 36, 'Q'); c.line(45, 33, 53, 37, 'r')          # arm to the crozier
c.text(53, 35, ['lm', 'sm'])                  # hand
c.rect(55, 12, 2, 60, 'i'); c.rect(55, 12, 1, 60, 'I')            # crozier staff
for y in (30, 44, 58): c.text(54, y, ['gGg'])  # brass rings
c.text(49, 0, ['   gGGg  ', '  G    g ', ' G  oF  g', ' g FfOO g', '  g  O  g', '      gg ', '      j',
               '      jj', '     jJjj', '      ii', '      ii', '      ii'])    # brass crook with fire inside
c.line(27, 32, 20, 44, 'Q'); c.line(28, 33, 21, 45, 'r'); c.text(18, 45, ['ml', 'sm'])   # back hand, open
flame(c, 19, 44, 6, 1)                        # a flame floating above the open palm
sparks(c, ((10, 52), (62, 50), (66, 62), (5, 64), (22, 58), (48, 56), (58, 42), (12, 40), (70, 54), (8, 30)))
write('boss_pyre_abbot', pal(SOOT, SKIN, EMBER, WOOD, IRON, BRASS, BONE, b='8a827c', B='c2b9ae', v='3a0c10',
      V='6a1a18', n='3a2418', N='6a4a2a', k='100808'), c, (36, 89), (-17, -47))

# --- Die Ewige Esse: a living forge colossus - a chipped brick furnace bound with riveted iron bands,
# a burning grate for a face, smoking chimneys, bellows and pipes on its side, chains on its shoulders,
# one iron arm raising a dripping hammer, an anvil with a glowing work piece at its feet
c = C(96, 100)
D = 'iIjJ'
for row, y in enumerate(range(22, 88, 5)):    # furnace body of soot-blackened bricks, chipped outline
    off = 0 if row % 2 else 5
    inset = 4 if row < 2 else (1 if row % 3 == 0 else 0)
    for x in range(16 + inset + off - 5, 78 - inset, 10):
        x0 = max(x, 16 + inset); w = min(x + 9, 78 - inset) - x0
        if w > 1: c.box(x0, y, w, 4, 'qQrR')
for (x, y) in ((16, 37), (77, 52), (16, 67), (77, 72)): c.rect(x, y, 2, 3, '.')   # chipped bricks
for y in (27, 58, 80):                        # riveted iron bands round the body
    c.rect(16, y, 62, 2, 'I'); c.rect(16, y, 62, 1, 'j')
    for x in range(18, 78, 6): c.put(x, y, 'J')
for (x0, y0, x1, y1) in ((18, 52, 26, 54), (64, 62, 76, 63), (20, 70, 30, 72)):   # glowing mortar near the fire
    seam(c, [(x0, y0), (x1, y1)])
c.box(30, 4, 12, 18, 'qQrR'); c.box(47, 8, 10, 14, 'qQrR')       # two chimneys
c.rect(29, 4, 14, 2, 'r'); c.rect(46, 8, 12, 2, 'r'); c.rect(29, 12, 14, 1, 'I'); c.rect(46, 15, 12, 1, 'I')
for (x, s) in ((36, 6), (52, 5)):
    flame(c, x, 3, s, x)
smoke(c, ((32, 0), (40, 1), (54, 3), (58, 0), (27, 2)))
c.box(26, 30, 42, 22, D)                      # iron face plate
for (x, y) in ((27, 31), (65, 31), (27, 49), (65, 49), (46, 31)): rivet(c, x, y)
c.rect(30, 34, 34, 14, 'k')                   # furnace mouth
c.rect(31, 42, 33, 6, 'O'); c.rect(33, 44, 29, 3, 'f'); c.rect(37, 45, 21, 1, 'F')   # fire inside
for x in range(30, 64, 4):                    # grate bars, hot at the bottom
    c.rect(x, 34, 1, 14, 'I'); c.put(x, 46, 'o'); c.put(x, 47, 'O')
c.text(33, 36, ['FF', 'fF']); c.text(58, 36, ['FF', 'Ff'])         # two white-hot eyes in the grate
drip(c, 40, 48, 3); drip(c, 55, 48, 2)        # molten metal dripping from the mouth
c.rect(36, 55, 22, 4, 'o'); c.rect(38, 56, 18, 2, 'O'); c.text(46, 55, ['jJ'])   # glowing ash door with handle
c.ell(12, 32, 7, 6, D); c.ell(82, 32, 7, 6, D)                    # iron shoulders
chain(c, 8, 36, 10, 52, 'J', 'j'); chain(c, 86, 36, 90, 50, 'J', 'j')   # chains hanging from the shoulders
c.box(5, 36, 12, 24, D)                       # back arm
for y in (40, 48, 56): rivet(c, 7, y)
c.box(4, 60, 14, 10, 'qQrR'); seam(c, [(6, 63), (10, 66)])        # back fist of brick
shade(c, poly([(79, 64), (92, 62), (94, 70), (92, 78), (79, 76)]), 'wWxX')   # bellows on its side
for y in (66, 69, 72): c.line(80, y, 92, y, 'n')                    # leather pleats
c.text(90, 78, ['jJ', 'Ii'])                  # bellows handle
c.line(79, 70, 74, 70, 'I'); c.line(79, 71, 74, 71, 'i'); c.text(72, 69, ['jJ', 'Ii'])   # pipe into the furnace
shade(c, poly([(78, 36), (85, 36), (91, 24), (90, 20), (84, 20), (79, 30)]), D)   # front arm raised
for y in (26, 31): rivet(c, 85, y)
c.box(82, 15, 10, 7, D); rivet(c, 84, 17)     # fist
c.rect(85, 3, 3, 14, 'w'); c.rect(85, 3, 1, 14, 'x')              # hammer haft through the fist
c.box(78, 0, 16, 6, D); c.text(81, 2, ['oOfO']); drip(c, 93, 6, 3); drip(c, 79, 6, 2)   # hammer head, dripping
c.box(60, 86, 30, 6, D); c.box(66, 92, 16, 6, D); c.text(55, 86, ['iiiii', '  iii'])    # anvil with horn
c.text(66, 87, ['j  j  j'])                   # hammer marks
c.text(69, 84, ['oOfFfOo'])                   # glowing work piece
sparks(c, ((64, 81), (76, 79), (82, 82), (69, 77), (88, 84), (60, 82), (73, 75), (91, 80)))
c.box(20, 88, 12, 10, 'qQrR'); c.box(43, 88, 12, 10, 'qQrR')     # stumpy brick legs
c.rect(20, 92, 12, 1, 'I'); c.rect(43, 92, 12, 1, 'I')           # iron bands round the legs
write('boss_eternal_forge', pal(SOOT, EMBER, WOOD, i='141216', I='2c282e', j='4a444c', J='7a7276', A='57514f',
      b='8a827c', n='2a1a10', k='0a0606'), c, (48, 98), (10, -56))
