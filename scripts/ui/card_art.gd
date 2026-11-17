class_name CardArt
extends RefCounted
## Pixel-art card faces (frame + background) by rarity, drawn at half the
## card's size and scaled up crisply:
## - own cards: frame material by rank (wood, iron, silver, gold, legendary
##   gold), parchment tinted in the tarot suit with motifs that grow richer
##   with the rank (watermark, border ornament, vines, ray burst, starry sky);
## - fusions: a frame braided from the materials of the fused figures;
## - enemies: cursed counterparts on dark cracked parchment, frames by cost
##   (rusty iron, thorns, bone and blood) and skulls with glowing eyes for bosses.

const MATERIALS := {
	"wood": ["2a1a0e", "4a2e18", "7a4a24", "a8743a"],
	"iron": ["24262c", "44484f", "6b707a", "9aa0aa"],
	"silver": ["3a4458", "7a8aa6", "b4c4dc", "eef4ff"],
	"gold": ["4a3208", "9a6a14", "d9a530", "ffe08a"],
	"rust": ["24120a", "5a2a14", "8a4a24", "b0703a"],
	"bone": ["4a4234", "8a7e64", "cfc4a6", "f0e8d4"],
}
const RANK_MATERIAL := {"page": "wood", "knight": "iron", "queen": "silver", "king": "gold", "legend": "gold"}
const RANK_TIER := {"page": 0, "knight": 1, "queen": 2, "king": 3, "legend": 4}
## Parchment per suit: light, mid, dark (motifs), deep (lines).
const PAPER := {
	"coins": ["eef0d4", "d6dcb0", "a8b07e", "6a7448"],
	"wands": ["f2dcc0", "dcb898", "b08466", "7a4a34"],
	"cups": ["e2e8f0", "c0cade", "8c9cbc", "52648c"],
	"swords": ["e6dcee", "cabcdc", "9a8cba", "5e507e"],
}
const ENEMY_PAPER := ["3a2228", "2a161c", "1c0c10", "120608"]
const GEMS := {"coins": "28b060", "wands": "e04a2a", "cups": "2a7ae0", "swords": "a65ae0"}
const OUTLINE := Color("120a0e")
const SUIT_MARKS := {
	"coins": [".ooooo.", "o.....o", "o.ooo.o", "o.o.o.o", "o.ooo.o", "o.....o", ".ooooo."],
	"wands": ["...o...", "..ooo..", "..o.o..", "...o...", "...o...", "...o...", "..ooo.."],
	"cups": ["ooooooo", "o.....o", ".o...o.", "..ooo..", "...o...", "...o...", ".ooooo."],
	"swords": ["...o...", "...o...", "...o...", "...o...", "ooooooo", "...o...", "...o..."],
}

static var _cache: Dictionary = {}


## The card face for a unit. width = how many card widths it spans.
static func for_unit(definition: Dictionary, enemy: bool, suit: String, size_px: Vector2) -> ImageTexture:
	var w := int(size_px.x / 2.0)
	var h := int(size_px.y / 2.0)
	var key := ""
	var spec := {"w": w, "h": h, "enemy": enemy}
	if enemy:
		spec["boss"] = bool(definition.get("boss", false))
		spec["tier"] = clampi(int(definition.get("cost", 1)), 1, 3)
		key = "e:%d:%d:%s:%d" % [w, h, spec["boss"], spec["tier"]]
	else:
		var rank := String(definition.get("rank", "page"))
		if definition.get("recipe", false):
			rank = "legend"
		spec["rank"] = rank
		spec["suit"] = suit if suit != "" else String(definition.get("suit", "coins"))
		var fusion: Dictionary = definition.get("fusion", {})
		spec["materials"] = [RANK_MATERIAL.get(rank, "wood")]
		if not fusion.is_empty():
			spec["materials"] = fusion.get("part_ranks", [rank]).map(
				func(r: String) -> String: return RANK_MATERIAL.get(r, "wood"))
			spec["stage"] = int(fusion.get("stage", 0))
		key = "p:%d:%d:%s:%s:%s:%d" % [w, h, rank, spec["suit"], ",".join(spec["materials"]), int(spec.get("stage", 0))]
	if not _cache.has(key):
		_cache[key] = _draw(spec)
	return _cache[key]


static func _ramp(name: String) -> Array:
	return MATERIALS[name].map(func(hex: String) -> Color: return Color(hex))


static func _draw(spec: Dictionary) -> ImageTexture:
	var w: int = spec["w"]
	var h: int = spec["h"]
	var c := PixelCanvas.new(w, h)
	if spec["enemy"]:
		_enemy_background(c, w, h)
		_enemy_frame(c, w, h, spec)
	else:
		_background(c, w, h, spec)
		_frame(c, w, h, spec)
	_round_corners(c, w, h)
	return c.texture()


# --- Own cards ---------------------------------------------------------------------------

static func _background(c: PixelCanvas, w: int, h: int, spec: Dictionary) -> void:
	var rank: String = spec["rank"]
	var paper: Array = PAPER.get(spec["suit"], PAPER["coins"]).map(func(hex: String) -> Color: return Color(hex))
	if rank == "legend":  # night sky with stars and golden rays
		for y in h:
			var t := float(y) / h
			c.px(Color(0.08 + t * 0.06, 0.06 + t * 0.04, 0.16 + t * 0.06), 0, y, w, 1)
		_rays(c, w, h, Color(1.0, 0.85, 0.4, 0.22), 14)
		for i in 26:
			var p := Vector2i((i * 37 + 5) % w, (i * 23 + 3) % (h - 10))
			c.px(Color("fff8e0") if i % 3 else Color("c0a0ff"), p.x, p.y)
		return
	for y in h:  # parchment, a little lighter at the top
		var tone: Color = paper[0].lerp(paper[1], clampf(float(y) / h * 1.3, 0.0, 1.0))
		c.px(tone, 0, y, w, 1)
	for i in w * h / 22:  # paper fibres
		var x := (i * 53 + 7) % w
		var y := (i * 29 + 11) % h
		c.px(paper[1].darkened(0.06), x, y)
	var tier: int = RANK_TIER.get(rank, 0)
	if tier >= 3:  # king: ray burst behind the figure
		_rays(c, w, h, Color(paper[2], 0.45), 12)
	# Suit watermark behind the figure (all ranks).
	var mark: Array = SUIT_MARKS.get(spec["suit"], SUIT_MARKS["coins"])
	var scale := 3 if w >= 50 else 2
	var ox := w / 2 - 7 * scale / 2
	var oy := int(h * 0.38) - 7 * scale / 2
	for y in 7:
		for x in 7:
			if String(mark[y])[x] == "o":
				c.px(Color(paper[2], 0.55), ox + x * scale, oy + y * scale, scale, scale)
	if tier >= 1:  # knight: an inner ornament border with corner diamonds
		var col: Color = paper[2]
		for x in range(6, w - 6, 2):
			c.px(col, x, 5)
			c.px(col, x, h - 6)
		for y in range(6, h - 6, 2):
			c.px(col, 5, y)
			c.px(col, w - 6, y)
		for p in [Vector2i(5, 5), Vector2i(w - 6, 5), Vector2i(5, h - 6), Vector2i(w - 6, h - 6)]:
			c.px(paper[3], p.x - 1, p.y, 3, 1)
			c.px(paper[3], p.x, p.y - 1, 1, 3)
	if tier >= 2:  # queen: vines curling along the sides
		for y in range(8, h - 8):
			var dx := int(round(sin(y * 0.55) * 1.5))
			c.px(Color(paper[3], 0.7), 8 + dx, y)
			c.px(Color(paper[3], 0.7), w - 9 - dx, y)
			if y % 7 == 0:
				c.px(Color(paper[2], 0.9), 9 + dx, y - 1, 2, 2)
				c.px(Color(paper[2], 0.9), w - 11 - dx, y - 1, 2, 2)


static func _rays(c: PixelCanvas, w: int, h: int, color: Color, count: int) -> void:
	var center := Vector2(w / 2.0, h * 0.45)
	for y in h:
		for x in w:
			var a := atan2(y - center.y, x - center.x)
			if int(floor((a + PI) / TAU * count * 2.0)) % 2 == 0:
				var d := Vector2(x, y).distance_to(center) / (h * 0.6)
				if d < 1.0:
					var base: Color = c.image.get_pixel(x, y)
					c.image.set_pixel(x, y, base.lerp(Color(color.r, color.g, color.b), color.a * (1.0 - d)))


## The frame: 3 px of material (fusions braid several materials).
static func _frame(c: PixelCanvas, w: int, h: int, spec: Dictionary) -> void:
	var materials: Array = spec["materials"]
	var ramps: Array = materials.map(func(m: String) -> Array: return _ramp(m))
	for y in h:
		for x in w:
			var edge := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			if edge > 2:
				continue
			var ramp: Array = ramps[0]
			if ramps.size() > 1:  # braided: diagonal bands of the fused materials
				ramp = ramps[int(floor((x + y) / 4.0)) % ramps.size()]
			var tone := 1
			if edge == 0:
				tone = 0
			elif edge == 1:
				tone = 3 if (x < w / 2 and y < h / 2) else 2
			else:
				tone = 1
			if x == w - 1 - edge or y == h - 1 - edge:
				tone = mini(tone, 1) if edge > 0 else 0
			c.image.set_pixel(x, y, ramp[tone])
	var main: String = materials[0]
	var rank: String = spec["rank"]
	var gem := Color(GEMS.get(spec["suit"], "28b060"))
	match main:
		"wood":  # grain
			for y in range(4, h - 4, 5):
				c.px(_ramp("wood")[0], 1, y, 1, 2)
				c.px(_ramp("wood")[0], w - 2, y + 2, 1, 2)
		"iron":  # rivets
			for x in range(5, w - 4, 8):
				c.px(_ramp("iron")[3], x, 1)
				c.px(_ramp("iron")[3], x, h - 2)
			for y in range(5, h - 4, 8):
				c.px(_ramp("iron")[3], 1, y)
				c.px(_ramp("iron")[3], w - 2, y)
	var tier: int = RANK_TIER.get(rank, 0)
	if tier >= 2:  # silver and gold: corner ornaments
		var orn: Array = _ramp(main)
		for p in [Vector2i(0, 0), Vector2i(w - 6, 0), Vector2i(0, h - 6), Vector2i(w - 6, h - 6)]:
			c.px(orn[3], p.x + 1, p.y + 1, 4, 1)
			c.px(orn[3], p.x + 1, p.y + 1, 1, 4)
			c.px(orn[2], p.x + 3, p.y + 3, 2, 2)
	if tier >= 3:  # gold: gems in the corners and on the sides
		var glow := tier >= 4
		for p in [Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 3), Vector2i(w - 3, h - 3),
				Vector2i(w / 2, 1), Vector2i(w / 2, h - 2)]:
			c.px(OUTLINE, p.x - 1, p.y - 1, 3, 3)
			c.px(gem if not glow else Color("7af0ff"), p.x, p.y)
			if glow:
				c.px(Color(1, 1, 1, 0.9), p.x, p.y)
				c.px(Color("7af0ff"), p.x - 1, p.y)
				c.px(Color("7af0ff"), p.x + 1, p.y)


# --- Enemy cards ---------------------------------------------------------------------------

static func _enemy_background(c: PixelCanvas, w: int, h: int) -> void:
	var paper: Array = ENEMY_PAPER.map(func(hex: String) -> Color: return Color(hex))
	for y in h:
		c.px(paper[0].lerp(paper[2], float(y) / h), 0, y, w, 1)
	# Cracks running through the old parchment.
	for i in 5:
		var x := (i * 17 + 9) % w
		var y := (i * 31 + 6) % (h - 10)
		for s in 9:
			x += [-1, 0, 1, 1, 0, -1][(s + i) % 6]
			y += 1
			c.px(paper[3], x, y)
	for i in w * h / 30:
		c.px(paper[1].lightened(0.05), (i * 41 + 3) % w, (i * 19 + 5) % h)


static func _enemy_frame(c: PixelCanvas, w: int, h: int, spec: Dictionary) -> void:
	var boss: bool = spec["boss"]
	var tier: int = spec["tier"]
	var ramp := _ramp("bone" if (tier >= 3 or boss) else "rust")
	for y in h:
		for x in w:
			var edge := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			if edge > 2:
				continue
			var tone := 0 if edge == 0 else (2 if edge == 1 else 1)
			if (x * 7 + y * 3) % 11 == 0 and edge > 0:
				tone = 0  # rust pits / old bone
			c.image.set_pixel(x, y, ramp[tone])
	if tier >= 2 or boss:  # thorns pointing inwards
		for y in range(6, h - 6, 6):
			c.px(ramp[2], 3, y, 2, 1)
			c.px(ramp[3], 5, y)
			c.px(ramp[2], w - 5, y, 2, 1)
			c.px(ramp[3], w - 6, y)
		for x in range(6, w - 6, 6):
			c.px(ramp[2], x, 3, 1, 2)
			c.px(ramp[3], x, 5)
	if tier >= 3 or boss:  # blood running down from the top
		var blood := Color("8a1420")
		for x in range(4, w - 4, 7):
			var length := 3 + (x * 5) % 6
			c.px(blood, x, 3, 1, length)
			c.px(Color("c02030"), x, 3 + length - 1)
	if boss:  # skulls with glowing eyes in the corners
		for p in [Vector2i(0, 0), Vector2i(w - 7, 0), Vector2i(0, h - 7), Vector2i(w - 7, h - 7)]:
			c.px(OUTLINE, p.x, p.y, 7, 7)
			c.px(_ramp("bone")[3], p.x + 1, p.y + 1, 5, 4)
			c.px(_ramp("bone")[2], p.x + 2, p.y + 5, 3, 1)
			c.px(Color("ff3030"), p.x + 2, p.y + 2)
			c.px(Color("ff3030"), p.x + 4, p.y + 2)


static func _round_corners(c: PixelCanvas, w: int, h: int) -> void:
	for p in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		c.image.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
