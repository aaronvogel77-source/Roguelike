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

# --- Wundversiegler: plague surgeon with a long bird mask, needle and glowing thread, bandages
c = C(36, 54)
for y in range(18, 52):                      # leather coat
    half = 5 + (y - 18) // 5
    for x in range(-half, half + 1):
        if y > 48 and x % 3 == 0: continue
        u = (x + half) / (2 * half)
        c.put(14 + x, y, 'L' if u < .22 else 'l' if u > .75 else 'm')
for y in range(22, 46, 5): c.line(9, y, 19, y + 2, 'W')            # bandages around the coat
c.ell(14, 11, 6, 6, 'lmLM')                  # hood
c.text(10, 1, ['  kkkkk ', ' kKKKKKk', 'kKMMMMMK'])                  # brimmed hat
c.ell(16, 11, 3, 3, 'pPqQ')                  # mask
c.text(15, 10, ['ee'])                       # glass eyes
c.line(19, 12, 30, 16, 'q'); c.line(19, 13, 29, 17, 'p'); c.line(19, 14, 27, 17, 'P')  # long beak
c.line(22, 26, 30, 22, 'm'); c.text(30, 20, ['QQ', 'QQ'])           # arm raising the needle
c.line(32, 12, 32, 22, 'N'); c.put(32, 11, 'Q')                     # needle
c.line(33, 22, 35, 30, 'y'); c.line(35, 30, 31, 36, 'y')            # glowing thread
write('wound_sealer', {'l': '1a120c', 'L': '5a4028', 'm': '3a2818', 'M': '7a5a3a', 'k': '0c0806', 'K': '2a2018',
      'p': '8a7e6a', 'P': 'b8ac94', 'q': 'd8ccb4', 'Q': 'f0e8d4', 'e': '7af0c0', 'W': 'd8d0c0', 'N': 'c0c8d4',
      'y': '7af0c0'}, c, (14, 52), (31, -34))

# --- Tresorkardinal: obese cardinal in red and gold, tall mitre, holding a golden reliquary shield
c = C(44, 58)
r = 'rRsS'  # cardinal red ramp
c.ell(20, 38, 13, 16, r)                     # huge robe
c.rect(19, 24, 3, 32, 'G'); c.rect(19, 24, 1, 32, 'T')             # gold stole
c.ell(20, 20, 7, 6, r)                       # shoulders / cape
c.ell(20, 13, 5, 5, 'pPqQ')                  # fat face
c.text(18, 12, ['k k'])
c.text(19, 15, ['ppp'])                      # double chin
c.tri((15, 9), (25, 9), (20, -1), 'a')       # mitre
c.tri((16, 8), (24, 8), (20, 0), 'G')
c.text(19, 3, [' T ', 'TGT', ' T '])        # jewel cross on the mitre
c.box(30, 22, 12, 14, 'aAGT')                # reliquary shield
c.text(33, 25, ['  T  ', ' TeT ', 'TeeeT', ' TeT ', '  T  '])     # glowing gem
c.line(27, 28, 31, 28, 'R')                  # arm holding it
for (x, y) in ((3, 20), (40, 12), (5, 40)):                          # small floating shield glyphs
    c.text(x, y, ['eee', 'eTe', ' e '])
write('vault_cardinal', {'r': '4a0c14', 'R': '8a1a24', 's': 'c03038', 'S': 'e86058', 'a': '6a4a10', 'A': 'a87c20',
      'G': 'dca42c', 'T': 'fff0a0', 'p': 'b08a74', 'P': 'd0a890', 'q': 'e8c4aa', 'Q': 'f8e0cc', 'k': '1a0c0a',
      'e': '7af0ff'}, c, (20, 56), (33, -30))

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
