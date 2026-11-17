from sk import C, write
# New enemies: two for act 1, six act-2 elites. Light from the top left,
# four-tone ramps (shadow cooler, light warmer), effects glow, bodies stay dark.

# --- Fluchweber: hunched hooded witch with four spider arms weaving a violet curse thread
c = C(34, 44)
R = 'mMnN'  # dark plum robe ramp
for y in range(16, 42):                      # robe, hunched, widening
    half = 5 + (y - 16) // 3
    for x in range(-half, half + 1):
        if y > 38 and (x + y) % 4 == 0: continue
        u = (x + half) / (2 * half)
        c.put(15 + x, y, R[2] if u < .22 else R[0] if u > .75 else R[1])
c.ell(16, 12, 7, 7, R)                       # hood, bent forward
c.ell(19, 13, 4, 4, 'kkkk')                  # face hole
c.text(19, 12, ['v v'])                      # glowing eyes
c.text(20, 15, ['ww'])                       # pale chin
for (x0, y0, x1, y1) in ((20, 20, 30, 15), (20, 23, 31, 22), (11, 21, 3, 15), (11, 24, 2, 23)):
    c.line(x0, y0, x1, y1, 'a'); c.line(x0, y0 + 1, x1, y1 + 1, 'A')   # spider arms
    c.put(x1, y1 - 1, 'A')
c.line(30, 14, 30, 4, 'V'); c.line(31, 21, 33, 8, 'V')                 # curse threads up
c.line(3, 14, 6, 4, 'V'); c.line(2, 22, 0, 10, 'V')
c.text(14, 3, [' V V ', 'VvVvV', ' VvV ', '  V  '])                   # woven curse sigil
c.text(12, 41, ['kk    kk'])                                         # feet
write('curse_weaver', {'m': '1e1424', 'M': '3a2446', 'n': '5a3a6a', 'N': '7e5a90', 'k': '08060c', 'v': 'd070ff',
      'V': 'a050e0', 'w': 'c8c0b0', 'a': '2a2030', 'A': '5a4a62'}, c, (16, 42), (30, -28))

# --- Kerzenträger: small wax acolyte, half melted, carrying a tall three-armed candelabrum
c = C(30, 46)
W = 'wWxX'  # wax ramp
for y in range(20, 44):
    half = 4 + (y - 20) // 4
    for x in range(-half, half + 1):
        u = (x + half) / (2 * half)
        c.put(11 + x, y, W[2] if u < .25 else W[0] if u > .75 else W[1])
for (x, y) in ((6, 26), (16, 30), (8, 36), (15, 40)):              # wax drips
    c.line(x, y, x, y + 3, 'X')
c.ell(11, 15, 5, 6, W)                       # head (bald, waxy)
c.text(10, 14, ['k k'])                      # sunken eyes
c.text(11, 17, ['x'])
c.ell(11, 9, 2, 2, 'oOfF'); c.text(11, 5, ['F', 'f'])              # candle stub melted into the head
c.rect(21, 12, 2, 30, 'b'); c.rect(21, 12, 1, 30, 'B')             # candelabrum pole
c.line(16, 14, 27, 14, 'b'); c.line(16, 13, 27, 13, 'B')            # arms of the candelabrum
for x in (16, 21, 27):
    c.rect(x, 8, 2, 5, 'W'); c.put(x, 8, 'X')                       # candles
    c.text(x, 4, [' F', 'Ff', 'fo'])                                # flames
c.line(14, 26, 21, 22, 'W'); c.line(14, 27, 21, 23, 'w')            # arm holding the pole
c.rect(18, 42, 7, 2, 'b')                                           # foot of the candelabrum
write('candle_bearer', {'w': '6a5a3a', 'W': 'a8946a', 'x': 'd0c094', 'X': 'f0e6c4', 'k': '1a1008', 'o': 'c04010',
      'O': 'e07020', 'f': 'ffb030', 'F': 'fff0a0', 'b': '3a2a1a', 'B': '8a6a3a'}, c, (12, 44), (22, -36))

# --- Salzgolem: hulking golem of grey-white salt blocks, crystal spikes, cold blue shadows
c = C(46, 56)
S = 'sStT'  # salt ramp (blue shadow -> warm white)
c.box(13, 14, 20, 20, S)                     # chest block
c.box(16, 34, 14, 8, S)                      # hips
c.box(3, 14, 10, 14, S); c.box(33, 14, 10, 14, S)      # shoulders/upper arms
c.box(2, 28, 10, 14, S); c.box(34, 28, 10, 14, S)      # fists
c.box(14, 42, 8, 12, S); c.box(25, 42, 8, 12, S)       # legs
c.box(17, 4, 12, 11, S)                      # head
c.text(19, 8, ['ee  ee'])                    # icy eyes
c.text(20, 12, ['kkkkk'])                    # mouth crack
for (x, y) in ((4, 9), (8, 11), (37, 9), (41, 11), (22, 1)):        # crystal spikes
    c.text(x, y, [' T', 'Tt', 'tS'])
for (x0, y0, x1, y1) in ((16, 18, 22, 26), (27, 16, 30, 24), (5, 31, 9, 37), (36, 33, 40, 38)):
    c.line(x0, y0, x1, y1, 's')              # cracks
c.text(20, 22, ['  T ', ' TeT', '  T '])     # glowing core crystal
write('salt_golem', {'s': '4a5a70', 'S': '8a98ac', 't': 'c8d0d8', 'T': 'f4f0e6', 'e': '8ae0ff', 'k': '141822'},
      c, (23, 54), (4, -26))

# --- Bannprior: tall gaunt priest, black and white robe, pale mask, staff with a crossed-out heart
c = C(36, 58)
for y in range(16, 56):                      # long robe
    half = 5 + (y - 16) // 6
    for x in range(-half, half + 1):
        u = (x + half) / (2 * half)
        ch = 'g' if u < .2 else 'k' if u > .78 else 'K'
        if abs(x) <= 1 and y > 18: ch = 'W'  # white stole
        c.put(15 + x, y, ch)
c.rect(14, 22, 3, 3, 'r'); c.put(15, 23, 'R')                       # red seal on the stole
c.ell(15, 10, 5, 6, 'kKgG')                  # hood
c.ell(16, 11, 3, 4, 'pPqQ')                  # pale mask
c.text(15, 10, ['k k'])                      # eye slits
c.text(16, 13, ['k'])
c.rect(28, 6, 2, 50, 'b'); c.rect(28, 6, 1, 50, 'B')                # staff
c.text(25, 0, [' rr rr ', 'rRRrRRr', 'rRRRRRr', ' rRRRr ', '  rRr  ', '   r   '])   # heart
c.line(24, 0, 32, 6, 'W'); c.line(24, 1, 32, 7, 'g')                # cross-out bar
c.line(20, 22, 27, 20, 'K'); c.text(26, 19, ['pp', 'pp'])           # hand on the staff
write('ban_prior', {'k': '0c0a10', 'K': '24202c', 'g': '4a4452', 'G': '6e6878', 'W': 'e8e2d4', 'r': '8a1020',
      'R': 'e03040', 'p': 'a89a8a', 'P': 'c8bcaa', 'q': 'e0d6c4', 'Q': 'f6eee0', 'b': '3a2a1a', 'B': '8a6a3a'},
      c, (15, 56), (28, -40))

# --- Schildbrecher: bronze brute with a huge iron maul raised high, broken shield shards at its feet
c = C(48, 54)
B = 'bBcC'  # bronze ramp
c.ell(20, 28, 11, 11, B)                     # barrel body
c.box(13, 22, 14, 12, 'hHiI')                # iron chest plate
c.text(15, 24, ['I        I', '          ', 'I        I'])        # rivets
c.rect(10, 35, 21, 3, 'w'); c.rect(18, 35, 4, 3, 'C')               # belt with buckle
c.ell(20, 13, 6, 6, 'hHiI')                  # bull-like helmet
c.text(11, 8, ['II ', ' IIh'])               # horns
c.text(26, 8, [' II', 'hII '])
c.rect(16, 13, 8, 2, 'k'); c.text(17, 13, ['e  e'])                 # visor slit with eyes
c.ell(8, 27, 4, 6, B)                        # left arm
c.ell(31, 22, 4, 5, B)                       # right arm raised
c.box(14, 38, 6, 13, 'hHiI'); c.box(22, 38, 6, 13, 'hHiI')        # armoured legs
c.rect(13, 50, 8, 2, 'k'); c.rect(21, 50, 8, 2, 'k')                # boots
c.rect(34, 8, 3, 18, 'w'); c.rect(34, 8, 1, 18, 'W')                # maul handle
c.box(28, 0, 15, 9, 'hHiI')                  # iron maul head
c.rect(31, 0, 2, 9, 'C'); c.rect(38, 0, 2, 9, 'C')                  # bronze bands
c.text(34, 3, ['ee', 'ee'])                  # glowing rune between the bands
c.text(1, 47, [' S', 'Ss', 's '])            # shield shards
c.text(36, 49, [' Ss', 'sSs'])
c.text(7, 51, ['SSs'])
write('shield_breaker', {'b': '3a2210', 'B': '7a4a1c', 'c': 'b07434', 'C': 'e0b060', 'h': '1e1e26', 'H': '3e3e4a',
      'i': '6a6a78', 'I': 'a8a8b8', 'e': 'ff6a30', 'k': '0a0808', 'w': '3a2a1a', 'W': '8a6a3a', 's': '5a6a80',
      'S': 'a8b8cc'}, c, (21, 52), (35, -38))

# --- Wundversiegler: gaunt plague surgeon, hunched, tall black hat, bone beak mask with red glass eyes,
# charcoal-green coat with a stitched apron, bandaged arms, a big curved needle with a glowing thread
c = C(38, 58)
L = 'lmMN'   # charcoal-green coat ramp
def coat(y, cx, half):
    for x in range(-half, half + 1):
        u = (x + half) / max(1, 2 * half)
        ch = L[2] if u < .2 else L[0] if u > .78 else L[1]
        if y > 38 and (x + half) % 4 == 3: ch = L[0]     # folds in the hem
        if y > 52 and (x + y) % 3 == 0: continue          # ragged hem
        c.put(cx + x, y, ch)
for y in range(20, 55):
    coat(y, 16, 4 + (y - 20) // 5)
for y in range(27, 50):                       # stitched leather apron
    half = 2 + (y - 27) // 8
    for x in range(-half, half + 1):
        c.put(17 + x, y, 'a' if x < half else 'A')
    if y % 3 == 0: c.put(17, y, 'w')
c.rect(13, 54, 3, 3, 'k'); c.rect(18, 54, 3, 3, 'k')                # boots
c.ell(16, 21, 6, 3, L)                        # hunched shoulders
c.ell(15, 15, 4, 4, 'mMNN')                   # hood
c.ell(17, 15, 3, 3, 'bBcC')                   # bone mask
c.text(16, 14, ['ee'])                        # red glass eyes
c.put(16, 13, 'E')
for i in range(9):                            # long curved beak (downward), shaded
    w = 2 if i < 4 else 1
    for dy in range(w):
        c.put(20 + i, 15 + i // 3 + dy, 'C' if dy == 0 else 'b')
c.text(9, 7, ['    kkkk', '    kKKk', '    kKKk', '   kKKKKk', 'kkkkkkkkkkkkk'])   # tall hat, wide brim
c.line(10, 22, 7, 34, 'm'); c.line(11, 22, 8, 34, 'M')             # back arm, long and thin
for y in (25, 28, 31): c.put(9, y, 'w')       # bandage strips
c.text(5, 34, ['gg', 'gG'])                   # back hand
c.line(21, 23, 27, 28, 'm'); c.line(21, 24, 27, 29, 'M')           # front arm reaching forward
for x in (23, 25): c.put(x, 25 + (x - 21) // 2, 'w')
c.text(27, 27, ['gG', 'gg'])                  # hand
c.line(29, 26, 31, 20, 'n'); c.line(31, 20, 30, 16, 'n'); c.put(29, 15, 'N')   # curved needle
c.line(29, 28, 33, 34, 'y'); c.line(33, 34, 31, 41, 'y'); c.put(32, 42, 'Y')  # glowing thread
write('wound_sealer', {'l': '0e1210', 'm': '1e2a24', 'M': '34463c', 'N': '506a58', 'k': '060606', 'K': '1a1a1e',
      'a': '2a1a10', 'A': '4a3020', 'w': 'c8c0aa', 'b': '8a8270', 'B': 'b0a890', 'c': 'd0c8b0', 'C': 'ece4cc',
      'e': 'c02020', 'E': 'ff7060', 'g': '3a3028', 'G': '6a5a48', 'n': '8a96a6', 'N': 'd8e0ea', 'y': '6ae0a8',
      'Y': 'c8ffe4'}, c, (16, 57), (28, -42))

# --- Tresorkardinal: corrupt cardinal of the vault - golden death mask under a tall mitre, heavy
# blood-red robe with gold borders and folds, gaunt hands clutching a reliquary shield
c = C(42, 58)
r = 'rRsS'   # deep blood red ramp
for y in range(24, 55):                       # robe, bell-shaped
    half = 7 + (y - 24) // 3
    for x in range(-half, half + 1):
        if y > 52 and (x + y) % 4 == 0: continue
        u = (x + half) / (2 * half)
        ch = r[2] if u < .2 else r[0] if u > .8 else r[1]
        if (x + half) % 5 == 4 and y > 34: ch = r[0]
        c.put(20 + x, y, ch)
c.rect(19, 24, 3, 31, 'A'); c.rect(19, 24, 1, 31, 'G')              # gold front band
for y in range(27, 54, 4): c.put(20, y, 'T')                         # studs on the band
c.ell(20, 23, 9, 5, r)                        # mozzetta
for x in range(12, 29): c.put(x, 27 if abs(x - 20) < 7 else 26, 'A')  # gold edge of the mozzetta
c.ell(20, 16, 4, 5, 'aAGT')                   # golden death mask (small head)
c.text(18, 15, ['k k'])                       # hollow eyes
c.text(18, 16, ['e e'])                       # faint glow inside
c.text(19, 19, ['kk'])                        # mouth slit
c.tri((15, 12), (25, 12), (20, 0), 'r')       # tall mitre (red with gold)
c.tri((16, 11), (24, 11), (20, 1), 'R')
c.line(20, 2, 20, 11, 'G'); c.line(17, 8, 23, 8, 'G')               # gold cross on the mitre
c.rect(15, 11, 11, 2, 'A')                    # mitre band
c.line(15, 13, 14, 21, 'A'); c.line(25, 13, 26, 21, 'A')            # lappets
c.ell(9, 33, 3, 6, r); c.ell(31, 33, 3, 6, r)                       # sleeves
c.box(13, 32, 15, 14, 'aAGT')                 # reliquary shield
c.rect(14, 33, 13, 1, 'T')
c.text(17, 35, ['  T  ', ' TeT ', 'TeeeT', ' TeT ', '  T  '])     # glowing gem
c.text(11, 37, ['pq']); c.text(28, 37, ['qp'])                      # gaunt hands
for (x, y) in ((3, 16), (36, 12), (2, 42), (37, 44)):               # floating shield glyphs
    c.text(x, y, ['eee', 'eTe', ' e '])
write('vault_cardinal', {'r': '2a060c', 'R': '5a0e18', 's': '8a1a26', 'S': 'b8343c', 'a': '5a3a0e', 'A': '9a6e1c',
      'G': 'd0a030', 'T': 'fff0a0', 'p': '8a7a6a', 'q': 'b8a894', 'k': '0a0606', 'e': '7af0ff'},
      c, (20, 56), (20, -24))

# --- Uhrwerk-Wächter: brass automaton with a clock face in its chest, gears, a wind-up key on its back
c = C(44, 56)
M = 'aAGT'  # brass ramp
c.box(12, 16, 20, 20, 'iIjJ')                # dark iron chest plate
c.ell(22, 26, 8, 8, M)                       # clock face rim
c.ell(22, 26, 6, 6, 'wWxX')                  # dial
c.line(22, 26, 22, 21, 'k'); c.line(22, 26, 26, 27, 'k')            # clock hands
for (x, y) in ((22, 20), (28, 26), (22, 32), (16, 26)): c.put(x, y, 'k')
c.box(16, 4, 12, 11, M)                      # head
c.text(18, 8, ['eeeeeeee'])                  # visor glow
c.rect(21, 1, 2, 3, 'A')                     # little chimney
c.text(20, 0, ['ss'])                        # steam
c.box(4, 16, 8, 8, M); c.box(32, 16, 8, 8, M)                       # shoulders
c.box(5, 24, 6, 12, 'iIjJ'); c.box(33, 24, 6, 12, 'iIjJ')          # arms
c.ell(8, 38, 3, 3, M); c.ell(36, 38, 3, 3, M)                       # fists
c.box(14, 36, 16, 5, M)                      # hips
c.box(14, 41, 6, 13, 'iIjJ'); c.box(24, 41, 6, 13, 'iIjJ')         # legs
c.ell(9, 46, 4, 4, M); c.text(8, 45, ['kk', 'kk'])                  # gear by the leg
c.text(0, 18, ['  A ', 'AGGA', 'G  G', 'AGGA'])                     # wind-up key behind
write('clockwork_warden', {'a': '5a3a10', 'A': '9a6a20', 'G': 'd4a040', 'T': 'fff0b0', 'i': '1e1e26', 'I': '3a3a46',
      'j': '5a5a68', 'J': '8a8a98', 'w': '8a7e6a', 'W': 'c8bca4', 'x': 'e8dcc4', 'X': 'fff8e8', 'k': '120c08',
      'e': 'ff7a30', 's': '8a8a98'}, c, (22, 54), (8, -18))
