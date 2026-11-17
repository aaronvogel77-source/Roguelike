from sk import C, write
# --- Der Steuereintreiber: a bloated toad lord in an ermine robe on his money sacks
c = C(66, 76)
for (x, y, r) in ((14, 66, 9), (50, 67, 9), (32, 69, 10)):       # money sacks
    c.ell(x, y, r, 7, 'aAbB'); c.text(x - 2, y - 7, ['rRr'])
c.text(29, 66, ['GG', 'GT']); c.text(47, 64, [' G', 'GT'])        # coin marks
c.ell(32, 46, 21, 18, 'pPqQ')                                    # robe body
for y in range(30, 62):                                          # ermine trim down the front
    c.put(31, y, 'w'); c.put(32, y, 'W' if y % 3 else 'k')
c.ell(32, 24, 13, 11, '0123')                                    # head
c.ell(32, 31, 10, 4, '1223')                                     # wide chin
c.text(22, 16, [' kkk    kkk', 'keeek  keeek', 'keEkk  keEkk', 'keeek  keeek', ' kkk    kkk'])   # bulging eyes
c.text(28, 15, ['GGGGG', 'G   G', 'G   G', 'G   G', 'GGGGG'])                # golden monocle round the right eye
c.text(26, 28, ['kkkkkkkkkkkk', ' tkt    tkt'])                  # wide mouth with teeth
c.text(23, 9, ['T  T  T  T  T', 'GTGGTGGTGGTGG', 'GGrGGGeGGGrGG', 'aaaaaaaaaaaaa'])   # crown
c.box(48, 36, 14, 17, 'RRrr'); c.rect(50, 38, 10, 13, 'w')       # ledger
for y in range(40, 50, 2): c.line(51, y, 58, y, 'k')
c.line(60, 30, 56, 42, 'W'); c.text(59, 27, ['WW', 'W'])          # quill
c.ell(48, 46, 4, 3, '0123')                                      # hand on the ledger
write('boss_tax_collector', {'0': '2a4a1c', '1': '4a7a2e', '2': '7aaa48', '3': 'b4d878', 'e': 'f4ecd0',
      'E': 'ffd040', 'k': '120a0c', 't': 'f0ead8', 'p': '2a1640', 'P': '4a2a6a', 'q': '6a4a8a', 'Q': '8a6aaa',
      'w': 'f2ece4', 'W': 'ffffff', 'a': '3a2410', 'A': '6a4422', 'b': '9a6a38', 'B': 'c89a5a', 'r': '8a1a24',
      'R': 'b02830', 'G': 'dca42c', 'T': 'fff0a0'}, c, (32, 75), (20, -40))

# --- Die Goldene Mauer: a living wall of gold bricks with a furnace face and chained arms
c = C(84, 94)
for row, y in enumerate(range(6, 90, 6)):
    inset = max(0, 12 - row * 3) if row < 5 else 0
    off = 0 if row % 2 else 6
    for x in range(inset + off - 6, 78 - inset, 12):
        x0 = max(x, inset + 3); w = min(x + 11, 80 - inset) - x0
        if w > 1: c.box(x0, y, w, 5, 'aAGT')
for (x, y) in ((22, 40), (60, 58), (30, 75), (52, 24)):          # cracks
    c.line(x, y, x + 4, y + 5, 'k'); c.line(x + 4, y + 5, x + 2, y + 9, 'k')
c.rect(22, 30, 14, 7, 'k'); c.rect(48, 30, 14, 7, 'k')           # eye sockets
c.rect(25, 32, 8, 3, 'r'); c.rect(51, 32, 8, 3, 'r'); c.rect(27, 33, 4, 1, 'Y'); c.rect(53, 33, 4, 1, 'Y')
c.rect(24, 50, 36, 12, 'k')                                       # furnace mouth
c.rect(26, 56, 32, 5, 'o'); c.rect(28, 58, 28, 2, 'Y')
for x in range(25, 59, 4): c.text(x, 50, ['tt', 't'])            # teeth
c.box(0, 40, 8, 26, 'aAGT'); c.box(76, 40, 8, 26, 'aAGT')        # pillar arms
for y in range(42, 66, 4): c.text(1, y, ['iiiiii']); c.text(77, y, ['iiiiii'])  # chains
c.text(38, 2, ['eGe', 'GTG'])                                    # gem on top
write('boss_golden_wall', {'a': '4a2e08', 'A': '9a6a14', 'G': 'd9a530', 'T': 'ffe08a', 'k': '140a06',
      'r': 'c02020', 'Y': 'ffd060', 'o': 'ff7020', 't': 'f0ead8', 'i': '3e434c', 'e': '28b060'}, c, (42, 93), (30, -50))
