"""Hand-detailed torsos for the court figures (pivots match FigureArt: hip, bottom centre).

Each torso starts from a shaded base shape (plate, robe, gown, leather, bare) and then gets
the figure's own details stamped on by hand. Writes/replaces the [torso] section of art/<id>.txt.
"""
import pathlib, re
ROOT = pathlib.Path(__file__).resolve().parents[2]
DIMS = {'page': (11, 13, 14), 'knight': (16, 16, 17), 'queen': (13, 17, 18), 'king': (17, 19, 20)}


def base(kind, tw, th, leg):
    """Rows of a torso in tone letters: 'L' light, 'M' mid, 'D' dark, 'X' deepest, '.' empty."""
    extra = leg - 4 if kind in ('robe', 'gown') else 0
    w = tw + 2
    rows = []
    for y in range(th + extra):
        q = y / th
        if kind in ('robe', 'gown') and y >= th:
            widen = 0 if kind == 'robe' else (y - th + 2) // 3
            width = tw + widen * 2
        else:
            width = tw - 2 if q < 0.12 else tw if q < 0.45 else tw - 2 if q < 0.7 else tw - 1
        width = min(width, w + 6)
        row = ''
        full = max(w, width)
        for x in range(full):
            off = x - (full - width) // 2
            if off < 0 or off >= width:
                row += '.'; continue
            u = off / max(1, width - 1)
            t = 'L' if u < 0.2 else 'X' if u > 0.88 else 'D' if u > 0.72 else 'M'
            if y == 0 and t == 'M': t = 'L'
            row += t
        rows.append(row)
    width_max = max(len(r) for r in rows)
    rows = [r.center(width_max, '.') for r in rows]
    return rows, th


def stamp(rows, x, y, art):
    rows = [list(r) for r in rows]
    for j, line in enumerate(art):
        for i, ch in enumerate(line):
            if ch != ' ' and 0 <= y + j < len(rows) and 0 <= x + i < len(rows[0]):
                rows[y + j][x + i] = ch
    return [''.join(r) for r in rows]


def recolor(rows, mapping):
    return [''.join(mapping.get(ch, ch) for ch in r) for r in rows]


def save(fid, rows, pivot_x, pivot_y, palette):
    path = ROOT / 'art' / f'{fid}.txt'
    text = path.read_text()
    text = re.sub(r'\[torso[^\]]*\]\n(?:[^\[\n][^\n]*\n)*', '', text)  # drop an old torso
    pal_lines = ''.join(f'{k} = {v}\n' for k, v in palette.items() if f'\n{k} = ' not in text)
    text = text.replace('[palette]\n', '[palette]\n' + pal_lines, 1)
    text = text.rstrip('\n') + f'\n[torso pivot={pivot_x},{pivot_y}]\n' + '\n'.join(rows) + '\n'
    path.write_text(text)


def make(fid, rank, kind, tones, details, palette):
    tw, th, leg = DIMS[rank]
    rows, hip = base(kind, tw, th, leg)
    rows = recolor(rows, tones)
    for (x, y, art) in details:
        rows = stamp(rows, x, y, art)
    save(fid, rows, len(rows[0]) // 2, hip, palette)


# Coins ---------------------------------------------------------------------------------
make('coin_squire', 'page', 'leather', {'L': 'N', 'M': 'n', 'D': 'b', 'X': 'b'}, [
    (2, 2, ['B', 'B', 'B', 'B', 'B']), (5, 4, ['e']),
    (0, 10, ['bbbbbbbbbbbbb']), (6, 10, ['I']),
    (0, 9, ['NN', 'NnN', 'NnnN', 'nGn'])],
    {'b': '24160e', 'B': '94683f', 'e': '2f8a3e'})
make('golden_scales', 'queen', 'gown', {'L': 'E', 'M': 'e', 'D': 'f', 'X': 'f'}, [
    (3, 0, ['cGGGGGGc', ' cGGGGc ', '  ceec  ']), (6, 7, ['GG', 'aa']),
    (4, 9, ['G    G', 'Ga  aG', ' a  a ']), (0, 16, ['ccccccccccccccc'])],
    {'e': '1e3c26', 'E': '3a6a3e', 'f': '0e1e14'})
# Wands ---------------------------------------------------------------------------------
make('spark_bearer', 'page', 'leather', {'L': 'N', 'M': 'n', 'D': 'b', 'X': 'b'}, [
    (2, 3, ['q', ' q', 'q ', ' q']), (7, 2, ['o', ' o']), (0, 10, ['bbbbbbbbbbbbb']), (5, 10, ['F'])],
    {'b': '24160e', 'q': '1a0a08', 'o': 'ff9a20', 'F': 'e04010'})
make('enraged_one', 'knight', 'bare', {'L': 'l', 'M': 'm', 'D': 's', 'X': 'd'}, [
    (6, 3, ['s  s', ' ss ']), (5, 7, ['ss ss', '     ', 'ss ss']), (3, 2, ['f', 'F', 'fF', ' F']),
    (12, 4, ['f', 'Ff', ' F']), (1, 12, ['bbbbbbbbbbbbbbbb']), (1, 13, ['nNNNNNNNNNNNNNNn']), (8, 12, ['iI'])],
    {'f': 'e04010', 'F': 'ff9a20', 'b': '24160e'})
make('mistress_of_embers', 'queen', 'gown', {'L': 'R', 'M': 'r', 'D': 'q', 'X': 'q'}, [
    (4, 0, ['cGGGGGc', ' cGeGc ', '  cGc  ']), (2, 10, ['o', ' F', '  o']), (10, 13, ['F', 'o']),
    (3, 20, ['o   F   o']), (0, 17, ['GGGGGGGGGGGGGGG']), (0, 31, ['FoFoFoFoFoFoFoFoFoF'])],
    {'r': '6a1620', 'R': 'a02a30', 'q': '3a0c10', 'o': 'ffa030', 'F': 'e04010', 'e': 'e04010'})
make('ash_king', 'king', 'plate', {'L': 'A', 'M': 'B', 'D': 'a', 'X': 'k'}, [
    (2, 3, ['BBBBBBBBBBBBBBB', '               ', 'BBBBBBBBBBBBBBB', '               ', 'BBBBBBBBBBBBBBB']),
    (7, 4, ['kkkkk', 'koook', 'kkekk', ' kok ']), (3, 9, ['o', ' o', '  e']), (13, 11, ['o', 'e']),
    (1, 16, ['cccccccccccccccc']), (8, 16, ['GeG'])],
    {'A': '5a525a', 'B': '3a3438', 'a': '24202a', 'o': 'ffa030', 'e': 'ff5020'})
# Cups ----------------------------------------------------------------------------------
make('altar_server', 'page', 'robe', {'L': 'V', 'M': 'v', 'D': 'w', 'X': 'w'}, [
    (5, 1, ['G', 'G', 'GGG', 'G', 'G']), (0, 10, ['nnnnnnnnnnnnn']), (2, 11, ['n', 'n', 'N']), (0, 21, ['GGGGGGGGGGGGG'])],
    {'v': 'b0a890', 'V': 'f0e8d0', 'w': '6a6458'})
make('blood_drinker', 'knight', 'plate', {'L': 'A', 'M': 'B', 'D': 'a', 'X': 'k'}, [
    (6, 1, ['RRRRR', ' RRR ', '  R  ']), (7, 5, ['rSr', 'rRr', 'rRr', ' r ']),
    (2, 4, ['BB', '  ', 'BB']), (12, 4, ['BB', '  ', 'BB']), (1, 13, ['rrrrrrrrrrrrrrrr'])],
    {'A': '4a4048', 'B': '2e282e', 'a': '1a161c', 'r': '5a0a12', 'R': 'a01828', 'S': 'e04a50'})
make('chalice_of_return', 'queen', 'gown', {'L': 'U', 'M': 'u', 'D': 'p', 'X': 'p'}, [
    (4, 0, ['VVVVVVV', ' VVVVV ']), (5, 6, ['GGGGG', ' GwG ', '  G  ', ' GGG ']),
    (0, 16, ['VVVVVVVVVVVVVVV']), (2, 24, ['y      y', '   y    ']), (0, 33, ['GGGGGGGGGGGGGGGGGGG'])],
    {'u': '1a3458', 'U': '2c5288', 'p': '0c1a2e', 'V': 'f0f8ff', 'w': '7ac8e8', 'y': '7ac8e8'})
make('drowned_king', 'king', 'robe', {'L': 'Q', 'M': 'S', 'D': 'z', 'X': 'z'}, [
    (2, 0, ['PPPPPPPPPPPPPPP', ' P  P  P  P  P ']), (8, 4, ['G', 'GyG', 'G']),
    (3, 8, ['b', ' b', 'b']), (13, 12, ['B', 'bB']), (1, 17, ['gggggggggggggggggg']),
    (4, 22, ['P', 'P', ' P', 'P']), (12, 26, ['P', ' P', 'P']), (6, 30, ['b  B']), (0, 34, ['yyyyyyyyyyyyyyyyyyy'])],
    {'S': '1e4a5a', 'Q': '3a7a86', 'z': '0e2a34', 'P': '3a7a3e', 'g': '1e4a2a', 'b': 'c8c0a8', 'B': 'e8e0d0', 'y': '7ac8e8'})
# Swords --------------------------------------------------------------------------------
make('blade_apprentice', 'page', 'leather', {'L': 'N', 'M': 'n', 'D': 'b', 'X': 'b'}, [
    (1, 1, ['I', ' I', '  I', '   I', '    I', '     I']), (0, 10, ['bbbbbbbbbbbbb']),
    (2, 10, ['W W W']), (8, 3, ['v'])],
    {'b': '24160e', 'v': 'a65ae0'})
make('clear_blade', 'queen', 'plate', {'L': 'Z', 'M': 'Y', 'D': 'x', 'X': 'x'}, [
    (2, 2, ['WWWWWWWWW', '         ', '  Y   Y  ', '         ', 'WWWWWWWWW']), (6, 7, ['vVv', ' v ']),
    (1, 12, ['bbbbbbbbbbbbb']), (6, 12, ['GG']), (3, 13, ['B', 'B', 'B'])],
    {'Z': 'e2ecff', 'Y': '9db0d0', 'x': '5a6c8c', 'v': '7a3aa0', 'V': 'c080ff', 'b': '342c4a', 'B': '54487a'})
make('the_judge', 'king', 'robe', {'L': 'J', 'M': 'j', 'D': 'z', 'X': 'z'}, [
    (3, 0, ['ZZZZZZZZZZZZ', ' ZZ      ZZ ']), (4, 2, ['G', ' G', '  G', '   G', '    GGG']), (13, 2, ['G', 'G', 'G', 'G']),
    (7, 6, ['cGGc', 'GTvG', 'cGGc']), (1, 17, ['ccccccccccccccccc']), (8, 18, ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'])],
    {'j': '1c1820', 'J': '302a36', 'z': '0a080c', 'Z': 'e2dcd2', 'v': 'a65ae0'})
print('torsos written')
