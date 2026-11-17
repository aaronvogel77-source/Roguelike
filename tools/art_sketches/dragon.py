"""Gieriger Drache: a red dragon on its hoard - big bat wings with finger bones,
S-neck, horned head with open jaws and fire, spiked back, spade tail, claws."""
from sk import C, write
c = C(60, 52)
R = 'rRsS'
# Gold hoard
c.ell(30, 47, 27, 5, 'aAGT')
for (x, y) in ((7, 45), (15, 43), (41, 43), (51, 46), (29, 42), (35, 45), (22, 46)):
    c.text(x, y, ['T'])
c.text(47, 40, [' GG', 'GTTG', ' aa'])
# Far wing (dark), peeking above the near wing
shoulder = (27, 25)
wrist = (20, 3)
c.tri(shoulder, wrist, (31, 8), 'q')
# Near wing: membrane panels between finger bones, scalloped trailing edge
tips = [(2, 12), (6, 20), (12, 24), (19, 26)]
panels = [wrist] + tips
for a, b in zip(panels, panels[1:]):
    c.tri(shoulder, a, b, 'W')
for i, t in enumerate(tips):  # scallops: cut small notches between the tips
    if i + 1 < len(tips):
        mx, my = (t[0] + tips[i + 1][0]) // 2, (t[1] + tips[i + 1][1]) // 2
        c.tri((mx - 1, my + 1), (mx + 2, my + 1), (mx + 1, my - 2), '.')
for t in [wrist] + tips:  # finger bones
    c.line(wrist[0], wrist[1], t[0], t[1], 'r')
c.line(shoulder[0], shoulder[1], wrist[0], wrist[1], 'r')
c.line(shoulder[0] - 1, shoulder[1], wrist[0] - 1, wrist[1], 'R')
c.text(wrist[0] - 1, wrist[1] - 2, ['h', 'hh'])  # wing claw
# Shading on the membrane: darker towards the body
for y in range(c.h):
    for x in range(c.w):
        if c.g[y][x] == 'W' and (x + y) % 6 == 0:
            c.put(x, y, 'w')
# Tail curling down to a spade tip
pts = [(15, 37), (11, 40), (7, 42), (4, 44), (2, 47)]
for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
    c.line(x0, y0, x1, y1, 'R'); c.line(x0, y0 + 1, x1, y1 + 1, 'r')
c.text(0, 46, [' S', 'SSS', ' r'])
# Body with belly plates
c.ell(23, 34, 12, 7, R)
for x in range(15, 32, 3):
    c.text(x, 39, ['yY'])
# Back spikes
for x in range(14, 31, 4):
    c.text(x, 26, [' h', 'hh'])
# Hind haunch and leg, front leg stepping forward, claws
c.ell(16, 38, 5, 5, R); c.rect(14, 42, 3, 3, 'R'); c.text(12, 45, ['hkhkh'])
c.ell(32, 38, 3, 4, R); c.rect(33, 41, 3, 4, 'R'); c.text(32, 45, ['hkhkh'])
# Neck: S-curve up to the head
for (x, y, r) in ((32, 30, 4), (35, 26, 4), (37, 22, 3), (38, 18, 3), (40, 15, 3)):
    c.ell(x, y, r, r, R)
for y in range(17, 31, 3):
    c.put(39 - (30 - y) // 4, y, 'Y')
# Head: a wedge-shaped skull with brow ridge, glowing eye, open jaws and fire
c.text(38, 3, [
    "hh..............",
    ".hhh....h.......",
    "..hhh...hh......",
    "...hhRRRRhh.....",
    "..RRSSSSSSSSr...",
    ".RRSrrYkRRRRRRr.",
    ".RRRRRRRRRRRRRRS",
    ".rRRRRRRRRRRRRRr",
    "..rRRRtt.tt.tt..",
    "...rRk......ffF.",
    "...rRk.....fFFFf",
    "....rRtt.tt.tFf.",
    ".....rRRRRRRRr..",
    "......rrrrrrr...",
])
c.text(55, 5, ['o', 'oo'])                     # smoke from the nostril
write('greedy_dragon', {'r': '4a0c10', 'R': '8a1c22', 's': 'c43a32', 'S': 'f07050', 'y': 'b07a30', 'Y': 'e8b050',
      'k': '1a0808', 't': 'f4ecdc', 'h': 'e8dcc0', 'w': '7a1c24', 'W': 'b0443a', 'q': '3a080c', 'F': 'ffd060',
      'f': 'ff7020', 'o': '8a8a90', 'a': '6a4a10', 'A': 'a87c20', 'G': 'dca42c', 'T': 'fff0a0'}, c, (30, 51), (18, -36))
print('dragon drawn')
