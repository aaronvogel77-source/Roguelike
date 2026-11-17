"""Hand-detailed arms and legs (and full bodies for skins, recipes and aces).

Pivots match FigureArt: arms hang from the shoulder (grid pivot 2,1), legs from the hip
(grid pivot legW/2,0). Back limbs use one tone darker. Writes sections into art/<id>.txt.
"""
import pathlib, re
from bodies import make, DIMS as TORSO_DIMS
ROOT = pathlib.Path(__file__).resolve().parents[2]
LIMBS = {'page': (12, 4, 14), 'knight': (14, 5, 17), 'queen': (14, 4, 18), 'king': (16, 5, 20), 'legend': (16, 5, 20)}
RANK = {'coin_squire': 'page', 'golden_scales': 'queen', 'king_midas': 'king', 'spark_bearer': 'page',
        'enraged_one': 'knight', 'mistress_of_embers': 'queen', 'ash_king': 'king', 'altar_server': 'page',
        'blood_drinker': 'knight', 'chalice_of_return': 'queen', 'drowned_king': 'king', 'blade_apprentice': 'page',
        'executioner': 'knight', 'clear_blade': 'queen', 'the_judge': 'king', 'ace_of_coins': 'legend',
        'ace_of_wands': 'legend', 'ace_of_cups': 'legend', 'ace_of_swords': 'legend', 'midas_scales': 'legend',
        'ash_flood_king': 'legend', 'skin_hell_executioner': 'knight', 'skin_frost_king': 'king',
        'skin_star_judge': 'king', 'skin_sun_midas': 'king'}


def set_section(fid, name, pivot, rows, palette):
    path = ROOT / 'art' / f'{fid}.txt'
    text = path.read_text()
    text = re.sub(r'\[' + name + r' [^\]]*\]\n(?:[^\[\n][^\n]*\n)*', '', text)
    for k, v in palette.items():
        if not re.search(rf'^{re.escape(k)} = ', text, re.M):
            text = text.replace('[palette]\n', f'[palette]\n{k} = {v}\n', 1)
    text = text.rstrip('\n') + f'\n[{name} pivot={pivot[0]},{pivot[1]}]\n' + '\n'.join(rows) + '\n'
    path.write_text(text)


def arm(length, sleeve, hand, cuff=None, mark=None, back=False):
    """sleeve/hand: 3 letters light, mid, dark. A 4-wide arm, hand in the last 4 rows."""
    s = sleeve if not back else sleeve[1] + sleeve[2] + sleeve[2]
    h = hand if not back else hand[1] + hand[2] + hand[2]
    rows = []
    for y in range(length):
        if y >= length - 4:
            rows.append(h[0] + h[1] + h[1] + h[2] if y < length - 1 else '.' + h[1] + h[2] + '.')
        else:
            rows.append(s[0] + s[1] + s[1] + s[2])
    if cuff:
        rows[length - 5] = cuff * 4
    if mark and not back:
        for (y, x, ch) in mark:
            r = list(rows[y]); r[x] = ch; rows[y] = ''.join(r)
    return rows


def leg(length, width, pants, boot, trim=None, mark=None, back=False):
    p = pants if not back else pants[1] + pants[2] + pants[2]
    b = boot if not back else boot[1] + boot[2] + boot[2]
    rows = []
    for y in range(length - 1):
        if y >= length - 6:
            rows.append(b[0] + b[1] * (width - 2) + b[2] + ('..' if y < length - 3 else b[1] + b[2]))
        else:
            rows.append(p[0] + p[1] * (width - 2) + p[2] + '..')
    if trim:
        rows[length - 7] = trim * width + '..'
    if mark and not back:
        for (y, x, ch) in mark:
            r = list(rows[y]); r[x] = ch; rows[y] = ''.join(r)
    return rows


def limbs(fid, sleeve, hand, pants, boot, palette, cuff=None, trim=None, arm_mark=None, leg_mark=None,
          hand_front=None):
    alen, lw, llen = LIMBS[RANK[fid]]
    set_section(fid, 'armF', (2, 1), arm(alen, sleeve, hand_front or hand, cuff, arm_mark), palette)
    set_section(fid, 'armB', (2, 1), arm(alen, sleeve, hand, cuff, None, back=True), palette)
    set_section(fid, 'legF', (lw // 2, 0), leg(llen, lw, pants, boot, trim, leg_mark), palette)
    set_section(fid, 'legB', (lw // 2, 0), leg(llen, lw, pants, boot, trim, None, back=True), palette)


SKIN = 'lms'
LEATHER = {'N': '94683f', 'n': '704a2e', 'b': '4a2e1c', 'q': '24160e'}
# --- Court figures -------------------------------------------------------------------
limbs('coin_squire', 'Nnb', SKIN, 'nbq', 'nbq', LEATHER, cuff='b')
limbs('golden_scales', 'Eef', SKIN, 'eff', 'GcA', {'e': '1e3c26', 'E': '3a6a3e', 'f': '0e1e14', 'A': '4a2a08'}, cuff='G')
limbs('king_midas', 'SRr', SKIN, 'Rrq', 'cGa', {}, cuff='F', hand_front='TGc', trim='G')
limbs('spark_bearer', 'Nnb', SKIN, 'nbq', 'nbq', {**LEATHER, 'o': 'ff9a20'}, cuff='b', arm_mark=[(3, 1, 'q'), (6, 2, 'q')])
limbs('enraged_one', SKIN, SKIN, 'nbq', 'nbq', {**LEATHER, 'f': 'e04010', 'F': 'ff9a20'}, cuff='b',
      arm_mark=[(2, 1, 'f'), (3, 2, 'F'), (4, 1, 'f'), (5, 2, 'f')], trim='b')
limbs('mistress_of_embers', 'Rrq', SKIN, 'rqq', 'GcA', {'r': '6a1620', 'R': 'a02a30', 'q': '3a0c10', 'A': '4a2a08', 'o': 'ffa030'}, cuff='o')
limbs('ash_king', 'ABa', 'ABa', 'ABa', 'Bak', {'A': '5a525a', 'B': '3a3438', 'a': '24202a', 'o': 'ffa030'}, cuff='o',
      trim='o', arm_mark=[(5, 1, 'o')], leg_mark=[(6, 1, 'o')])
limbs('altar_server', 'Vvw', SKIN, 'vww', 'nbq', {'v': 'b0a890', 'V': 'f0e8d0', 'w': '6a6458', **LEATHER}, cuff='V')
limbs('blood_drinker', 'ABa', 'lms', 'Bak', 'Bak', {'A': '4a4048', 'B': '2e282e', 'a': '1a161c', 'R': 'a01828',
      'l': 'eee6ea', 'm': 'c8bcc2', 's': '8c7e86'}, cuff='R', trim='R')
limbs('chalice_of_return', 'Uup', SKIN, 'upp', 'GcA', {'u': '1a3458', 'U': '2c5288', 'p': '0c1a2e', 'A': '4a2a08', 'V': 'f0f8ff'}, cuff='V')
limbs('drowned_king', 'QSz', 'lms', 'Szz', 'Szz', {'S': '1e4a5a', 'Q': '3a7a86', 'z': '0e2a34', 'P': '3a7a3e',
      'l': 'c4e4da', 'm': '8ab8ac', 's': '3a6a66'}, cuff='P', arm_mark=[(3, 1, 'P'), (7, 2, 'P')], trim='P')
limbs('blade_apprentice', 'Nnb', SKIN, 'nbq', 'nbq', {**LEATHER, 'v': 'a65ae0', 'W': 'd8e0ea'}, cuff='v', arm_mark=[(5, 3, 'W'), (6, 3, 'W')])
limbs('executioner', SKIN, SKIN, 'nbq', 'nbq', {**LEATHER, 'i': '4c5462'}, cuff='b', trim='i')
limbs('clear_blade', 'ZYx', 'WWI', 'ZYx', 'Yxx', {'Z': 'e2ecff', 'Y': '9db0d0', 'x': '5a6c8c', 'V': 'c080ff'}, cuff='V', trim='V')
limbs('the_judge', 'Jjz', SKIN, 'jzz', 'jzz', {'j': '1c1820', 'J': '302a36', 'z': '0a080c', 'Z': 'e2dcd2'}, cuff='Z', trim='G')

# --- Aces (spirits, glowing trims) and secret recipes: torso + limbs --------------------
make('ace_of_coins', 'king', 'robe', {'L': 'S', 'M': 'R', 'D': 'r', 'X': 'q'}, [
    (6, 1, ['GTTG', 'GeeG', 'GTTG']), (0, 17, ['TTTTTTTTTTTTTTTTT']), (8, 22, ['T', 'T', 'T', 'T', 'T', 'T', 'T', 'T', 'T', 'T', 'T', 'T'])],
    {'q': '5a3608', 'r': '8a5a12', 'R': 'c08a20', 'S': 'f0c850', 'e': '28b060'})
limbs('ace_of_coins', 'SRr', 'lms', 'Rrq', 'cGa', {'l': 'fff8d0', 'm': 'f0d070', 's': 'c89a30'}, cuff='T', hand_front='TGc')
make('ace_of_wands', 'king', 'plate', {'L': 'T', 'M': 'G', 'D': 'c', 'X': 'a'}, [
    (2, 3, ['ccccccccccccccc', '               ', 'ccccccccccccccc']), (6, 6, ['ffFff', ' fyf ', '  F  ']),
    (1, 16, ['FFFFFFFFFFFFFFFF'])], {'F': 'ff9a20', 'f': 'e04010', 'y': 'fff0a0'})
limbs('ace_of_wands', 'TGc', 'lms', 'Gca', 'caa', {'l': 'ffd060', 'm': 'f07a20', 's': 'b03a10', 'F': 'ff9a20'}, cuff='F', trim='F')
make('ace_of_cups', 'king', 'gown', {'L': 'U', 'M': 'u', 'D': 'p', 'X': 'p'}, [
    (4, 0, ['VVVVVVVVV', ' VVVVVVV ']), (6, 5, ['GGGGG', ' GwG ', '  G  ', ' GGG ']), (0, 17, ['VVVVVVVVVVVVVVVVV']),
    (3, 25, ['y    y', '  y    y'])], {'u': '1a3458', 'U': '2c5288', 'p': '0c1a2e', 'V': 'f0f8ff', 'w': '7ac8e8', 'y': '7ac8e8'})
limbs('ace_of_cups', 'Uup', 'lms', 'upp', 'VVu', {'l': 'd0ecff', 'm': '7aaae0', 's': '3a6aa8'}, cuff='V')
make('ace_of_swords', 'king', 'plate', {'L': 'Z', 'M': 'Y', 'D': 'x', 'X': 'k'}, [
    (2, 2, ['WWWWWWWWWWWWW', '             ', '  Y       Y  ', '             ', 'WWWWWWWWWWWWW']),
    (7, 7, ['eEe', ' e ', ' e ']), (1, 16, ['eeeeeeeeeeeeeeee'])],
    {'Z': 'e2ecff', 'Y': '9db0d0', 'x': '5a6c8c', 'e': 'a65ae0', 'E': 'd8b0ff'})
limbs('ace_of_swords', 'ZYx', 'WWI', 'ZYx', 'Yxx', {'Z': 'e2ecff', 'Y': '9db0d0', 'x': '5a6c8c', 'e': 'a65ae0'}, cuff='e', trim='e')
make('midas_scales', 'king', 'robe', {'L': 'S', 'M': 'R', 'D': 'r', 'X': 'q'}, [
    (2, 0, ['FFFFFFFFFFFFFFF', 'FkFFFkFFFkFFFkF']), (4, 4, ['G         G', 'GG       GG', ' cG     Gc ', '  cGGeGGc  ']),
    (8, 9, ['T', 'T', 'T']), (0, 17, ['ccccccccccccccccc']), (0, 18, ['aaaaaaaaaaaaaaaaa']), (0, 34, ['TTTTTTTTTTTTTTTTTTT'])],
    {'q': '5a3608', 'r': '8a5a12', 'R': 'c08a20', 'S': 'f0c850', 'F': 'f6f0e6', 'k': '202024', 'e': '28b060'})
limbs('midas_scales', 'SRr', SKIN, 'Rrq', 'cGa', {}, cuff='F', hand_front='TGc', trim='T')
make('ash_flood_king', 'king', 'plate', {'L': 'A', 'M': 'B', 'D': 'a', 'X': 'k'}, [
    (2, 3, ['BBBBBBBBBBBBBBB', '               ', 'BBBBBBBBBBBBBBB']), (7, 5, ['kkkkk', 'koyok', 'kkokk']),
    (3, 9, ['o', ' P', '  P']), (12, 10, ['P', 'yP']), (1, 16, ['PPPPPPPPPPPPPPPP'])],
    {'A': '5a525a', 'B': '3a3438', 'a': '24202a', 'o': 'ffa030', 'y': '7ac8e8', 'P': '3a7a3e'})
limbs('ash_flood_king', 'ABa', 'lms', 'ABa', 'Bak', {'A': '5a525a', 'B': '3a3438', 'a': '24202a', 'P': '3a7a3e',
      'l': 'c4e4da', 'm': '8ab8ac', 's': '3a6a66'}, cuff='P', trim='P', arm_mark=[(4, 1, 'P')])

# --- Legendary skins: full bodies -----------------------------------------------------
make('skin_hell_executioner', 'knight', 'bare', {'L': 'H', 'M': 'h', 'D': 'k', 'X': 'k'}, [
    (6, 1, ['O', ' o', 'o', ' oO', '  o', ' o', 'o']), (2, 4, ['o', ' O', '  o']), (12, 6, ['o', 'O', ' o']),
    (1, 12, ['bbbbbbbbbbbbbbbb']), (7, 12, ['oOo']), (2, 13, ['BBBBBBBBBBBBBB', 'BBBBBBoBBBBBBB', 'BBBBBBBBoBBBBB', ' BBBBBBBBBBBB '])],
    {'b': '24160e', 'B': '3a2414'})
limbs('skin_hell_executioner', 'Hhk', 'Hhk', 'Bbk', 'kkk', {'b': '24160e', 'B': '3a2414'}, cuff='O',
      arm_mark=[(2, 1, 'o'), (3, 2, 'O'), (5, 1, 'o'), (7, 2, 'o')], trim='o', leg_mark=[(3, 1, 'o'), (6, 2, 'o')])
make('skin_frost_king', 'king', 'robe', {'L': 'B', 'M': 'I', 'D': 'i', 'X': 'd'}, [
    (2, 0, ['WWWWWWWWWWWWWWW', ' W W W W W W W ']), (8, 3, ['w', 'WIW', 'w']), (3, 8, ['W', ' w']), (13, 11, ['w', 'W']),
    (1, 17, ['wwwwwwwwwwwwwwwww']), (4, 24, ['W', 'W', 'w']), (12, 27, ['W', 'w']), (0, 34, ['WwWwWwWwWwWwWwWwWwW'])],
    {'i': '2a5a8a', 'I': '6aa8d8', 'B': 'b8e4ff', 'W': 'ffffff', 'w': 'dcefff', 'd': '1c2e4a'})
limbs('skin_frost_king', 'BIi', 'lms', 'Iid', 'Wwi', {'i': '2a5a8a', 'I': '6aa8d8', 'B': 'b8e4ff', 'W': 'ffffff', 'w': 'dcefff', 'd': '1c2e4a'},
      cuff='W', trim='W', arm_mark=[(4, 1, 'W'), (8, 2, 'w')])
make('skin_star_judge', 'king', 'robe', {'L': 'V', 'M': 'v', 'D': 'N', 'X': 'n'}, [
    (3, 0, ['ppppppppppppp']), (2, 4, ['w', '   E', '      w', ' p', '        E', '   w']), (7, 6, ['eEe', 'EwE', 'eEe']),
    (1, 17, ['eeeeeeeeeeeeeeeee']), (3, 22, ['w     E', '   p', 'E      w', '     w', '  E']), (0, 34, ['epepepepepepepepepe'])],
    {'n': '06040c', 'N': '120c22', 'v': '221838', 'V': '3a2c5a', 'e': 'c080ff', 'E': 'f0e0ff', 'w': 'e0d0ff', 'p': '9a70e0'})
limbs('skin_star_judge', 'VvN', 'VvN', 'vNn', 'Nnn', {'n': '06040c', 'N': '120c22', 'v': '221838', 'V': '3a2c5a', 'e': 'c080ff', 'w': 'e0d0ff'},
      cuff='e', trim='e', arm_mark=[(3, 1, 'w'), (7, 2, 'w')])
make('skin_sun_midas', 'king', 'plate', {'L': 'S', 'M': 'R', 'D': 'q', 'X': 'a'}, [
    (2, 2, ['TTTTTTTTTTTTT', '             ', '  R       R  ', '             ', 'TTTTTTTTTTTTT']), (6, 7, ['GTTTG', 'TTuTT', 'GTTTG']),
    (1, 16, ['ccccccccccccccc']), (7, 16, ['GeG'])], {'q': '7a5410', 'R': 'd8a830', 'S': 'ffe070', 'u': 'ff6030', 'e': '28b060'})
limbs('skin_sun_midas', 'SRq', SKIN, 'SRq', 'Rqa', {'q': '7a5410', 'R': 'd8a830', 'S': 'ffe070'}, cuff='T', trim='T', hand_front='TSR')
print('limbs written')
