class_name CardArt
extends RefCounted
## Pixel-art card faces (frame + background), drawn at half the card's size
## and scaled up crisply. Rarity is shown by clear colours, and the higher
## tiers add effects through card_shine.gdshader:
##   page bronze (plain) · knight blue steel (gloss) · queen violet (gloss)
##   king gold (gloss + sparkles) · ace/legend polychrome · recipes black gold
##   with strong polychrome · fusions braided frames (more gloss per stage)
##   legendary skins in their theme colour · enemies cursed (rust, thorns, bone,
##   skulls for bosses) · objects by equipment rarity or category colour.

const TIERS := {
	"page": {"frame": ["2e2216", "5e4630", "947454", "c8a880"], "bg": ["ece2cc", "cdbd9c"], "fx": {}},
	"knight": {"frame": ["101c34", "264a80", "4f84d0", "b8d8ff"], "bg": ["dde8f6", "a9c0e0"], "fx": {"gloss": 0.55}},
	"queen": {"frame": ["220e36", "552682", "9654d6", "e2c4ff"], "bg": ["ece0f6", "c6a8e2"], "fx": {"gloss": 0.8}},
	"king": {"frame": ["4a3208", "9a6a14", "e0aa30", "fff0a0"], "bg": ["f8ecc8", "e2c88a"], "fx": {"gloss": 1.0, "sparkle": 1.0}},
	"legend": {"frame": ["4a3c22", "b09858", "f0e0a0", "ffffff"], "bg": ["1a1430", "0c0a1a"], "dark": true,
		"fx": {"gloss": 1.0, "sparkle": 1.0, "poly": 0.75}},
	"recipe": {"frame": ["0a0806", "4a3208", "d9a530", "ffe08a"], "bg": ["3a0c14", "12040a"], "dark": true,
		"fx": {"gloss": 1.0, "sparkle": 1.0, "poly": 1.0}},
}
## Equipment rarity -> tier look (common, magic, rare, epic, unique).
const ITEM_TIERS := ["page", "knight", "king", "queen", "unique"]
const UNIQUE := {"frame": ["0a3a36", "1e8a80", "45f2e0", "d8fff8"], "bg": ["123432", "08201e"], "dark": true,
	"fx": {"gloss": 1.0, "sparkle": 1.0, "poly": 0.6}}
const CATEGORY := {
	"relic": {"frame": ["0a2a28", "1e6a64", "4ac8bc", "b8fff4"], "bg": ["16302e", "0a1a1a"], "dark": true, "fx": {"gloss": 0.5}},
	"tarot": {"frame": ["1e1036", "4a2a80", "a070e0", "e8d0ff"], "bg": ["221838", "100a20"], "dark": true, "fx": {"gloss": 0.5}},
	"pact": {"frame": ["2a0408", "6a0c16", "c02436", "ff8a90"], "bg": ["2a0a10", "140408"], "dark": true, "fx": {"gloss": 0.4}},
}
const ENEMY_BG := ["3a2228", "1c0c10"]
const SUIT_MARKS := {
	"coins": [".ooooo.", "o.....o", "o.ooo.o", "o.o.o.o", "o.ooo.o", "o.....o", ".ooooo."],
	"wands": ["...o...", "..ooo..", "..o.o..", "...o...", "...o...", "...o...", "..ooo.."],
	"cups": ["ooooooo", "o.....o", ".o...o.", "..ooo..", "...o...", "...o...", ".ooooo."],
	"swords": ["...o...", "...o...", "...o...", "...o...", "ooooooo", "...o...", "...o..."],
}
const OUTLINE := Color("120a0e")

static var _cache: Dictionary = {}


## {"tex", "fx" {gloss, sparkle, poly}, "accent" (frame colour), "dark" (light text needed)}.
static func for_unit(definition: Dictionary, enemy: bool, suit: String, size_px: Vector2) -> Dictionary:
	var w := int(size_px.x / 2.0)
	var h := int(size_px.y / 2.0)
	if enemy:
		var boss := bool(definition.get("boss", false))
		var tier := clampi(int(definition.get("cost", 1)), 1, 3)
		return _cached("e:%d:%d:%s:%d" % [w, h, boss, tier], func() -> Dictionary: return _enemy(w, h, tier, boss))
	suit = suit if suit != "" else String(definition.get("suit", "coins"))
	var id := String(definition.get("id", ""))
	var skin := String(Cosmetics.skins.get(id, ""))
	if FigureArt.SKINS.has(skin) and not definition.has("fusion"):
		var theme: Array = FigureArt.FX_COLORS[FigureArt.SKINS[skin]["fx"]]
		return _cached("s:%d:%d:%s" % [w, h, skin], func() -> Dictionary: return _skin(w, h, suit, theme))
	var rank := String(definition.get("rank", "page"))
	if definition.get("recipe", false):
		return _cached("r:%d:%d:%s" % [w, h, suit], func() -> Dictionary: return _figure(w, h, TIERS["recipe"], suit, "recipe"))
	if rank == "legend":
		return _cached("a:%d:%d:%s" % [w, h, suit], func() -> Dictionary: return _figure(w, h, TIERS["legend"], suit, "ace"))
	var fusion: Dictionary = definition.get("fusion", {})
	if not fusion.is_empty():
		var ranks: Array = fusion.get("part_ranks", [rank])
		var stage := int(fusion.get("stage", 1))
		return _cached("f:%d:%d:%s:%s:%d" % [w, h, suit, ",".join(ranks), stage],
			func() -> Dictionary: return _fusion(w, h, ranks, suit, stage))
	return _cached("p:%d:%d:%s:%s" % [w, h, rank, suit],
		func() -> Dictionary: return _figure(w, h, TIERS.get(rank, TIERS["page"]), suit, ""))


## Object cards: equipment by rarity, relics / tarot / pacts by category.
static func for_object(kind: String, rarity: int, size_px: Vector2) -> Dictionary:
	var w := int(size_px.x / 2.0)
	var h := int(size_px.y / 2.0)
	if kind == "tarot":
		return _cached("t:%d:%d" % [w, h], func() -> Dictionary: return _tarot(w, h))
	var look: Dictionary
	if kind == "equipment":
		var tier: String = ITEM_TIERS[clampi(rarity, 0, 4)]
		look = UNIQUE if tier == "unique" else TIERS[tier]
	else:
		look = CATEGORY.get(kind, TIERS["page"])
	return _cached("o:%d:%d:%s:%d" % [w, h, kind, rarity], func() -> Dictionary: return _figure(w, h, look, "", ""))


static func _cached(key: String, make: Callable) -> Dictionary:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _colors(hexes: Array) -> Array:
	return hexes.map(func(hex: String) -> Color: return Color(hex))


# --- Faces ---------------------------------------------------------------------------------

static func _figure(w: int, h: int, look: Dictionary, suit: String, special: String) -> Dictionary:
	var c := PixelCanvas.new(w, h)
	var frame := _colors(look["frame"])
	_gradient(c, w, h, Color(look["bg"][0]), Color(look["bg"][1]))
	if look.get("dark", false):
		_stars(c, w, h, frame[3])
	else:
		_fibres(c, w, h, Color(look["bg"][1]))
	if special == "ace" or special == "recipe":
		_rays(c, w, h, Color(frame[2], 0.35), 16)
	if special == "recipe":
		_circle(c, w / 2, int(h * 0.45), mini(w, h) / 3, Color(frame[2], 0.6))
	if suit != "":
		_watermark(c, w, h, suit, Color(frame[1], 0.28 if special == "" else 0.5), special != "")
	_frame(c, w, h, [frame])
	_round(c, w, h)
	return {"tex": c.texture(), "fx": look.get("fx", {}), "accent": frame[2], "dark": look.get("dark", false)}


## A real tarot card: midnight sky, a gold arch framing the picture, a name
## plate at the bottom and a double gold frame.
## Layout of a tarot card as fractions of its height (shared with ObjectCard):
## the arch ("gate") with the picture, the name plate below it, then the text field.
const TAROT_ARCH_END := 0.47
const TAROT_NAME := [0.49, 0.585]
const TAROT_TEXT := [0.61, 0.935]


## A real tarot card: midnight sky, a gold arch framing the picture, a name
## plate and a separate text field, all inside a double gold frame.
static func _tarot(w: int, h: int) -> Dictionary:
	var c := PixelCanvas.new(w, h)
	var gold := _colors(TIERS["king"]["frame"])
	_gradient(c, w, h, Color("221a44"), Color("0e0a22"))
	_stars(c, w, h, Color("e8dcff"))
	var cx := w / 2
	var top := 8
	var r := (w - 18) / 2
	var bottom := int(h * TAROT_ARCH_END)
	for y in range(top, bottom + 1):  # the arch window (lighter sky inside)
		for x in range(9, w - 9):
			if y >= top + r or Vector2(x, y).distance_to(Vector2(cx, top + r)) <= r:
				var base: Color = c.image.get_pixel(x, y)
				c.image.set_pixel(x, y, base.lerp(Color("3a2c6a"), 0.55))
	for i in 48:  # gold arch line
		var a := PI + PI * i / 47.0
		c.px(gold[2], cx + int(cos(a) * r), top + r + int(sin(a) * r))
	c.px(gold[2], 9, top + r, 1, bottom - top - r)
	c.px(gold[2], w - 10, top + r, 1, bottom - top - r)
	c.px(gold[2], 9, bottom, w - 18, 1)
	# Name plate: a gold-edged band.
	var n0 := int(h * TAROT_NAME[0])
	var n1 := int(h * TAROT_NAME[1])
	c.px(gold[0], 7, n0, w - 14, n1 - n0)
	c.px(gold[2], 7, n0, w - 14, 1)
	c.px(gold[1], 7, n1, w - 14, 1)
	# Text field: a dark panel with a thin gold border.
	var t0 := int(h * TAROT_TEXT[0])
	var t1 := int(h * TAROT_TEXT[1])
	c.px(Color("0a0716"), 7, t0, w - 14, t1 - t0)
	c.px(gold[1], 7, t0, w - 14, 1)
	c.px(gold[1], 7, t1, w - 14, 1)
	c.px(gold[1], 7, t0, 1, t1 - t0)
	c.px(gold[1], w - 8, t0, 1, t1 - t0 + 1)
	_frame(c, w, h, [gold])
	_round(c, w, h)
	return {"tex": c.texture(), "fx": {"gloss": 0.7, "sparkle": 0.8}, "accent": gold[2], "dark": true}


static func _fusion(w: int, h: int, ranks: Array, suit: String, stage: int) -> Dictionary:
	var c := PixelCanvas.new(w, h)
	var main: Dictionary = TIERS.get(ranks[0], TIERS["page"])
	# Calm and elegant: the main figure's parchment, the braided frame of all
	# fused figures, and one small gold stone per fusion stage at the bottom.
	_gradient(c, w, h, Color(main["bg"][0]), Color(main["bg"][1]))
	_fibres(c, w, h, Color(main["bg"][1]))
	var frames: Array = ranks.map(func(r: String) -> Array: return _colors(TIERS.get(r, TIERS["page"])["frame"]))
	_vortex(c, w, h, frames.map(func(f: Array) -> Color: return f[1]), stage)
	_frame(c, w, h, frames)
	var gold := _colors(TIERS["king"]["frame"])
	for x in range(5, w - 5):  # a fine gold inner line
		c.px(Color(gold[2], 0.55), x, 4)
		c.px(Color(gold[2], 0.55), x, h - 5)
	for i in clampi(stage, 1, 3):
		var x := w / 2 + (i - (clampi(stage, 1, 3) - 1) / 2.0) * 5.0
		c.px(OUTLINE, int(x) - 1, h - 3, 3, 3)
		c.px(gold[3], int(x), h - 2)
	_round(c, w, h)
	var fx := {"gloss": [0.0, 0.15, 0.22, 0.3][clampi(stage, 0, 3)]}
	return {"tex": c.texture(), "fx": fx, "accent": frames[0][2], "dark": false}


static func _skin(w: int, h: int, suit: String, theme: Array) -> Dictionary:
	var main := Color(theme[0])
	var light := Color(theme[1])
	var frame := [main.darkened(0.7), main.darkened(0.3), main, light]
	var c := PixelCanvas.new(w, h)
	# A calm, neutral background so the skinned figure stands out; the theme
	# colour lives in the frame and a faint watermark only.
	_gradient(c, w, h, Color("4a4450").lerp(main, 0.12), Color("1e1a24"))
	_fibres(c, w, h, Color("2a2630"))
	_watermark(c, w, h, suit, Color(light, 0.12), true)
	_frame(c, w, h, [frame])
	_round(c, w, h)
	return {"tex": c.texture(), "fx": {"gloss": 0.35}, "accent": main, "dark": true}


## Enemy cards: the same bold card as the player's, but cursed - dark
## blood-red parchment, iron/bone frames, skulls with glowing eyes and smoke
## that grow with the enemy's strength (tier 1-3, bosses strongest).
static func _enemy(w: int, h: int, tier: int, boss: bool) -> Dictionary:
	var c := PixelCanvas.new(w, h)
	var level := 4 if boss else tier
	# A dusty blood-red mid tone (not black), so dark creatures still stand out.
	var bg_top := Color("9a6a62").lerp(Color("8a4a46"), level / 4.0)
	_gradient(c, w, h, bg_top, Color("5a3434").lerp(Color("4a2226"), level / 4.0))
	for i in 4 + level * 2:  # cracks through the cursed parchment
		var x := (i * 17 + 9) % w
		var y := (i * 31 + 6) % maxi(1, h - 10)
		for s in 7 + level * 2:
			x += [-1, 0, 1, 1, 0, -1][(s + i) % 6]
			y += 1
			c.px(Color("3a1a1c"), x, y)
	var frame := _colors(["1a0a0a", "4a2a24", "8a6a5a", "c8b8a0"] if level >= 3 else ["140808", "3a1a14", "6a3424", "9a5a3a"])
	_frame(c, w, h, [frame])
	if level >= 2:  # thorns pointing inwards
		for y in range(8, h - 8, 6):
			c.px(frame[2], 4, y, 2, 1)
			c.px(frame[2], w - 6, y, 2, 1)
	if level >= 3:  # blood running down from the top
		for x in range(6, w - 6, 7):
			var length := 3 + (x * 5) % 6
			c.px(Color("8a1420"), x, 4, 1, length)
			c.px(Color("d02838"), x, 4 + length - 1)
	# Skulls with glowing eyes on the frame: 1 at the bottom, 2 more on the
	# sides from tier 2, all four corners from tier 3, big ones for bosses.
	var size := 2 if boss else 1
	var spots: Array = [Vector2i(w / 2 - 3 * size, h - 7 * size)]
	if level >= 2:
		spots.append(Vector2i(0, h / 2 - 3 * size))
		spots.append(Vector2i(w - 7 * size, h / 2 - 3 * size))
	if level >= 3:
		spots.append_array([Vector2i(0, 0), Vector2i(w - 7 * size, 0), Vector2i(0, h - 7 * size), Vector2i(w - 7 * size, h - 7 * size)])
	for p in spots:
		_skull(c, p.x, p.y, size, frame[3], Color("ff3030"))
	_round(c, w, h)
	var fx := {"curse": true, "smoke": [0.0, 0.25, 0.5, 0.75, 1.0][level], "eyes": 0.5 + 0.125 * level}
	return {"tex": c.texture(), "fx": fx, "accent": Color("c02030"), "dark": true}


## A small pixel skull (7×7 per size step) with eyes in eye_color.
static func _skull(c: PixelCanvas, x: int, y: int, size: int, bone: Color, eye_color: Color) -> void:
	var rows := [".bbbbb.", "bbbbbbb", "beebeeb", "beebeeb", "bbb.bbb", ".bbbbb.", ".b.b.b."]
	for j in 7:
		for i in 7:
			var ch: String = rows[j][i]
			if ch == ".":
				continue
			c.px(eye_color if ch == "e" else bone, x + i * size, y + j * size, size, size)


# --- Building blocks -------------------------------------------------------------------------

static func _gradient(c: PixelCanvas, w: int, h: int, top: Color, bottom: Color) -> void:
	for y in h:
		c.px(top.lerp(bottom, float(y) / maxf(1.0, h - 1)), 0, y, w, 1)


static func _fibres(c: PixelCanvas, w: int, h: int, color: Color) -> void:
	for i in w * h / 24:
		c.px(color.darkened(0.05), (i * 53 + 7) % w, (i * 29 + 11) % h)


static func _stars(c: PixelCanvas, w: int, h: int, color: Color) -> void:
	for i in w * h / 90:
		var p := Vector2i((i * 37 + 5) % w, (i * 23 + 3) % h)
		c.px(color if i % 3 else Color(color, 0.5), p.x, p.y)


static func _rays(c: PixelCanvas, w: int, h: int, color: Color, count: int) -> void:
	var center := Vector2(w / 2.0, h * 0.45)
	for y in h:
		for x in w:
			var a := atan2(y - center.y, x - center.x)
			if int(floor((a + PI) / TAU * count * 2.0)) % 2 == 0:
				var d := Vector2(x, y).distance_to(center) / (h * 0.65)
				if d < 1.0:
					var base: Color = c.image.get_pixel(x, y)
					c.image.set_pixel(x, y, base.lerp(Color(color.r, color.g, color.b), color.a * (1.0 - d)))


## The fusion vortex behind the figure: spiral arms in the colours of the
## fused figures turning into a bright core; more arms per fusion stage.
static func _vortex(c: PixelCanvas, w: int, h: int, colors: Array, stage: int) -> void:
	var center := Vector2(w / 2.0, h * 0.44)
	var reach := minf(w, h) * 0.8
	var arms := 2 + clampi(stage, 1, 3)
	for y in h:
		for x in w:
			var d := Vector2(x, y) - center
			var r := d.length() / reach
			if r > 1.0:
				continue
			var a := atan2(d.y, d.x)
			var spiral := fposmod(a * arms / TAU + log(r + 0.05) * 1.6, 1.0)
			var arm := int(floor(fposmod(a / TAU * arms + log(r + 0.05) * 1.6 / 1.0, float(arms)))) % colors.size()
			var strength := 1.0 - r * r
			var band := 1.0 - absf(spiral - 0.5) * 2.0  # brightest in the middle of each arm
			var tint: Color = colors[arm]
			var base: Color = c.image.get_pixel(x, y)
			var mixed := base.lerp(tint, clampf(band * strength * 0.85, 0.0, 0.8))
			mixed = mixed.lerp(Color("fff6e0"), clampf((0.18 - r) * 4.0, 0.0, 0.6))  # bright core
			c.image.set_pixel(x, y, mixed)


static func _circle(c: PixelCanvas, cx: int, cy: int, r: int, color: Color) -> void:
	for i in 64:
		var a := TAU * i / 64.0
		c.px(color, cx + int(cos(a) * r), cy + int(sin(a) * r))
	for i in 6:  # a hexagram inside the arcane circle
		var a := TAU * i / 6.0 - PI / 2
		var b := TAU * (i + 2) / 6.0 - PI / 2
		var from := Vector2(cx + cos(a) * r, cy + sin(a) * r)
		var to := Vector2(cx + cos(b) * r, cy + sin(b) * r)
		for s in 24:
			var p := from.lerp(to, s / 23.0)
			c.px(color, int(p.x), int(p.y))


static func _watermark(c: PixelCanvas, w: int, h: int, suit: String, color: Color, big: bool) -> void:
	var mark: Array = SUIT_MARKS.get(suit, SUIT_MARKS["coins"])
	var scale := (5 if big else 4) if w >= 50 else 3
	var ox := w / 2 - 7 * scale / 2
	var oy := int(h * 0.42) - 7 * scale / 2
	for y in 7:
		for x in 7:
			if String(mark[y])[x] == "o":
				c.px(color, ox + x * scale, oy + y * scale, scale, scale)


## A bold 4-pixel bevelled frame; several ramps braid in diagonal bands.
static func _frame(c: PixelCanvas, w: int, h: int, ramps: Array) -> void:
	for y in h:
		for x in w:
			var edge := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			if edge > 3:
				continue
			var ramp: Array = ramps[0] if ramps.size() == 1 else ramps[int(floor((x + y) / 5.0)) % ramps.size()]
			var lit := x + y < (w + h) / 2  # top-left half catches the light
			var tone: Color
			match edge:
				0:
					tone = OUTLINE
				1:
					tone = ramp[3] if lit else ramp[1]
				2:
					tone = ramp[2]
				_:
					tone = ramp[0]
			c.image.set_pixel(x, y, tone)


static func _round(c: PixelCanvas, w: int, h: int) -> void:
	for p in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		c.image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))


static var _shader: Shader
static var _curse_shader: Shader


## The face as a crisp TextureRect with the rarity effects as shader params.
static func face_rect(face: Dictionary) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = face["tex"]
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx: Dictionary = face.get("fx", {})
	if fx.get("curse", false):  # enemies: smoke and glowing skull eyes
		if _curse_shader == null:
			_curse_shader = load("res://scripts/ui/card_curse.gdshader")
		var curse := ShaderMaterial.new()
		curse.shader = _curse_shader
		curse.set_shader_parameter("smoke", float(fx.get("smoke", 0.0)))
		curse.set_shader_parameter("eyes", float(fx.get("eyes", 0.0)))
		rect.material = curse
		return rect
	if not fx.is_empty():
		if _shader == null:
			_shader = load("res://scripts/ui/card_shine.gdshader")
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("gloss", float(fx.get("gloss", 0.0)))
		material.set_shader_parameter("sparkle", float(fx.get("sparkle", 0.0)))
		material.set_shader_parameter("poly", float(fx.get("poly", 0.0)))
		material.set_shader_parameter("gloss_speed", 0.25 + randf() * 0.15)
		rect.material = material
	return rect

