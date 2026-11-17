from sk import C, write
# --- Tresorwächter: a stone golem with a round vault door in its chest
c = C(44, 60)
S = '0123'
c.box(10, 18, 24, 26, S)                    # torso
c.box(14, 2, 16, 15, S)                     # head block
c.rect(17, 8, 10, 2, 'k'); c.rect(18, 8, 8, 1, 'e')   # glowing visor
c.box(2, 18, 8, 20, S); c.box(34, 18, 8, 20, S)       # arms
c.box(1, 38, 9, 7, S); c.box(34, 38, 9, 7, S)         # fists
c.box(13, 44, 7, 14, S); c.box(24, 44, 7, 14, S)      # legs
for y in range(22, 44, 5): c.line(11, y, 32, y, '0')  # stone courses
for (x, y) in ((15, 20), (27, 25), (13, 35), (29, 39), (6, 26), (37, 30)): c.put(x, y, '3')
c.ell(22, 31, 8, 8, 'aAGT')                 # vault door
c.ell(22, 31, 5, 5, 'iIiI')
c.text(21, 26, ['GG']); c.text(21, 35, ['GG']); c.text(17, 30, ['G', 'G']); c.text(27, 30, ['G', 'G'])  # bolts
c.text(20, 29, [' TT', 'TkkT', ' TT'])      # dial
write('vault_warden', {'0': '24222a', '1': '3e3c46', '2': '5a5864', '3': '807e8a', 'k': '0a0a0e', 'e': '7af0ff',
      'a': '6a4a10', 'A': 'a87c20', 'G': 'dca42c', 'T': 'fff0a0', 'i': '3e434c', 'I': '8e98a8'}, c, (22, 57), (8, -40))

# --- Gieriger Drache: a small red dragon crouching on its gold
c = C(50, 44)
c.ell(25, 39, 20, 5, 'aAGT')                # gold pile
for (x, y) in ((10, 37), (18, 35), (31, 36), (39, 38), (25, 34)): c.text(x, y, ['T'])
c.ell(22, 28, 12, 8, 'rRsS')                # body
c.ell(20, 31, 8, 4, 'yYyY')                 # belly
c.line(10, 30, 2, 26, 'R'); c.line(9, 31, 1, 27, 'r'); c.text(0, 24, ['RR', ' R'])  # tail
c.ell(33, 18, 4, 7, 'rRsS')                 # neck
c.ell(38, 11, 6, 4, 'rRsS')                 # head
c.text(41, 12, ['RRRR', 'kkkk', 'RRR'])     # snout and jaw
c.put(38, 9, 'Y'); c.put(39, 9, 'k')        # eye
c.text(33, 4, ['h  h', 'hh hh'])            # horns
c.text(45, 10, ['f', ' ff', 'fF'])          # smoke / ember breath
c.text(14, 15, ['   www', '  wWWWw', ' wWWWWWw', 'wWwWwWwW'])   # wing
c.rect(14, 34, 3, 4, 'r'); c.rect(26, 34, 3, 4, 'r')  # legs
c.text(13, 37, ['kkkk']); c.text(25, 37, ['kkkk'])    # claws
write('greedy_dragon', {'r': '5a1014', 'R': '902028', 's': 'c03a3a', 'S': 'e86a5a', 'y': 'c89040', 'Y': 'f0c060',
      'k': '1a0808', 'h': 'e8dcc0', 'w': '6a1420', 'W': 'a02a34', 'f': '8a8a8a', 'F': 'ff9a20',
      'a': '6a4a10', 'A': 'a87c20', 'G': 'dca42c', 'T': 'fff0a0'}, c, (25, 43), (14, -30))

# --- Spiegelmünze: a floating silver coin with a face and little bat wings
c = C(44, 40)
c.text(0, 10, ['  bb      ', ' bBBb     ', 'bBBBBb    ', 'bBbBbBb   ', 'b b b bb  '])        # left wing
c.text(34, 10, ['      bb  ', '     bBBb ', '    bBBBBb', '   bBbBbBb', '  bb b b b'])   # right wing
c.ell(22, 16, 13, 13, '0123')               # coin
c.ell(22, 16, 10, 10, '1223')
c.text(16, 12, ['ee     ee', 'eR     Re'])   # eyes
c.text(17, 20, ['k       k', ' kkkkkkk'])   # grin
c.text(15, 6, ['3  3  3  3'])               # rim glints
c.line(22, 30, 22, 38, 'b')                 # the thin tail it hangs from
write('mirror_coin', {'0': '5a6c8c', '1': '9db0d0', '2': 'c8d6ea', '3': 'ffffff', 'e': 'f4f4ff', 'R': 'e03040',
      'k': '28324a', 'b': '28203a', 'B': '4a3e64'}, c, (22, 39), (10, -18))
