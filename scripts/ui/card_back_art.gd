class_name CardBackArt
extends RefCounted
## Pixel-art card backs: the worn back (vault mirror) gives velvet and metal,
## the suit family gives the ornament (coin pentacle, crossed wands, chalice,
## sword), the gems, the corner motifs and the velvet pattern. Light comes from
## the top left. Built once per back × suit × size and cached.
## Shown with nearest filtering at an integer scale (shop card 56×82 ×2).

const SUITS := ["coins", "wands", "cups", "swords"]
## Four-tone ramps (dark, mid, light, highlight) per worn back.
const BACKS := {
	"back_tarot": {"velvet": ["14061e", "220a32", "32124a", "46205e"], "metal": ["4a3208", "9a6a14", "d9a530", "ffe08a"]},
	"back_blood": {"velvet": ["1a0408", "2e0a12", "44121c", "5e1e28"], "metal": ["2a2a3a", "6a6a7c", "b0b0bc", "f0ecf0"]},
	"back_gold": {"velvet": ["1a1006", "2a1c0a", "3c2a10", "52401a"], "metal": ["5a3a08", "a8781a", "e8bc40", "fff0a8"]},
	## Soul pack and pacts (not a worn back): violet-black velvet, bone-silver metal.
	"back_soul": {"velvet": ["0a0612", "150b24", "20123a", "2e1c4e"], "metal": ["2a2632", "6e6a78", "bcb6c4", "f2eef6"]},
	## Equipment (forge) packs: soot-black leather, dark iron frame.
	"back_forge": {"velvet": ["0c0a0a", "181414", "231c1a", "302622"], "metal": ["1e2024", "4a4e58", "8a909c", "c8ccd4"]},
}
## Gem ramps of the suit families: coins green, wands red-orange, cups blue, swords violet.
const GEMS := {
	"coins": ["0a3a1e", "1e7a40", "3ab060", "a0f0b0"],
	"wands": ["4a1008", "a8301a", "e86a2a", "ffd080"],
	"cups": ["0a1e4a", "1a4ea0", "3a8ae0", "b0e0ff"],
	"swords": ["2a1048", "5a2a98", "9a62d8", "e0c8ff"],
	"soul": ["0e2440", "2a6aa0", "6ab8f0", "d0f4ff"],  # soul blue, for the soul pack and pacts
	"forge": ["4a1008", "a8401a", "f08a30", "ffe0a0"],  # ember, for equipment packs
}
const WOOD := ["2a1608", "5a3418", "8a5a2a", "b08050"]

static var _cache := {}

var _img: Image
var _w := 0
var _h := 0


## The card back texture (w × h art pixels) for a worn back and a suit.
## suit "soul" always gives the soul back (soul pack, pacts), "forge" the
## forge back (equipment packs).
static func texture(back: String, suit: String, w := 56, h := 82) -> ImageTexture:
	if suit == "soul":
		back = "back_soul"
	elif suit == "forge":
		back = "back_forge"
	if not BACKS.has(back):
		back = "back_tarot"
	if not GEMS.has(suit):
		suit = "coins"
	var key := "%s/%s/%d/%d" % [back, suit, w, h]
	if not _cache.has(key):
		var art := CardBackArt.new()
		_cache[key] = ImageTexture.create_from_image(art._paint(back, suit, w, h))
	return _cache[key]


## A control showing the back at a fixed size, pixel-sharp (nearest).
static func rect(back: String, suit: String, size: Vector2) -> TextureRect:
	var scale := maxf(1.0, floorf(minf(size.x / 56.0, size.y / 82.0)))
	var art_w := int(round(size.x / scale))
	var art_h := int(round(size.y / scale))
	var view := TextureRect.new()
	view.texture = texture(back, suit, art_w, art_h)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = size
	view.size = size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


static func _ramp(hexes: Array) -> Array:
	return hexes.map(func(hex: String) -> Color: return Color(hex))


func _px(c: Color, x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < _w and y < _h:
		_img.set_pixel(x, y, c)


## Fills a set of points (Vector2i keys) with a ramp, lit from the top left,
## plus an outline in the darkest tone.
func _bevel(points: Dictionary, ramp: Array, outline := true) -> void:
	for p in points:
		var tl := not points.has(p + Vector2i(-1, 0)) or not points.has(p + Vector2i(0, -1))
		var br := not points.has(p + Vector2i(1, 0)) or not points.has(p + Vector2i(0, 1))
		var tone: Color = ramp[3] if tl and not br else (ramp[1] if br and not tl else ramp[2])
		_px(tone, p.x, p.y)
	if outline:
		for p in points:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not points.has(p + d):
					_px(ramp[0], p.x + d.x, p.y + d.y)


static func _points(list: Array) -> Dictionary:
	var out := {}
	for p in list:
		out[p] = true
	return out


func _paint(back: String, suit: String, w: int, h: int) -> Image:
	_w = w
	_h = h
	_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var velvet := _ramp(BACKS[back]["velvet"])
	var metal := _ramp(BACKS[back]["metal"])
	var gem := _ramp(GEMS[suit])
	var cx := w / 2
	var cy := h / 2
	_lattice(velvet, suit, cx, cy)
	# Metal frame (bevelled), dark outline, cut corners.
	var frame := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if x < 3 or y < 3 or x > w - 4 or y > h - 4:
				frame[Vector2i(x, y)] = true
	_bevel(frame, metal, false)
	for x in w:
		_px(PixelCanvas.OUTLINE, x, 0)
		_px(PixelCanvas.OUTLINE, x, h - 1)
	for y in h:
		_px(PixelCanvas.OUTLINE, 0, y)
		_px(PixelCanvas.OUTLINE, w - 1, y)
	for p in [Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, h - 2), Vector2i(w - 2, h - 2)]:
		_px(PixelCanvas.OUTLINE, p.x, p.y)
	# Inner fillet: shadow line, then light top/left and dark bottom/right.
	for x in range(4, w - 4):
		_px(velvet[0], x, 4)
	for y in range(4, h - 4):
		_px(velvet[0], 4, y)
	for x in range(5, w - 5):
		_px(metal[1], x, 5)
		_px(metal[0], x, h - 6)
	for y in range(5, h - 5):
		_px(metal[1], 5, y)
		_px(metal[0], w - 6, y)
	# Corner motifs of the suit family.
	for corner in [Vector2i(8, 8), Vector2i(w - 9, 8), Vector2i(8, h - 9), Vector2i(w - 9, h - 9)]:
		_bevel(_points(_corner_motif(suit, corner)), metal)
		if suit == "coins":
			_px(gem[2], corner.x, corner.y)
	_medallion(velvet, metal, gem, suit, cx, cy, int(round(w * 17.0 / 56.0)), int(round(h * 22.0 / 82.0)))
	return _img


func _lattice(velvet: Array, suit: String, cx: int, cy: int) -> void:
	var soft: Color = velvet[1].lerp(velvet[2], 0.5)
	for y in _h:
		for x in _w:
			var v: Color = velvet[1]
			match suit:
				"coins":  # diamond lattice with studs
					if (x + y) % 8 == 0 or posmod(x - y, 8) == 0:
						v = velvet[2]
					if x % 8 == 4 and y % 8 == 0:
						v = velvet[3]
				"wands":  # rising vines with buds
					if (x + 2 * y) % 11 == 0:
						v = velvet[2]
					if (x + 2 * y) % 11 == 1 and y % 6 == 0:
						v = velvet[3]
				"cups":  # fish scales / waves
					var yy := y % 6
					var xx := (x + (3 if (y / 6) % 2 else 0)) % 6
					if (yy == 0 and xx in [1, 2, 3, 4]) or (yy == 1 and xx in [0, 5]):
						v = velvet[2]
				"forge":  # riveted leather plates
					if y % 10 == 0:
						v = velvet[0]
					elif y % 10 == 1:
						v = velvet[2]
					elif y % 10 == 5 and x % 8 == 4:
						v = velvet[3]
				"soul":  # little soul wisps rising
					if x % 9 == 4 and (y + (x / 9) * 5) % 10 < 3:
						v = velvet[3] if (y + (x / 9) * 5) % 10 == 0 else velvet[2]
				_:  # sun rays from the medallion
					var a := atan2(y - cy, x - cx)
					if int((a + PI) / TAU * 28.0) % 2 == 0 and (x - cx) * (x - cx) + (y - cy) * (y - cy) > 225:
						v = soft
			_px(v, x, y)


static func _corner_motif(suit: String, c: Vector2i) -> Array:
	var points: Array = []
	match suit:
		"coins":
			for y in range(-2, 3):
				for x in range(-2, 3):
					if x * x + y * y <= 4:
						points.append(c + Vector2i(x, y))
		"wands":
			for k in range(-1, 3):
				points.append(c + Vector2i(k, k))
			points.append(c + Vector2i(2, 0))
			points.append(c + Vector2i(0, 2))
		"cups":
			for p in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				points.append(c + p)
		"forge":  # a hex nut
			for p in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				points.append(c + p)
		"soul":  # a small flame
			for p in [Vector2i(0, -2), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
					Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				points.append(c + p)
		_:
			for p in [Vector2i(0, -2), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]:
				points.append(c + p)
	return points


func _medallion(velvet: Array, metal: Array, gem: Array, suit: String, cx: int, cy: int, rx: int, ry: int) -> void:
	var rim := {}
	for y in range(cy - ry - 1, cy + ry + 2):
		for x in range(cx - rx - 1, cx + rx + 2):
			var ox := (x - cx + 0.5) / rx
			var oy := (y - cy + 0.5) / ry
			if ox * ox + oy * oy > 1.0:
				continue
			var ix := (x - cx + 0.5) / (rx - 2)
			var iy := (y - cy + 0.5) / (ry - 2)
			if ix * ix + iy * iy > 1.0:
				rim[Vector2i(x, y)] = true
				continue
			# Glow of the suit colour behind the ornament, a bit to the top left.
			var dx := (x - cx + 1.0) / rx
			var dy := float(y - cy) / ry
			var d := dx * dx + dy * dy
			var t: Color
			if d < 0.18:
				t = gem[0].lerp(gem[1], 0.5)
			elif d < 0.42:
				t = gem[0]
			elif d < 0.62:
				t = gem[0].lerp(velvet[1], 0.5)
			elif d < 0.86:
				t = velvet[1]
			else:
				t = velvet[0]
			_px(t, x, y)
	_bevel(rim, metal)
	for g in [Vector2i(cx - 1, cy - ry), Vector2i(cx - 1, cy + ry - 1), Vector2i(cx - rx, cy - 1), Vector2i(cx + rx - 1, cy - 1)]:
		_bevel(_points([g, g + Vector2i(1, 0), g + Vector2i(0, 1), g + Vector2i(1, 1)]), gem)
	var o := Vector2i(cx, cy + 2)
	match suit:
		"coins":
			_coins(metal, gem, o)
		"wands":
			_wands(metal, gem, o)
		"cups":
			_cups(metal, gem, o)
		"soul":
			_soul(metal, gem, o)
		"forge":
			_forge(metal, gem, o)
		_:
			_swords(metal, gem, o)


## A coin ring with a pentacle.
func _coins(metal: Array, gem: Array, c: Vector2i) -> void:
	var ring := {}
	for y in range(-11, 12):
		for x in range(-11, 12):
			var d := x * x + y * y
			if d <= 110 and d >= 71:
				ring[c + Vector2i(x, y)] = true
	_bevel(ring, metal)
	var star := {}
	var tips: Array = []
	for i in 5:
		var a := i * TAU * 2.0 / 5.0
		tips.append(Vector2(c) + Vector2(sin(a), -cos(a)) * 7.6)
	for i in 5:
		var p0: Vector2 = tips[i]
		var p1: Vector2 = tips[(i + 1) % 5]
		for k in 21:
			star[Vector2i((p0 + (p1 - p0) * k / 20.0).round())] = true
	_bevel(star, gem, false)
	_px(metal[3], c.x, c.y)


## Two crossed staffs with leaves and flames at the tips.
func _wands(metal: Array, gem: Array, c: Vector2i) -> void:
	var staffs := {}
	for k in range(-11, 12):
		for d in 2:
			staffs[c + Vector2i(roundi(k * 0.55) + d, k)] = true
			staffs[c + Vector2i(-roundi(k * 0.55) + d - 1, k)] = true
	_bevel(staffs, metal)
	var leaves := {}
	for l in [Vector2i(-7, -5), Vector2i(7, -5), Vector2i(-6, 3), Vector2i(7, 3), Vector2i(-3, 8), Vector2i(4, 8)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(-1, 1)]:
			leaves[c + l + d] = true
	_bevel(leaves, gem)
	for fx in [-6, 6]:
		var flame := [Vector2i(0, -16), Vector2i(0, -15), Vector2i(-1, -14), Vector2i(0, -14), Vector2i(1, -14),
			Vector2i(-1, -13), Vector2i(0, -13), Vector2i(1, -13), Vector2i(0, -12)]
		for i in flame.size():
			_px(gem[3] if i % 5 == 0 else gem[2], c.x + fx + flame[i].x, c.y + flame[i].y)


## A chalice with water welling over the rim.
func _cups(metal: Array, gem: Array, c: Vector2i) -> void:
	var cup := {}
	for y in range(-11, 0):
		for x in range(-9, 10):
			if absf(x + 0.5) <= 8.5 - maxf(0.0, y + 6) * 1.5:
				cup[c + Vector2i(x, y)] = true
	for k in 6:
		cup[c + Vector2i(0, k)] = true
		cup[c + Vector2i(-1, k)] = true
	cup[c + Vector2i(-2, 2)] = true
	cup[c + Vector2i(1, 2)] = true
	for y in range(6, 9):
		for x in range(-6, 7):
			if absf(x + 0.5) <= 5.5 - (y - 6):
				cup[c + Vector2i(x, y)] = true
	_bevel(cup, metal)
	for x in range(-6, 6):
		_px(gem[2], c.x + x, c.y - 12)
	for p in [Vector2i(-5, -14), Vector2i(4, -15), Vector2i(-1, -16), Vector2i(-1, -15)]:
		_px(gem[2], c.x + p.x, c.y + p.y)
	for p in [Vector2i(-1, -6), Vector2i(0, -6), Vector2i(-1, -5), Vector2i(0, -5)]:
		_px(gem[3], c.x + p.x, c.y + p.y)


## An upright sword in a ring of rays.
func _swords(metal: Array, gem: Array, c: Vector2i) -> void:
	var sword := {}
	for y in range(-15, 4):
		for x in range(-3, 4):
			if (y >= -14 and absf(x + 0.5) <= 1.6) or (y == -15 and x in [-1, 0]):
				sword[c + Vector2i(x, y)] = true
	for y in range(3, 6):
		for x in range(-7, 8):
			var ax := absf(x + 0.5)
			if (y >= 4 and ax <= 6.5) or (y == 3 and (ax == 5.5 or ax == 6.5)):
				sword[c + Vector2i(x, y)] = true
	for p in [Vector2i(-1, 6), Vector2i(0, 6), Vector2i(-1, 7), Vector2i(0, 7), Vector2i(-1, 8), Vector2i(0, 8),
			Vector2i(-1, 9), Vector2i(0, 9), Vector2i(-2, 10), Vector2i(-1, 10), Vector2i(0, 10), Vector2i(1, 10)]:
		sword[c + p] = true
	_bevel(sword, metal)
	for k in 8:
		var a := k / 8.0 * TAU
		for r in ([10, 11] if k % 2 == 0 else [10]):
			_px(gem[2], roundi(c.x - 0.5 + cos(a) * r), roundi(c.y - 5 + sin(a) * r))
	_px(gem[3], c.x - 1, c.y + 4)
	_px(gem[3], c.x, c.y + 4)


## The pact sigil: a thin soul-blue circle with bone runes, a soul flame inside.
func _soul(metal: Array, gem: Array, c: Vector2i) -> void:
	var cc := c + Vector2i(0, -2)
	for i in 72:
		var a := i / 72.0 * TAU
		_px(gem[2], roundi(cc.x - 0.5 + cos(a) * 12.0), roundi(cc.y - 0.5 + sin(a) * 12.0))
	var runes := {}
	for k in 3:  # three runes on the circle (top, lower left, lower right)
		var a := -PI / 2 + k * TAU / 3.0
		var p := Vector2i(roundi(cc.x - 0.5 + cos(a) * 12.0), roundi(cc.y - 0.5 + sin(a) * 12.0))
		for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			runes[p + d] = true
	_bevel(runes, metal)
	# The flame: a teardrop whose tip curls to the right, brightest low in the core.
	var flame := {}
	for y in range(-9, 7):
		var half: float
		if y < -1:
			half = (y + 9) / 8.0 * 4.0  # tapering towards the tip
		else:
			half = sqrt(maxf(0.0, 1.0 - pow((y + 1) / 7.5, 2))) * 4.5
		var shift := 1 if y < -4 else 0
		for x in range(-6, 7):
			if absf(x + 0.5 - shift) <= half + 0.01:
				flame[cc + Vector2i(x, y)] = true
	for d in [Vector2i(-3, -5), Vector2i(-3, -4), Vector2i(-4, -6), Vector2i(-4, -7)]:  # a side tongue
		flame[cc + d] = true
	for p in flame:
		var rel: Vector2i = p - cc
		var core := pow(rel.x + 0.5, 2) / 6.0 + pow(rel.y - 2.0, 2) / 16.0
		var tone: Color = gem[3] if core < 0.6 else (gem[2] if core < 2.2 else gem[1])
		_px(tone, p.x, p.y)
	for p in flame:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not flame.has(p + d):
				_px(gem[0], p.x + d.x, p.y + d.y)
	for p in [Vector2i(-6, -10), Vector2i(5, -9), Vector2i(2, -15)]:  # sparks of the soul
		_px(gem[2], cc.x + p.x, cc.y + p.y)


## Anvil and a hammer striking it, sparks flying.
func _forge(metal: Array, gem: Array, c: Vector2i) -> void:
	var anvil := {}
	var rows := [[-1, -9, 7], [0, -7, 7], [1, -4, 5], [2, -2, 3], [3, -2, 3], [4, -4, 5], [5, -6, 7], [6, -6, 7]]
	for row in rows:
		for x in range(row[1], row[2] + 1):
			anvil[c + Vector2i(x, row[0])] = true
	_bevel(anvil, metal)
	var handle := {}
	for k in 9:  # the shaft rises to the upper right
		var p := c + Vector2i(1 + roundi(k * 0.7), -6 - k)
		handle[p] = true
		handle[p + Vector2i(1, 0)] = true
	_bevel(handle, _ramp(WOOD))
	var head := {}
	for y in range(-6, -3):
		for x in range(-3, 4):
			head[c + Vector2i(x, y)] = true
	_bevel(head, metal)
	# Sparks from the strike, hottest close to it.
	for spark in [[-5, -4, 3], [5, -5, 3], [-7, -6, 2], [7, -3, 2], [-4, -8, 2], [9, -6, 1], [-9, -3, 1], [3, -9, 1]]:
		_px(gem[spark[2]], c.x + spark[0], c.y + spark[1])
	_px(gem[3], c.x, c.y - 1)  # glowing spot on the anvil face
	_px(gem[2], c.x - 1, c.y - 1)
	_px(gem[2], c.x + 1, c.y - 1)
