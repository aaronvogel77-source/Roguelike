from sk import C, write
# --- Bettlergeist: tattered hooded ghost, holding out a bowl, chain dragging
c = C(30, 44)
G = '0123'  # ghost ramp
c.ell(14, 13, 8, 9, G)                      # hood
for y in range(18, 40):                     # robe widening, tattered hem
    half = 6 + (y - 18) // 3
    for x in range(-half, half + 1):
        if y > 34 and (x * 3 + y) % 5 == 0: continue
        u = (x + half) / (2 * half)
        c.put(14 + x, y, '2' if u < .25 else '0' if u > .78 else '1')
c.ell(16, 13, 5, 6, 'kkkk')                 # dark face hole
c.text(15, 11, ['e e'])                     # eyes
c.text(16, 15, ['mmm'])                     # mouth
c.text(19, 22, ['     GT  ', '1 bBBBBBBb', '11 bbbbbb '])  # arm holding out a bowl with a coin
c.line(6, 30, 2, 40, 'i'); c.line(5, 31, 1, 41, 'I')  # chain
for y in (33, 36, 39): c.put(3, y, 'I')
write('beggar_ghost', {'0': '1c2630', '1': '3a5060', '2': '6a8a9a', '3': 'b8d8e0', 'k': '06080c', 'e': '9ae8ff',
      'm': '1c2630', 'b': '4a2e1c', 'B': '94683f', 'i': '3e434c', 'I': '8e98a8'}, c, (14, 41), (10, -16))

# --- Münzwerfer: goblin with a coin sack on its back and a sling
c = C(32, 38)
c.ell(9, 18, 8, 9, 'aAbB')                  # sack
c.text(5, 10, ['  rrrr', ' rRRRRr'])        # sack tie
c.ell(19, 22, 6, 7, 'cCdD')                 # body (tunic)
c.ell(21, 12, 5, 5, '0123')                 # head
c.text(25, 11, ['22', '1'])                 # long nose
c.text(21, 10, ['Y'])                       # eye
c.text(15, 8, ['13', ' 2'])                 # ear
c.text(20, 15, ['tkt'])                     # grin
c.rect(16, 29, 2, 6, 'n'); c.rect(21, 29, 2, 6, 'n')   # legs
c.rect(15, 34, 4, 2, 'k'); c.rect(20, 34, 4, 2, 'k')
c.line(25, 21, 28, 13, 'w'); c.line(28, 13, 29, 6, 'w')  # sling strap
c.text(28, 4, ['GG', 'GT'])                 # coin in the sling
c.text(1, 20, [' G', 'GT', ' G'])           # coins spilling
write('coin_thrower', {'0': '1a3416', '1': '35602a', '2': '5e9a3c', '3': '9ccc62', 'Y': 'ffd040', 't': 'f0ead8',
      'k': '120c10', 'a': '3a2410', 'A': '6a4422', 'b': '9a6a38', 'B': 'c89a5a', 'r': '6a1a1a', 'R': 'a03030',
      'c': '2a1a2e', 'C': '4a3050', 'd': '6a4a78', 'D': '8a6aa0', 'n': '3a2a1a', 'w': '94683f', 'G': 'dca42c',
      'T': 'fff0a0'}, c, (19, 35), (12, -24))

# --- Der Wechsler: a two-faced mask (gold / black) over a purple robe, coins circling
c = C(36, 50)
for y in range(22, 48):
    half = 6 + (y - 22) // 4
    for x in range(-half, half + 1):
        if y > 44 and x % 3 == 0: continue
        u = (x + half) / (2 * half)
        c.put(18 + x, y, 'P' if u < .25 else 'q' if u > .75 else 'p')
for y in range(24, 46, 4): c.line(14, y, 22, y, 'q')
c.ell(18, 13, 8, 10, 'aAGT', cut=lambda x, y: x <= 0)   # gold half
c.ell(18, 13, 8, 10, 'kkKK', cut=lambda x, y: x > 0)    # black half
c.text(13, 10, ['RR'])                       # eye gold side
c.text(21, 10, ['ww'])                       # eye black side
c.text(14, 17, ['aaaa'])                     # frown on gold side
c.text(19, 18, ['wwww'])                     # smile on black side
c.text(18, 17, ['w'])
c.line(18, 3, 18, 23, 'K')                   # seam
for (x, y) in ((3, 10), (31, 14), (4, 30), (32, 32), (6, 42)):
    c.text(x - 1, y - 1, [' G ', 'GTG', ' G '])
write('the_changer', {'a': '6a4a10', 'A': 'a87c20', 'G': 'dca42c', 'T': 'fff0a0', 'k': '0a080c', 'K': '2a2430',
      'R': 'e03040', 'w': 'e8e0f0', 'p': '4a2a6a', 'P': '6a4a8a', 'q': '2a1640'}, c, (18, 47), (8, -26))

# --- Gierschlund: a mimic chest, lid open, teeth and a long tongue
c = C(38, 34)
c.box(3, 16, 32, 15, 'aAbB')                 # chest body
for x in (3, 18, 33): c.rect(x, 16, 2, 15, 'i')  # iron bands
c.rect(3, 22, 32, 1, 'i')
c.box(16, 22, 6, 5, 'cGGT')                  # lock
c.put(19, 24, 'k')
c.box(3, 3, 32, 8, 'aAbB')                   # lid (raised)
for x in (3, 18, 33): c.rect(x, 3, 2, 8, 'i')
c.rect(4, 11, 30, 5, 'k')                    # mouth
for x in range(5, 33, 3): c.text(x, 11, ['t', 't']); c.text(x + 1, 14, ['t'])
c.text(13, 13, ['rRRRRr', '  rRRRr', '   rRRRr', '    rrRr'])   # tongue
c.text(7, 8, ['YY']); c.text(27, 8, ['YY'])  # eyes on the lid
c.rect(5, 31, 3, 2, 'k'); c.rect(30, 31, 3, 2, 'k')  # little feet
write('greedmaw', {'a': '2e1a0e', 'A': '5a3418', 'b': '7a4a22', 'B': 'a8743a', 'i': '3e434c', 'c': '9a6212',
      'G': 'dca42c', 'T': 'fff0a0', 'k': '0e080a', 't': 'f0ead8', 'r': '8a1a24', 'R': 'd04050', 'Y': 'ffd040'},
      c, (19, 32), (10, -18))
