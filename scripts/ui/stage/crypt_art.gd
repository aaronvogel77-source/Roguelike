class_name CryptArt
extends RefCounted
## The crypt, painted in pixels with light: the battle background "Schatzgewölbe"
## (stage_vault) and the Krypta-Lager room of the vault screen.
## Every surface gets an unlit colour first; then moonlight from a high window
## (top left), torches and candles add light in hard steps (pixel art, no
## dither), a shaft of light, floor mist and a vignette. Effects (flames,
## glass, gold glints) are self-lit and keep their bright colours.

const GOLD := ["4a3208", "9a6a14", "d9a530", "ffe08a"]

static var _cache := {}

var w := 0
var h := 0
var fy := 0
var _base: Image
var _emit: Image
var _lights: Array = []  # [x, y, radius, Color, strength, vertical squash]
var _shafts: Array = []  # each [x, y, slope, width, Color, strength]
## Mist bands: [centre y, half height, strength]; the default lies along the wall foot.
var _mists: Array = []


func _init(width: int, height: int, floor_y: int) -> void:
	w = width
	h = height
	fy = floor_y
	_base = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_base.fill(Color("0d0a0c"))
	_emit = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_mists = [[fy - 3, 10.0, 0.10]]


# --- Public -----------------------------------------------------------------------------

## The battle background: brick vault, three deep arches with gold, pillars
## with torch brackets (the stage draws the flickering flames), wall niches,
## chains, a moonlit window top left and a flagstone floor in perspective.
static func stage(width: int, height: int, floor_y: int) -> ImageTexture:
	var key := "stage/%d/%d/%d" % [width, height, floor_y]
	if not _cache.has(key):
		var r := CryptArt.new(width, height, floor_y)
		r._paint_stage()
		_cache[key] = ImageTexture.create_from_image(r._render(0.5))
	return _cache[key]


## The Krypta-Lager room (vault screen), 180 px high and as wide as the screen
## needs: chests left, the altar in a deep arch in the middle, two portraits,
## the mirror right. station_rects() gives where each station is.
static func room(width: int, height := 180) -> ImageTexture:
	var key := "room/%d/%d" % [width, height]
	if not _cache.has(key):
		var r := CryptArt.new(width, height, room_floor(height))
		r._paint_room()
		_cache[key] = ImageTexture.create_from_image(r._render(0.6))
	return _cache[key]


static func room_floor(height: int) -> int:
	return int(height * 0.733)


## Tappable areas of the four stations in room pixels.
static func station_rects(width: int, height := 180) -> Dictionary:
	var floor_y := room_floor(height)
	var ax := width / 2
	var mirror := _mirror_x(width)
	var frame_y := 30
	return {
		"chests": Rect2(8, floor_y - 22, 72, 30),
		"altar": Rect2(ax - 26, floor_y - 46, 52, 48),
		"portraits": Rect2(_portrait_x(width, 0) - 3, frame_y - 3, _portrait_x(width, 1) - _portrait_x(width, 0) + 28, 34),
		"mirror": Rect2(mirror - 16, floor_y - 74, 32, 76),
	}


static func _portrait_x(width: int, index: int) -> int:
	return width / 2 - 50 if index == 0 else width / 2 + 28


static func _mirror_x(width: int) -> int:
	return width - 52


# --- Painting primitives ------------------------------------------------------------------

func put(color: Color, x: int, y: int, rw := 1, rh := 1, emit := false) -> void:
	var rect := Rect2i(x, y, rw, rh).intersection(Rect2i(0, 0, w, h))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	(_emit if emit else _base).fill_rect(rect, color)
	if not emit:  # a solid thing in front of glass or moon hides it
		_emit.fill_rect(rect, Color(0, 0, 0, 0))


func light(x: float, y: float, radius: float, color: Color, strength: float, squash := 1.0) -> void:
	_lights.append([x, y, radius, color, strength, squash])


func _render(vignette: float) -> Image:
	# Sum the stepped light of all lamps (only inside their reach).
	var lit := PackedVector3Array()
	lit.resize(w * h)
	for l in _lights:
		var lx: float = l[0]
		var ly: float = l[1]
		var radius: float = l[2]
		var c: Color = l[3]
		var k: float = l[4]
		var squash: float = l[5]
		for y in range(maxi(0, int(ly - radius / squash) - 1), mini(h, int(ly + radius / squash) + 2)):
			for x in range(maxi(0, int(lx - radius) - 1), mini(w, int(lx + radius) + 2)):
				var dx := x - lx
				var dy := (y - ly) * squash
				var d := sqrt(dx * dx + dy * dy) / radius
				if d >= 1.0:
					continue
				var f := (1.0 - d) * (1.0 - d) * k
				f = clampf(floorf(f * 6.0 + 0.35), 0.0, 6.0) / 6.0 * k  # six hard steps
				if f > 0.0:
					lit[y * w + x] += Vector3(c.r, c.g, c.b) * f
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mist := Vector3(120, 110, 140) / 255.0
	for y in h:
		for x in w:
			var e := _emit.get_pixel(x, y)
			if e.a > 0.0:
				out.set_pixel(x, y, Color(e.r, e.g, e.b))
				continue
			var b := _base.get_pixel(x, y)
			var base := Vector3(b.r, b.g, b.b)
			var amb := 0.55 + 0.25 * (1.0 - float(x) / w)  # cool ambient, darker to the right
			var l: Vector3 = lit[y * w + x]
			var acc := base * amb + base * l * 1.6 + l * 0.07
			acc.z += 3.0 / 255.0  # shadows lean violet
			for shaft in _shafts:
				acc += _shaft_light(shaft, x, y)
			for band in _mists:
				var reach: float = band[1]
				var off := absf(y - float(band[0]))
				if off < reach:
					var m: float = float(band[2]) * (1.0 - off / reach)
					m = floorf(m * 40.0) / 40.0  # mist in steps, too
					acc = acc * (1.0 - m) + mist * m * 0.5
			# Vignette in eighth steps.
			var vx := (x - w * 0.45) / (w * 0.62)
			var vy := (y - h * 0.42) / (h * 0.75)
			var vd := vx * vx + vy * vy
			if vd > 0.55:
				var q := roundf(minf(vignette, (vd - 0.55) * vignette * 1.3) * 8.0) / 8.0
				acc = Vector3(acc.x * (1.0 - q), acc.y * (1.0 - q), acc.z * (1.0 - q) * 0.95 + 4.0 / 255.0 * q)
			out.set_pixel(x, y, Color(minf(acc.x, 1.0), minf(acc.y, 1.0), minf(acc.z, 1.0)))
	return out


## A shaft of light from a window: two solid bands, fading towards the floor.
func _shaft_light(_shaft: Array, x: int, y: int) -> Vector3:
	var sx: float = _shaft[0]
	var sy: float = _shaft[1]
	var t := y - sy
	if t <= 0.0:
		return Vector3.ZERO
	var width: float = _shaft[3] * (1.0 + t / 120.0)
	var off := absf(x - (sx + t * float(_shaft[2])))
	if off >= width:
		return Vector3.ZERO
	var f: float = _shaft[5] * (1.0 - off / width) * maxf(0.0, 1.0 - t / (fy - sy))
	var band := 0.10 if f > 0.22 else (0.05 if f > 0.08 else 0.0)
	var c: Color = _shaft[4]
	return Vector3(c.r, c.g, c.b) * band


# --- Parts --------------------------------------------------------------------------------

func _bricks(y0: int, y1: int) -> void:
	var tones := [Color("2a2026"), Color("30252b"), Color("261d22"), Color("342830"), Color("2c2228")]
	var mortar := Color("120d10")
	for y in range(y0, y1):
		var row := (y - y0) / 6
		var off := 6 if row % 2 else 0
		var in_row := (y - y0) % 6
		for x in w:
			if in_row == 0 or (x + off) % 12 == 0:
				put(mortar, x, y)
				continue
			var t: Color = tones[absi(((x + off) / 12) * 7 + row * 13) % 5]
			if in_row == 1:  # each brick lit on its top edge
				t = t.lerp(Color("4a3a40"), 0.35)
			elif in_row == 5 or (x + off) % 12 == 11:
				t = t.lerp(Color("140e14"), 0.4)
			put(t, x, y)
	for i in 18:  # a few worn bricks
		put(Color("1a1318"), (i * 53) % w, y0 + ((i * 29) % maxi(1, (y1 - y0) / 6)) * 6 + 1, 4, 2)


func _ceiling(rows: int) -> void:
	for y in rows:
		put(Color("120d10").lerp(Color("231a1e"), float(y) / rows), 0, y, w, 1)
	for x in range(0, w, 50):  # vault ribs
		for i in 10:
			put(Color("3a2e30"), x + i * 2, rows - 1 - i / 2, 2, 1)


## A deep arch: each level smaller and darker, with a far candle at its end.
func _arch(cx: int, half: int, height: int, levels: int) -> void:
	var shades := [Color("0e0a0e"), Color("0b080b"), Color("080608"), Color("050405")]
	for lvl in levels + 1:
		var hh := half - lvl * 4
		var top := fy - height + lvl * 6
		for y in range(top, fy - lvl * 2):
			var dy := y - top
			var hw := hh if dy >= hh else int(sqrt(maxf(0.0, hh * hh - (hh - dy) * (hh - dy))))
			put(shades[mini(lvl, 3)], cx - hw, y, hw * 2, 1)
		if lvl < levels:
			var dim := 0.35 * lvl
			for i in 48:
				var a := PI + i / 48.0 * PI
				var col := Color("5a4844") if a < PI * 1.5 else Color("3a2e30")  # lit from the left
				put(col.lerp(Color("0b080b"), dim), roundi(cx + cos(a) * (hh + 1)), roundi(top + hh + sin(a) * (hh + 1)))
			put(Color("4a3c3e").lerp(Color("0b080b"), dim), cx - hh - 1, top + hh, 1, fy - lvl * 2 - top - hh)
			put(Color("2a2024").lerp(Color("0b080b"), dim), cx + hh, top + hh, 1, fy - lvl * 2 - top - hh)
	var y := fy - levels * 2 - 3
	put(Color("ffe08a"), cx, y - 2, 1, 1, true)
	put(Color("ff9030"), cx, y - 1, 1, 1, true)
	put(Color("d8c8a8"), cx, y, 1, 2)
	light(cx, y - 2, 14, Color("ff9a40"), 0.7)


func _pillar(x: int, y0: int, y1: int, pw := 10) -> void:
	for y in range(y0, y1):
		put(Color("2e2428"), x, y, pw, 1)
		put(Color("4e4044"), x, y, 2, 1)
		put(Color("3a2e32"), x + 2, y, 1, 1)
		put(Color("1a1216"), x + pw - 2, y, 2, 1)
		if (y - y0) % 14 == 0:
			put(Color("1a1216"), x, y, pw, 1)
	for step in [[y0, 2], [y0 + 1, 1], [y1 - 3, 1], [y1 - 2, 2], [y1 - 1, 2]]:
		var yy: int = step[0]
		var ext: int = step[1]
		put(Color("3e3236"), x - ext, yy, pw + ext * 2, 1)
		put(Color("5a4a4c"), x - ext, yy, 2, 1)
		put(Color("1a1216"), x + pw + ext - 1, yy, 1, 1)


## An iron bracket; with flame=true it burns here, else the stage draws the flame.
func _sconce(x: int, y: int, flame: bool) -> void:
	put(Color("2a2224"), x - 1, y + 2, 3, 1)
	put(Color("3e3438"), x, y + 1, 1, 4)
	put(Color("1a1418"), x - 2, y + 2, 1, 2)
	put(Color("1a1418"), x + 2, y + 2, 1, 2)
	if flame:
		put(Color("fff0a0"), x, y - 1, 1, 2, true)
		put(Color("ffb040"), x, y - 2, 1, 1, true)
		put(Color("ff8020"), x - 1, y - 1, 1, 1, true)
		put(Color("ffb040"), x + 1, y - 1, 1, 1, true)
		put(Color("e05010"), x, y - 3, 1, 1, true)
	light(x, y - 1 if flame else y - 8, 46, Color("ffa850"), 1.0, 1.15)


func _window(x: int, y: int, ww: int, wh: int) -> void:
	for yy in range(y, y + wh):
		var dy := yy - y
		var hw := ww / 2 if dy >= ww / 2 else int(sqrt(maxf(0.0, pow(ww / 2.0, 2) - pow(ww / 2.0 - dy, 2))))
		for xx in range(x + ww / 2 - hw, x + ww / 2 + hw):
			var c := Color("8ab0d8") if (xx + yy) % 5 else Color("b8d4f0")
			if xx == x + ww / 2 or ((yy - y) % 6 == 0 and dy > 3):
				c = Color("2a2834")  # lead came
			put(c.lerp(Color("3a5a90"), 0.25 * float(dy) / wh), xx, yy, 1, 1, true)
	put(Color("5a4a48"), x - 1, y + wh, ww + 2, 1)
	put(Color("2a2024"), x - 1, y + wh + 1, ww + 2, 1)


func _chain(x: int, length: int) -> void:
	for i in length:
		put(Color("4a4448") if i % 2 else Color("2a262c"), x, i)
		if i % 2 == 0:
			put(Color("5e585e"), x - 1 if (i / 2) % 2 else x + 1, i)


func _cobweb(x: int, y: int, s: int, flip: int) -> void:
	for i in s:
		put(Color("3a3640"), x + flip * i, y)
		put(Color("3a3640"), x, y + i)
		if i % 3 == 0 and i > 0:
			for j in i:
				put(Color("2e2a34"), x + flip * (i - j), y + j)


func _pile(cx: int, cy: int, rx: int, ry: int) -> void:
	for yy in range(-ry, 1):
		for xx in range(-rx, rx + 1):
			if float(xx * xx) / (rx * rx) + float(yy * yy) / (ry * ry) > 1.0:
				continue
			var v := -float(xx) / rx - float(yy) / ry
			put(Color(GOLD[3 if v > 0.9 else (2 if v > 0.1 else (1 if v > -0.6 else 0))]), cx + xx, cy + yy)
			if ((xx * 31 + yy * 17) & 15) == 0:
				put(Color("fff4b8"), cx + xx, cy + yy, 1, 1, true)
	light(cx, cy - ry, rx * 2.2, Color("ffd060"), 0.35)


func _chest(x: int, y: int, cw: int, ch: int, open: bool) -> void:
	for yy in ch:
		put(Color("5a3418") if yy > 2 else Color("6e4220"), x, y + yy, cw, 1)
	put(Color("8a5a2a"), x, y, cw, 1)
	put(Color("3a2010"), x, y + ch - 1, cw, 1)
	put(Color("2a1808"), x + cw - 1, y, 1, ch)
	for bx in [x + 2, x + cw - 4]:
		put(Color("4a4448"), bx, y, 2, ch)
		put(Color("7a747a"), bx, y, 1, 1)
	put(Color("d9a530"), x + cw / 2 - 1, y + 3, 2, 2)
	put(Color("ffe08a"), x + cw / 2 - 1, y + 3, 1, 1)
	if open:
		put(Color("3a2010"), x, y - 6, cw, 5)
		put(Color("6e4220"), x + 1, y - 5, cw - 2, 3)
		put(Color("8a5a2a"), x + 1, y - 5, cw - 2, 1)
		put(Color("ffe08a"), x + 2, y - 1, cw - 4, 1, true)
		light(x + cw / 2, y - 1, 22, Color("ffd060"), 0.8)


func _skull(x: int, y: int) -> void:
	var rows := [".###.", "#####", "#.#.#", "#####", ".#.#."]
	for j in rows.size():
		for i in 5:
			if rows[j][i] == "#":
				put(Color("a89a86") if i < 2 and j < 2 else (Color("6a6054") if i > 3 or j > 3 else Color("8a8070")), x + i, y + j)
	put(Color("1a1214"), x + 1, y + 2)
	put(Color("1a1214"), x + 3, y + 2)


func _urn(x: int, y: int) -> void:
	var rows := [[1, 3], [0, 5], [0, 5], [0, 5], [1, 3], [1, 3]]
	for j in rows.size():
		var o: int = rows[j][0]
		var uw: int = rows[j][1]
		for i in uw:
			put(Color("8a6a4a") if i == 0 else (Color("3a2a1c") if i == uw - 1 else Color("5a4630")), x + o + i, y + j)


## Flagstones in perspective: rows get taller towards the viewer, joints fan out.
func _floor() -> void:
	for y in range(fy, h):
		var t := float(y - fy) / maxf(1.0, h - fy)
		put(Color("2a2226").lerp(Color("161114"), t), 0, y, w, 1)
	var rows := [fy]
	var row_h := 3
	while rows[-1] < h:
		rows.append(rows[-1] + row_h)
		row_h += 2
	var vx := w * 0.5
	for r in rows.size() - 1:
		var y0: int = rows[r]
		var y1: int = rows[r + 1]
		put(Color("0e0a0c"), 0, y0, w, 1)
		put(Color("3e3236"), 0, y0 + 1, w, 1)  # lit top edge of each row
		var step := 14 + r * 6
		var off := step / 2 if r % 2 else 0
		for gx in range(-w, 2 * w, step):
			for y in range(y0 + 1, mini(y1, h)):
				var k := float(y - fy + 6) / (h - fy + 6)
				put(Color("0e0a0c"), roundi(vx + (gx + off - vx) * (0.7 + k * 0.6)), y)
	put(Color("4a3c40"), 0, fy, w, 1)  # wall foot
	put(Color("0a0709"), 0, fy + 1, w, 1)
	for i in 22:  # scattered coins
		var cx := (i * 97) % w
		var cy := fy + 5 + (i * 31) % maxi(1, h - fy - 8)
		put(Color(GOLD[2]), cx, cy, 2, 1)
		put(Color(GOLD[3]), cx, cy)


func _niche(x: int, y: int, skull: bool) -> void:
	put(Color("0c090b"), x, y, 9, 9)
	put(Color("4a3c3e"), x - 1, y + 9, 11, 1)
	if skull:
		_skull(x + 2, y + 3)
	else:
		_urn(x + 2, y + 3)


# --- Scenes -------------------------------------------------------------------------------

func _paint_stage() -> void:
	_floor()
	_bricks(0, fy)
	_ceiling(8)
	_window(22, 10, 9, 22)
	for ax in [int(w * 0.14), int(w * 0.5), int(w * 0.86)]:
		_arch(ax, 18, 70, 3)
	_pile(int(w * 0.14), fy, 13, 8)
	_pile(int(w * 0.5) + 2, fy, 15, 9)
	_pile(int(w * 0.86), fy, 12, 7)
	for px in [int(w * 0.31) - 5, int(w * 0.69) - 5]:
		_pillar(px, 6, fy)
	# Brackets under the candles the stage draws (battle_stage._draw_ambient).
	var candle_y := fy + 4 - 66
	_sconce(int(w * 0.31), candle_y + 6, false)
	_sconce(int(w * 0.69), candle_y + 6, false)
	for side in [12, w - 12]:
		put(Color("3e3438"), side - 3, fy - 15, 7, 1)
		put(Color("5a4a4c"), side - 3, fy - 15, 2, 1)
		light(side, fy - 25, 26, Color("ffa850"), 0.7)
	_niche(int(w * 0.31) + 12, 22, true)
	_niche(int(w * 0.69) - 21, 22, false)
	_chain(int(w * 0.40), 22)
	_chain(int(w * 0.60), 14)
	_cobweb(0, 0, 9, 1)
	_cobweb(w - 1, 0, 11, -1)
	_chest(int(w * 0.40) - 8, fy - 9, 16, 10, false)
	_pile(int(w * 0.3), fy + 2, 6, 3)
	_pile(int(w * 0.71), fy + 2, 7, 4)
	light(26, 22, 70, Color("8ab0e0"), 0.45, 0.9)  # moonlight, top left
	_shafts.append([30.0, 32.0, 0.9, 5.0, Color("a8c8f0"), 0.45])


func _paint_room() -> void:
	_floor()
	var ax := w / 2
	# A red runner leading to the altar, with a gold edge.
	for y in range(fy + 1, h):
		var t := float(y - fy) / (h - fy)
		var hw := int(12 + t * 26)
		put(Color("4a1420"), ax - hw, y, hw * 2, 1)
		put(Color("6a2030"), ax - hw, y, 2, 1)
		put(Color("2a0a12"), ax + hw - 2, y, 2, 1)
		put(Color(GOLD[1]), ax - hw + 3, y, 1, 1)
		put(Color(GOLD[0]), ax + hw - 4, y, 1, 1)
		if (y - fy) % 9 == 4:
			put(Color("5a1a28"), ax - hw + 5, y, hw * 2 - 10, 1)
	_bricks(0, fy)
	_ceiling(10)
	_window(30, 12, 11, 30)
	_arch(ax, 26, 100, 4)
	var left_pillar := ax - 70
	var right_pillar := ax + 58
	_pillar(left_pillar, 8, fy, 12)
	_pillar(right_pillar, 8, fy, 12)
	_sconce(left_pillar - 8, 64, true)
	_sconce(right_pillar + 24, 64, true)
	# Chests (left): an open chest full of gold, a small one, coins spilling out.
	_chest(30, fy - 12, 22, 12, true)
	_chest(60, fy - 8, 14, 8, false)
	_pile(46, fy + 4, 24, 7)
	_pile(14, fy + 3, 9, 4)
	# Altar (middle): stone slab, red cloth, candles, a hovering star.
	put(Color("4a3c40"), ax - 22, fy - 16, 44, 3)
	put(Color("6a5a5a"), ax - 22, fy - 16, 44, 1)
	put(Color("2a2024"), ax - 22, fy - 13, 44, 1)
	put(Color("3a2e32"), ax - 18, fy - 13, 36, 13)
	put(Color("54464a"), ax - 18, fy - 13, 2, 13)
	put(Color("1e161a"), ax + 16, fy - 13, 2, 13)
	put(Color("6a1a2a"), ax - 10, fy - 13, 20, 8)
	put(Color("8a2a3a"), ax - 10, fy - 13, 20, 1)
	put(Color("d9a530"), ax - 10, fy - 6, 20, 1)
	for candle in [[-19, 8], [-15, 5], [14, 6], [18, 9]]:
		var cx: int = ax + candle[0]
		var ch: int = candle[1]
		put(Color("d8c8a8"), cx, fy - 16 - ch, 2, ch)
		put(Color("f0e4c8"), cx, fy - 16 - ch, 1, ch)
		put(Color("ffe08a"), cx, fy - 18 - ch, 1, 2, true)
		put(Color("ff9030"), cx + 1, fy - 17 - ch, 1, 1, true)
		light(cx, fy - 18 - ch, 26, Color("ffb050"), 0.55)
	var star := Vector2i(ax, fy - 34)
	for k in range(-3, 4):
		put(Color("ffe08a"), star.x + k, star.y, 1, 1, true)
		put(Color("ffe08a"), star.x, star.y + k, 1, 1, true)
	put(Color("fff8d0"), star.x, star.y, 1, 1, true)
	put(Color("d9a530"), star.x - 1, star.y - 1, 1, 1, true)
	put(Color("d9a530"), star.x + 1, star.y + 1, 1, 1, true)
	light(star.x, star.y, 40, Color("ffd070"), 0.9)
	# Portraits: gilt frames with dark painted busts.
	for i in 2:
		var fx := _portrait_x(w, i)
		var fy2 := 30
		var fw := 22
		var fh := 28
		put(Color(GOLD[1]), fx - 2, fy2 - 2, fw + 4, fh + 4)
		put(Color(GOLD[2]), fx - 2, fy2 - 2, fw + 4, 1)
		put(Color(GOLD[2]), fx - 2, fy2 - 2, 1, fh + 4)
		put(Color(GOLD[0]), fx + fw + 1, fy2 - 2, 1, fh + 4)
		put(Color(GOLD[0]), fx - 2, fy2 + fh + 1, fw + 4, 1)
		for yy in fh:
			put(Color("3a2a1e").lerp(Color("1a1218"), float(yy) / fh), fx, fy2 + yy, fw, 1)
		var cloak := Color("2a1a2e") if i == 0 else Color("1a2a24")
		put(Color("3a2a3a"), fx + fw / 2 - 4, fy2 + 6, 8, 8)
		put(Color("b08a70"), fx + fw / 2 - 2, fy2 + 8, 4, 5)
		put(cloak, fx + fw / 2 - 8, fy2 + 15, 16, fh - 15)
		put(cloak.lightened(0.2), fx + fw / 2 - 8, fy2 + 15, 16, 1)
		put(Color("1a1214"), fx + fw / 2 - 1, fy2 + 10)
		put(Color("1a1214"), fx + fw / 2 + 1, fy2 + 10)
	# Mirror (right): tall oval in a silver frame, cold dim reflection.
	var mx := _mirror_x(w)
	var my := fy - 40
	var mrx := 13
	var mry := 30
	for yy in range(-mry - 2, mry + 3):
		for xx in range(-mrx - 2, mrx + 3):
			var d := pow(xx / (mrx + 1.5), 2) + pow(yy / (mry + 1.5), 2)
			if d > 1.0:
				continue
			if pow(float(xx) / mrx, 2) + pow(float(yy) / mry, 2) <= 1.0:
				var g := (xx + mrx) / (2.0 * mrx) * 0.5 + (yy + mry) / (2.0 * mry) * 0.5
				var c := Color("4a5a7a") if g < 0.3 else (Color("2e3a54") if g < 0.6 else Color("1e2438"))
				if yy < 0 and (xx - yy / 3) + mrx / 2 in [-3, -2]:
					c = Color("8aa0c0")  # one soft glint, top left
				if absi(xx) < 3 and yy > 4 and yy < 16:
					c = Color("3a3448")  # a faint reflected figure
				put(c, mx + xx, my + yy, 1, 1, true)
			else:
				put(Color("c0c0cc") if xx < 0 and yy < 0 else (Color("5a5a6c") if xx > 0 and yy > 0 else Color("8a8a9a")), mx + xx, my + yy)
	put(Color("6a6a7c"), mx - 4, my + mry + 2, 9, 2)
	put(Color("3a3a48"), mx - 1, my + mry + 4, 3, fy - (my + mry + 4))
	put(Color("6a6a7c"), mx - 6, fy - 2, 13, 2)
	light(mx, my, 30, Color("8ab0e0"), 0.3)
	# A shelf with relics above the mirror's side, chains, cobwebs, skulls.
	var shelf := mini(w - 94, mx - 42)
	put(Color("4a3020"), shelf, 46, 58, 2)
	put(Color("6a4a30"), shelf, 46, 58, 1)
	put(Color("2a1a10"), shelf, 48, 58, 1)
	for i in 5:
		var kx := shelf + 4 + i * 11
		if i % 2 == 0:
			_urn(kx, 40)
		else:
			put(Color("2a4a3a") if i == 1 else Color("3a2a5a"), kx, 38, 4, 8)
			put(Color("4a7a5a") if i == 1 else Color("5a4a8a"), kx, 38, 1, 8)
	put(Color("d8c8a8"), shelf + 56, 40, 2, 6)
	put(Color("ffe08a"), shelf + 56, 38, 1, 2, true)
	light(shelf + 56, 38, 22, Color("ffb050"), 0.5)
	_chain(ax - 32, 30)
	_chain(ax + 32, 22)
	_cobweb(0, 0, 12, 1)
	_cobweb(w - 1, 0, 14, -1)
	for sx in [ax - 64, ax + 50, ax + 66]:
		_skull(sx, fy - 5)
	light(36, 28, 90, Color("8ab0e0"), 0.5, 0.9)  # moonlight, top left
	_shafts.append([40.0, 42.0, 0.85, 7.0, Color("a8c8f0"), 0.5])


# --- Cathedral ----------------------------------------------------------------------------

## The ruined cathedral: stone blocks, a rose window whose coloured light falls
## across the nave, two lancet windows, columns with candle brackets, pointed
## vaults, an altar with candles, pews of shadow and a marble floor.
static func cathedral(width: int, height: int, floor_y: int) -> ImageTexture:
	var key := "cathedral/%d/%d/%d" % [width, height, floor_y]
	if not _cache.has(key):
		var r := CryptArt.new(width, height, floor_y)
		r._paint_cathedral()
		_cache[key] = ImageTexture.create_from_image(r._render(0.5))
	return _cache[key]


func _blocks(y0: int, y1: int) -> void:
	var tones := [Color("23212c"), Color("282634"), Color("1f1d27"), Color("2c2a37")]
	for y in range(y0, y1):
		var row := (y - y0) / 8
		var off := 8 if row % 2 else 0
		var in_row := (y - y0) % 8
		for x in w:
			if in_row == 0 or (x + off) % 16 == 0:
				put(Color("121118"), x, y)
				continue
			var t: Color = tones[absi(((x + off) / 16) * 5 + row * 11) % 4]
			if in_row == 1:
				t = t.lerp(Color("4a4656"), 0.3)
			elif in_row == 7 or (x + off) % 16 == 15:
				t = t.lerp(Color("0e0d14"), 0.4)
			put(t, x, y)


## Glass colours: ruby, sapphire, gold, emerald, amethyst.
const GLASS := [Color("b02a3a"), Color("2a5ab0"), Color("d8a838"), Color("2a8a4a"), Color("7a3ab0")]


func _rose(cx: int, cy: int, r: int) -> void:
	for y in range(-r - 3, r + 4):
		for x in range(-r - 3, r + 4):
			var d := sqrt(float(x * x + y * y))
			if d > r + 2.5:
				continue
			if d > r:  # stone ring, lit top left
				put(Color("5a5664") if x + y < 0 else Color("2e2c38"), cx + x, cy + y)
				continue
			var a := fposmod(atan2(y, x), TAU)
			var spoke := fposmod(a, TAU / 12.0)
			if d < 3.0:
				put(Color("ffe8a0"), cx + x, cy + y, 1, 1, true)
			elif spoke < 0.12 or absf(d - r * 0.55) < 0.6:
				put(Color("1a1822"), cx + x, cy + y, 1, 1, true)  # lead and tracery
			else:
				var cell := int(a / (TAU / 12.0)) + (1 if d > r * 0.55 else 0)
				var c: Color = GLASS[cell % GLASS.size()]
				if d > r * 0.55 and spoke < 0.26:
					c = c.lightened(0.25)  # light catches the leading edge
				put(c.darkened(0.3 if y > 0 else 0.2), cx + x, cy + y, 1, 1, true)


func _lancet(x: int, y: int, ww: int, wh: int, tint: int) -> void:
	for yy in range(y - 1, y + wh + 1):
		var dy := yy - y
		var hw := ww / 2 if dy >= ww / 2 else int(sqrt(maxf(0.0, pow(ww / 2.0, 2) - pow(ww / 2.0 - dy, 2))))
		put(Color("4a4656"), x + ww / 2 - hw - 1, yy, 1, 1)
		put(Color("1e1c26"), x + ww / 2 + hw, yy, 1, 1)
		for xx in range(x + ww / 2 - hw, x + ww / 2 + hw):
			var c: Color = GLASS[(tint + (yy - y) / 6) % GLASS.size()]
			if xx == x + ww / 2 or (yy - y) % 6 == 0:
				c = Color("1a1822")
			put(c.darkened(0.35), xx, yy, 1, 1, true)


func _column(x: int, y0: int, y1: int, cw: int) -> void:
	for y in range(y0, y1):
		put(Color("34323e"), x, y, cw, 1)
		put(Color("5a5664"), x, y, 2, 1)
		put(Color("44424e"), x + 2, y, 1, 1)
		put(Color("4a4656"), x + cw / 2, y, 1, 1)  # fluting
		put(Color("1a1822"), x + cw - 2, y, 2, 1)
	for step in [[y0, 2], [y0 + 1, 1], [y1 - 3, 1], [y1 - 2, 2], [y1 - 1, 2]]:
		put(Color("44424e"), x - step[1], step[0], cw + step[1] * 2, 1)
		put(Color("6a6676"), x - step[1], step[0], 2, 1)


func _pointed_vault(x0: int, x1: int, top: int, spring: int) -> void:
	# Two arcs meeting in a point: the rib of a gothic vault.
	var mid := (x0 + x1) / 2.0
	var half := (x1 - x0) / 2.0
	for i in 40:
		var t := i / 39.0
		var y := spring - (spring - top) * sin(t * PI / 2)
		put(Color("4a4656"), roundi(x0 + t * half), roundi(y), 2, 1)
		put(Color("2a2834"), roundi(x1 - t * half) - 1, roundi(y), 2, 1)


func _marble_floor() -> void:
	var rows := [fy]
	var row_h := 3
	while rows[-1] < h:
		rows.append(rows[-1] + row_h)
		row_h += 2
	var vx := w * 0.5
	for r in rows.size() - 1:
		var step := 14 + r * 6
		var off := step / 2 if r % 2 else 0
		for y in range(rows[r], mini(rows[r + 1], h)):
			var k := float(y - fy + 6) / (h - fy + 6)
			var spread := 0.7 + k * 0.6
			for x in w:
				var u := vx + (x - vx) / spread - off
				var cell := int(floorf(u / step)) + r
				var dark := posmod(cell, 2) == 0
				var c := Color("2a2832") if dark else Color("3a3844")
				c = c.lerp(Color("16141c"), float(y - fy) / (h - fy) * 0.5)
				if y == rows[r]:
					c = Color("121018")
				elif y == rows[r] + 1:
					c = c.lightened(0.12)
				put(c, x, y)
	put(Color("54505e"), 0, fy, w, 1)
	put(Color("0e0d14"), 0, fy + 1, w, 1)


func _paint_cathedral() -> void:
	_marble_floor()
	_blocks(0, fy)
	for y in 6:
		put(Color("0e0d14").lerp(Color("1e1c26"), y / 6.0), 0, y, w, 1)
	var cx := w / 2
	var left := int(w * 0.31) - 6
	var right := int(w * 0.69) - 6
	# Vault ribs between the columns, the rose window high in the middle.
	_pointed_vault(-20, left + 6, 4, 34)
	_pointed_vault(left + 6, right + 6, 2, 30)
	_pointed_vault(right + 6, w + 20, 4, 34)
	_rose(cx, 34, 18)
	_lancet(int(w * 0.13) - 4, 20, 9, 48, 1)
	_lancet(int(w * 0.87) - 4, 20, 9, 48, 3)
	# Coloured light from the rose window falls to the right across the nave,
	# moonlight from the left lancet (light from the top left).
	_shafts.append([cx - 9.0, 50.0, 0.45, 4.0, GLASS[0], 0.6])
	_shafts.append([cx - 1.0, 52.0, 0.5, 4.0, GLASS[2], 0.6])
	_shafts.append([cx + 7.0, 50.0, 0.55, 4.0, GLASS[1], 0.6])
	_shafts.append([int(w * 0.13) + 1.0, 68.0, 0.8, 4.0, Color("a8c8f0"), 0.4])
	light(cx, 34, 70, Color("c8a0e0"), 0.35, 0.9)
	light(int(w * 0.13), 40, 50, Color("8ab0e0"), 0.4, 0.8)
	light(int(w * 0.87), 40, 40, Color("8ab0e0"), 0.25, 0.8)
	_column(left, 26, fy, 12)
	_column(right, 26, fy, 12)
	# Brackets under the candles the stage draws (battle_stage._draw_ambient).
	var candle_y := fy + 4 - 66
	_sconce(int(w * 0.31), candle_y + 6, false)
	_sconce(int(w * 0.69), candle_y + 6, false)
	for side in [12, w - 12]:  # iron candle stands
		put(Color("2a2832"), side, fy - 15, 1, 15)
		put(Color("4a4656"), side - 3, fy - 15, 7, 1)
		put(Color("2a2832"), side - 2, fy - 1, 5, 1)
		light(side, fy - 25, 26, Color("ffa850"), 0.7)
	# Altar under the rose: steps, cloth, two tall candles.
	put(Color("3a3844"), cx - 26, fy - 3, 52, 3)
	put(Color("54505e"), cx - 26, fy - 3, 52, 1)
	put(Color("3a3844"), cx - 20, fy - 6, 40, 3)
	put(Color("54505e"), cx - 20, fy - 6, 40, 1)
	put(Color("44424e"), cx - 14, fy - 18, 28, 12)
	put(Color("5a5664"), cx - 14, fy - 18, 2, 12)
	put(Color("22202a"), cx + 12, fy - 18, 2, 12)
	put(Color("e8e0d0"), cx - 15, fy - 19, 30, 2)
	put(Color("7a1a2a"), cx - 5, fy - 17, 10, 9)
	put(Color("d9a530"), cx - 1, fy - 15, 2, 5)
	put(Color("d9a530"), cx - 3, fy - 13, 6, 1)
	for dx in [-11, 10]:
		put(Color("d8c8a8"), cx + dx, fy - 28, 2, 9)
		put(Color("f0e4c8"), cx + dx, fy - 28, 1, 9)
		put(Color("ffe08a"), cx + dx, fy - 30, 1, 2, true)
		put(Color("ff9030"), cx + dx + 1, fy - 29, 1, 1, true)
		light(cx + dx, fy - 30, 30, Color("ffb050"), 0.6)
	# Pews: dark wooden backs between the columns, in two rows.
	for row in 2:
		var py := fy - 10 + row * 4
		for seg in [[18, left - 4], [left + 16, cx - 30], [cx + 30, right - 4], [right + 16, w - 18]]:
			var x0: int = seg[0]
			var x1: int = seg[1]
			if x1 <= x0:
				continue
			put(Color("2a1a14") if row == 0 else Color("22140e"), x0, py, x1 - x0, 3)
			put(Color("4a3020"), x0, py, x1 - x0, 1)
			for px in range(x0, x1, 9):
				put(Color("1a0e08"), px, py, 1, 6)
	_cobweb(0, 0, 8, 1)
	_cobweb(w - 1, 0, 8, -1)
	# Fallen stones of the ruin.
	for rubble in [[34, 3], [41, 2], [258, 3], [251, 2], [118, 2]]:
		put(Color("3a3844"), rubble[0], fy - rubble[1], rubble[1] + 2, rubble[1])
		put(Color("54505e"), rubble[0], fy - rubble[1], rubble[1] + 2, 1)


# --- Graveyard ----------------------------------------------------------------------------

## The moonlit graveyard: night sky with the moon top left, hills and a far
## chapel in the mist, crooked tombstones and crosses in three depth layers,
## a dead tree, an iron fence, lanterns on posts and soft ground.
static func graveyard(width: int, height: int, floor_y: int) -> ImageTexture:
	var key := "graveyard/%d/%d/%d" % [width, height, floor_y]
	if not _cache.has(key):
		var r := CryptArt.new(width, height, floor_y)
		r._paint_graveyard()
		_cache[key] = ImageTexture.create_from_image(r._render(0.45))
	return _cache[key]


func _stone(x: int, base: int, sw: int, sh: int, fade: float, kind: int) -> void:
	var ramp := [Color("2e3036"), Color("4a4d55"), Color("6a6e78"), Color("8a8e98")]
	var fog := Color("2a3040")
	for i in 4:
		ramp[i] = ramp[i].lerp(fog, fade)
	var top := base - sh
	match kind:
		0:  # rounded headstone
			for y in range(top, base):
				var dy := y - top
				var r := sw / 2.0
				var half := r if dy >= r else sqrt(maxf(0.0, r * r - (r - dy) * (r - dy)))
				var x0 := roundi(x - half)
				var x1 := roundi(x + half)
				put(ramp[1], x0, y, x1 - x0, 1)
				put(ramp[2], x0, y, 1, 1)
				put(ramp[0], x1 - 1, y, 1, 1)
			put(ramp[3], x - 1, top, 2, 1)
			if sh > 8:
				put(ramp[0], x - 2, top + 4, 4, 1)  # inscription
				put(ramp[0], x - 1, top + 6, 3, 1)
		1:  # cross
			put(ramp[1], x - 1, top, 2, sh)
			put(ramp[2], x - 1, top, 1, sh)
			put(ramp[1], x - 4, top + 3, 8, 2)
			put(ramp[2], x - 4, top + 3, 8, 1)
			put(ramp[0], x + 1, top + 1, 1, sh - 1)
		_:  # slab, leaning
			for y in range(top, base):
				var lean := (base - y) / 5
				put(ramp[1], x - sw / 2 + lean, y, sw, 1)
				put(ramp[2], x - sw / 2 + lean, y, 1, 1)
				put(ramp[0], x + sw / 2 + lean - 1, y, 1, 1)
			put(ramp[3], x - sw / 2 + (sh / 5), top, sw - 1, 1)


func _paint_graveyard() -> void:
	# Sky: deep blue, lighter towards the horizon, in bands.
	var horizon := fy - 24
	for y in horizon:
		var t := float(y) / horizon
		var band := floorf(t * 8.0) / 8.0
		put(Color("0c1224").lerp(Color("2a3450"), band), 0, y, w, 1)
	for i in 46:
		var sx := (i * 89 + 13) % w
		var sy := (i * 37) % (horizon - 20)
		if sx < 80 and sy < 46:
			continue  # no stars in the moon's glow
		put(Color("d0d8f0") if i % 5 == 0 else Color("7a86a8"), sx, sy, 1, 1, true)
		if i % 11 == 0:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				put(Color("5a6688"), sx + d.x, sy + d.y, 1, 1, true)
	# The moon, top left, lit from its upper left.
	var mx := 48
	var my := 24
	for y in range(-11, 12):
		for x in range(-11, 12):
			var d := x * x + y * y
			if d > 121:
				continue
			var c := Color("f0ecd8") if x + y < -6 else (Color("d8d4c0") if d < 90 else Color("b0ac98"))
			put(c, mx + x, my + y, 1, 1, true)
	for crater in [[-4, -2, 2], [3, 4, 3], [5, -5, 1], [-2, 6, 1]]:
		put(Color("b8b4a0"), mx + crater[0], my + crater[1], crater[2], crater[2], true)
	light(mx, my, 70, Color("9ab0e0"), 0.45, 0.8)
	for streak in [[20, 30, 46], [60, 34, 30], [150, 18, 60], [230, 26, 40]]:  # thin clouds
		put(Color("1e2638"), streak[0], streak[1], streak[2], 2)
		put(Color("2a344c"), streak[0] + 3, streak[1] - 1, streak[2] - 8, 1)
	# Far hills with a chapel, pale in the mist.
	for x in w:
		var hill := int(14 + 6 * sin(x * 0.03) + 3 * sin(x * 0.09 + 1.0))
		put(Color("1a2230"), x, horizon - hill + 12, 1, hill + 12)
	var ch := int(w * 0.62)
	put(Color("161c28"), ch, horizon - 18, 14, 22)
	put(Color("161c28"), ch + 4, horizon - 30, 6, 12)
	put(Color("161c28"), ch + 6, horizon - 35, 2, 5)
	put(Color("161c28"), ch + 5, horizon - 33, 4, 1)
	put(Color("ffc060"), ch + 6, horizon - 10, 2, 3, true)  # a lit window far away
	light(ch + 7, horizon - 9, 10, Color("ffb050"), 0.4)
	_mists.append([horizon + 2, 9.0, 0.22])
	# Ground: dark earth with grass at the top.
	for y in range(horizon + 8, h):
		var t := float(y - horizon) / (h - horizon)
		put(Color("1e2420").lerp(Color("100e0c"), floorf(t * 6.0) / 6.0), 0, y, w, 1)
	for x in range(0, w, 3):
		put(Color("2a3a24"), x, horizon + 8 - (x * 7) % 3, 1, 2)
	# Back row of stones, small and misty; middle row; then the dead tree.
	for i in 9:
		_stone(14 + i * 34 + (i * 7) % 11, horizon + 12, 6, 7 + (i * 3) % 4, 0.55, i % 3)
	_mists.append([horizon + 13, 6.0, 0.14])
	for i in 7:
		var gx := 26 + i * 44 + (i * 13) % 15
		if absi(gx - int(w * 0.31)) < 8 or absi(gx - int(w * 0.69)) < 8:
			gx += 14
		_stone(gx, fy - 4, 9, 12 + (i * 5) % 6, 0.25, (i + 1) % 3)
	var tx := int(w * 0.16)
	for y in range(16, fy - 2):
		var tw := 6 if y > 80 else (5 if y > 56 else (4 if y > 36 else 3))
		var bend := roundi(sin(y * 0.08) * 1.5)  # a crooked trunk
		put(Color("141210"), tx - tw / 2 + bend, y, tw, 1)
		put(Color("3e3e4a"), tx - tw / 2 + bend, y, 1, 1)  # moonlit edge on the left
	for b in [[-1, 34, 16], [1, 40, 14], [-1, 52, 11], [1, 60, 9], [-1, 24, 8], [1, 22, 7]]:
		var dir: int = b[0]
		for i in int(b[2]):
			var bx := tx + dir * (2 + i)
			var by := int(b[1]) - i / 2 - (i * i) / 30
			put(Color("141210"), bx, by, 1, 2 if i < b[2] / 2 else 1)
			if i == b[2] / 2:  # a twig
				put(Color("141210"), bx + dir, by - 2, 1, 2)
	put(Color("141210"), tx - 6, fy - 3, 14, 2)  # roots
	put(Color("141210"), tx - 8, fy - 1, 4, 1)
	put(Color("141210"), tx + 5, fy - 1, 5, 1)
	# Iron fence along the back, broken in the middle.
	for x in range(0, w, 4):
		if x > w * 0.42 and x < w * 0.58:
			continue
		put(Color("16161c"), x, fy - 17, 1, 13)
		put(Color("2e2e38"), x, fy - 18, 1, 1)
	put(Color("16161c"), 0, fy - 14, int(w * 0.42), 1)
	put(Color("16161c"), int(w * 0.58), fy - 14, w - int(w * 0.58), 1)
	# Lantern posts: the stage draws the candle flames inside them.
	var candle_y := fy + 4 - 66
	for lx in [int(w * 0.31), int(w * 0.69)]:
		put(Color("1a1a20"), lx - 1, candle_y + 10, 2, fy - candle_y - 10)
		put(Color("3a3a44"), lx - 1, candle_y + 10, 1, fy - candle_y - 10)
		put(Color("2a2a32"), lx - 5, candle_y - 8, 11, 2)  # roof
		put(Color("4a4a56"), lx - 4, candle_y - 9, 9, 1)
		put(Color("2a2a32"), lx - 4, candle_y + 8, 9, 2)  # base
		put(Color("2a2a32"), lx - 4, candle_y - 6, 1, 14)
		put(Color("2a2a32"), lx + 4, candle_y - 6, 1, 14)
		put(Color("2a2a32"), lx - 1, candle_y - 11, 2, 2)  # ring
		light(lx, candle_y - 2, 30, Color("ffa850"), 0.7, 1.1)
	# Small grave stones under the low candles.
	for side in [12, w - 12]:
		put(Color("4a4d55"), side - 4, fy - 14, 9, 14)
		put(Color("6a6e78"), side - 4, fy - 14, 9, 1)
		put(Color("6a6e78"), side - 4, fy - 14, 1, 14)
		put(Color("2e3036"), side + 4, fy - 14, 1, 14)
		light(side, fy - 25, 24, Color("ffa850"), 0.6)
	# Front: mounds and soft ground mist.
	for m in [[60, 6], [150, 7], [236, 6]]:
		for xx in range(-m[1] * 2, m[1] * 2):
			var hh := int(m[1] * 0.5 * (1.0 - pow(xx / (m[1] * 2.0), 2)))
			put(Color("1e1a14"), m[0] + xx, fy + 3 - hh, 1, hh)
	_mists[0] = [fy - 2, 9.0, 0.16]
