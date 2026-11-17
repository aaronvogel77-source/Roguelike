class_name FigureArt
extends RefCounted
## Builds the pixel art of figures, enemies and the battle background.
## Style "Prunk & Reliquie": the material shows the rank (iron, steel, silver,
## gold), a gem on the chest shows the suit, fusions add gilding, only secret
## recipe figures shimmer.
##
## A "look" describes a figure; build() turns it into rig parts
## {"legB", "legF", "torso", "head", "armB", "armF", "weapon", ["shield"], ["cape"]}
## each {"tex", "pivot"}, plus "dim" and "arm_len".

const RAMPS := {
	"skin": ["3a2418", "7a4a32", "b47a52", "e0aa80"],
	"iron": ["1e2024", "3e434c", "6b7380", "a9b2bf"],
	"steel": ["24303c", "4c5c6e", "8094aa", "c8d6e6"],
	"silver": ["28324a", "5a6c8c", "9db0d0", "e2ecff"],
	"gold": ["4a3208", "9a6a14", "d9a530", "ffe08a"],
	"leather": ["24160e", "4a2e1c", "704a2e", "94683f"],
	"wood": ["1e1208", "3c2414", "5c3a20", "7e5430"],
	"hair": ["1a100a", "3a2414", "5c3a20", "7a5230"],
	"beard": ["2a2420", "6a625a", "a8a096", "d8d2c8"],
	"fur": ["3a3430", "8a8278", "d8d0c4", "ffffff"],
	"ghost": ["1c2630", "3a5060", "6a8a9a", "b8d8e0"],
	"shadow": ["0a080d", "1b1722", "2b2535", "3d3449"],
	"coins": ["0e1e14", "1e3c26", "2f5e3a", "4c8456"],
	"wands": ["2a0c10", "5a1820", "8c2a30", "b8464a"],
	"cups": ["0c1a2e", "1a3458", "2c5288", "4a78b8"],
	"swords": ["1a1626", "342c4a", "54487a", "7a6ca8"],
	# Enemies: corrupted bronze, sickly skin, dark red cloth
	"bronze": ["1e140a", "4a3218", "7a5428", "a87e44"],
	"sick": ["1e2418", "3e4a32", "66764e", "94a274"],
	"blood": ["1e0608", "3c0c10", "601820", "88282e"],
}
const GEMS := {"coins": "1e9a4e", "wands": "e0402a", "cups": "2a7ae0", "swords": "a65ae0"}
const RANK_INDEX := {"page": 0, "knight": 1, "queen": 2, "king": 3, "legend": 3}
const DIMS := [
	{"H": 44, "leg": 14, "torso": 13, "tw": 11, "arm": 12, "head": 11, "legW": 4},
	{"H": 52, "leg": 17, "torso": 16, "tw": 16, "arm": 14, "head": 12, "legW": 5},
	{"H": 56, "leg": 18, "torso": 17, "tw": 13, "arm": 14, "head": 12, "legW": 4},
	{"H": 62, "leg": 20, "torso": 19, "tw": 17, "arm": 16, "head": 13, "legW": 5},
]
const BOSS_DIM := {"H": 98, "leg": 32, "torso": 30, "tw": 27, "arm": 26, "head": 19, "legW": 8}
const MATERIAL_BY_RANK := ["iron", "steel", "silver", "gold"]
## Default weapons per suit and rank (page, knight, queen, king).
const WEAPONS := {
	"coins": ["pouch", "mace", "scales", "scepter"],
	"wands": ["torch", "mace", "torch", "torch"],
	"cups": ["chalice", "dagger", "chalice", "chalice"],
	"swords": ["dagger", "sword", "sword", "sword"],
}
## Figures that fight from range (they throw or cast instead of running).
const RANGED := ["coin_squire", "spark_bearer", "blade_apprentice", "altar_server", "mistress_of_embers",
	"coin_thrower", "the_changer"]

static var _cache: Dictionary = {}


static func ramp(name: String) -> Array:
	return RAMPS[name].map(func(hex: String) -> Color: return Color(hex))


static func is_ranged(def_id: String) -> bool:
	return def_id in RANGED


## The look of a player figure (fusions: their built definition).
static func look_for_figure(definition: Dictionary) -> Dictionary:
	var rank := String(definition.get("rank", "page"))
	var r: int = RANK_INDEX.get(rank, 0)
	var suit := String(definition.get("suit", "coins"))
	var fusion: Dictionary = definition.get("fusion", {})
	var stage := int(fusion.get("stage", 0))
	var recipe := bool(definition.get("recipe", false))
	var legend := rank == "legend"
	return {
		"key": "fig:%s:%s:%d:%d" % [definition.get("id", ""), suit, stage, 1 if recipe else 0],
		"dim": DIMS[r],
		"metal": "gold" if legend or recipe else MATERIAL_BY_RANK[r],
		"cloth": suit,
		"skin": "skin",
		"gem": GEMS.get(suit, "1e9a4e"),
		"head": ["cap", "helm", "tiara", "crown"][r],
		"beard": r == 3,
		"long_hair": r == 2,
		"cape": [0, 12, 24, 32][r],
		"fur": r == 3,
		"weapon": WEAPONS.get(suit, WEAPONS["coins"])[r],
		"shield": r == 1,
		"gems_in_crown": legend or recipe or stage >= 2,
		"gild": stage,
		"shimmer": recipe,
		"eyes": null,
	}


## Enemies: corrupted versions of the figure bodies; a few special shapes.
static func look_for_enemy(definition: Dictionary) -> Dictionary:
	var id := String(definition.get("id", ""))
	if id in ["beggar_ghost", "greedmaw"]:
		return {"key": "ghost:" + id, "ghost": true, "tint": Color(1, 1, 1) if id == "beggar_ghost" else Color(1.1, 1.0, 0.55),
			"big": id == "greedmaw"}
	var boss := bool(definition.get("boss", false))
	var cost := int(definition.get("cost", 2))
	var r := 3 if boss else clampi(cost - 1, 0, 3)
	var weapon := "book"
	match id:
		"coin_thrower":
			weapon = "pouch"
		"vault_warden":
			weapon = "mace"
		"greedy_dragon":
			weapon = "sword"
		"mirror_coin":
			weapon = "scales"
		"the_changer":
			weapon = "chalice"
	return {
		"key": "enemy:" + id,
		"dim": BOSS_DIM if boss else DIMS[r],
		"metal": "bronze",
		"cloth": "blood",
		"skin": "sick",
		"gem": "ff3040",
		"head": "hood" if id in ["debt_collector", "coin_thrower", "the_changer"] else (["cap", "helm", "helm", "crown"][r]),
		"beard": false,
		"long_hair": false,
		"cape": 34 if boss else (12 if r >= 2 else 0),
		"fur": boss,
		"weapon": "scepter" if boss else weapon,
		"shield": id == "vault_warden",
		"gems_in_crown": boss,
		"gild": 0,
		"shimmer": false,
		"eyes": Color("ff4040"),
	}


static func build(look: Dictionary) -> Dictionary:
	var key: String = look["key"]
	if not _cache.has(key):
		_cache[key] = _build_ghost(look) if look.get("ghost", false) else _build_figure(look)
	return _cache[key]


# --- Figures ------------------------------------------------------------------------

static func _build_figure(look: Dictionary) -> Dictionary:
	var d: Dictionary = look["dim"]
	var metal := ramp(look["metal"])
	var cloth := ramp(look["cloth"])
	var skin := ramp(look["skin"])
	var gold := ramp("gold")
	var gem := Color(look["gem"])
	var gild := int(look["gild"])
	var parts := {"dim": d}
	var leg_w: int = d["legW"]
	var leg: int = d["leg"]

	# Legs: plate greaves with knee and boot
	for side in ["B", "F"]:
		var back: bool = side == "B"
		var tone := _back(metal) if back else metal
		var c := PixelCanvas.new(leg_w + 5, leg + 3)
		c.shade(1, 1, leg_w, leg - 5, tone)
		if not back:
			c.px(metal[3], 2, int(leg * 0.45), leg_w - 2, 1)
		var boot := _back(ramp("leather")) if back else ramp("leather")
		c.shade(1, leg - 5, leg_w, 4, boot)
		c.shade(1, leg - 2, leg_w + 2, 2, boot)
		c.px(gold[2] if gild >= 1 else boot[3], 1, leg - 5, leg_w, 1)
		parts["leg" + side] = c.outline().part(Vector2i(1 + leg_w / 2, 1))

	# Torso: filigree armor, gem on the chest, belt
	var tw: int = d["tw"]
	var th: int = d["torso"]
	var torso := PixelCanvas.new(tw + 4, th + 4)
	_torso_shape(torso, 2, 2, tw, th, metal)
	for y in range(3, th - 1, 3):
		for x in range(2, tw - 2, 2):
			torso.px(metal[3], 2 + x, 2 + y)
	var cx := 2 + tw / 2 - 1
	torso.px(metal[0], cx - 1, 2 + 4, 5, 5)
	torso.px(gem.darkened(0.25), cx, 2 + 5, 3, 3)
	torso.px(gem.lightened(0.45), cx, 2 + 5)
	torso.px(gem.darkened(0.6), cx + 2, 2 + 7)
	var belt := 2 + th - 3
	torso.px(gold[1] if gild >= 1 else metal[0], 2, belt, tw, 1)
	torso.px(gold[3] if gild >= 1 else metal[3], 3, belt)
	if gild >= 2:  # gilded shoulder line
		torso.px(gold[2], 3, 2, tw - 2, 1)
		torso.px(gold[3], 3, 2, 3, 1)
	parts["torso"] = torso.outline().part(Vector2i(2 + tw / 2, 2 + th))
	parts["torso_h"] = th

	# Head with headgear (canvas with headroom), pivot at the neck
	var hs: int = d["head"]
	var hw := hs + 18
	var hh := hs + 22
	var head := PixelCanvas.new(hw, hh)
	var hx := hw / 2
	var rr := hs / 2
	var hy := hh - 3 - rr
	var top := hy - rr
	if look["head"] == "hood":
		head.blob(hx - 1, hy - 1, rr + 2, rr + 2, cloth)
		head.blob(hx + 2, hy + 1, rr - 1, rr - 1, ramp("shadow"))
		var eye: Color = look["eyes"] if look["eyes"] != null else Color("ffd25a")
		head.px(eye, hx + 1, hy)
		head.px(eye, hx + 4, hy)
	else:
		head.blob(hx, hy, rr, rr, skin)
		head.px(skin[0], hx - rr + 1, hy, 2, 3)
		var eye_white := Color("f4ece0") if look["eyes"] == null else Color(look["eyes"])
		head.px(eye_white, hx + 2, hy - 1, 2, 1)
		head.px(Color("1a0e08") if look["eyes"] == null else Color(look["eyes"]).lightened(0.4), hx + 3, hy - 1)
		head.px(skin[0], hx + 1, hy - 3, 3, 1)
		head.px(skin[2], hx + rr, hy, 1, 2)
		head.px(skin[0], hx + 2, hy + 3, 2, 1)
		var hair := ramp("hair")
		if look["head"] != "helm":
			for y in range(top - 1, top + 4):
				for x in range(hx - rr, hx + rr - 1):
					if (x - hx) * (x - hx) + (y - hy) * (y - hy) <= (rr + 1) * (rr + 1):
						head.px(hair[2] if y == top - 1 else hair[1], x, y)
			head.px(hair[1], hx - rr, hy - 2, 3, 6)
		if look["long_hair"]:
			head.px(hair[1], hx - rr - 1, hy - 2, 3, hs + 2)
			head.px(hair[2], hx - rr - 1, hy - 2, 1, hs)
		if look["beard"]:
			head.shade(hx - 1, hy + 2, 6, 6, ramp("beard"))
		match look["head"]:
			"cap":
				head.shade(hx - rr, top - 2, hs + 1, 4, metal)
				head.px(metal[0], hx + rr - 1, top + 1, 3, 1)
				var feather := gem.lightened(0.2)
				head.px(feather, hx - rr - 1, top - 3, 4, 1)
				head.px(feather, hx - rr - 3, top - 4, 3, 1)
				head.px(feather, hx - rr - 4, top - 5, 2, 1)
			"helm":
				head.shade(hx - rr - 1, top - 2, hs + 2, hs + 1, metal)
				head.px(PixelCanvas.OUTLINE, hx, hy - 1, rr + 2, 1)
				head.px(PixelCanvas.OUTLINE, hx + 2, hy + 2, rr, 1)
				head.px(metal[3], hx - rr + 1, top, 1, hs - 3)
				for i in 5:
					head.px(gem if i % 2 == 0 else gem.darkened(0.3), hx - 2 + i, top - 4 - (i & 1))
				if look["eyes"] != null:
					head.px(Color(look["eyes"]), hx + 2, hy - 1, 2, 1)
			"tiara":
				_crown(head, hx, rr, hs, top, gold, 1, look["gems_in_crown"])
			"crown":
				_crown(head, hx, rr, hs, top, gold, 4 if look["gems_in_crown"] else 2, true)
	parts["head"] = head.outline().part(Vector2i(hx - 1, hh - 3))

	# Arms with hands
	var arm: int = d["arm"]
	for side in ["B", "F"]:
		var back: bool = side == "B"
		var c := PixelCanvas.new(6, arm + 3)
		var sleeve := _back(metal) if back else metal
		c.shade(1, 1, 4, arm - 4, sleeve)
		c.px(gold[2] if gild >= 1 else sleeve[3], 1, arm - 5, 4, 1)
		c.shade(1, arm - 4, 4, 4, _back(skin) if back else skin)
		parts["arm" + side] = c.outline().part(Vector2i(3, 2))
	parts["arm_len"] = arm - 3

	parts["weapon"] = _weapon(look["weapon"], metal, gold, gem)
	if look["shield"]:
		var s := PixelCanvas.new(12, 15)
		s.shade(1, 1, 10, 10, metal)
		s.px(metal[1], 2, 11, 8, 1)
		s.px(metal[1], 3, 12, 6, 1)
		s.px(metal[0], 5, 13, 2, 1)
		s.px(gem.darkened(0.2), 4, 3, 4, 4)
		s.px(gem.lightened(0.4), 4, 3)
		parts["shield"] = s.outline().part(Vector2i(6, 5))
	var cape_len: int = look["cape"]
	if cape_len > 0:
		var c := PixelCanvas.new(18, cape_len + 3)
		for y in cape_len:
			var cw := 6 + mini(9, y >> 1)
			var x0 := 16 - cw
			for x in cw:
				var tone := 0 if x == 0 else (1 if x < 2 else (1 if (x + y) % 7 == 0 else 2))
				c.px(cloth[tone], x0 + x, 1 + y)
			if look["fur"]:
				c.px(Color("f2ece4"), x0, 1 + y, 2, 1)
				if y % 3 == 1:
					c.px(Color("141012"), x0, 1 + y)
			elif gild >= 1:
				c.px(gold[2], x0, 1 + y)
		if look["fur"]:
			c.px(ramp("fur")[2], 9, 1, 8, 2)
		parts["cape"] = c.outline().part(Vector2i(14, 1))
	return parts


static func _torso_shape(c: PixelCanvas, x0: int, y0: int, tw: int, th: int, r: Array) -> void:
	for y in th:
		var q := float(y) / th
		var ww := tw - 2 if q < 0.12 else (tw if q < 0.45 else (tw - 2 if q < 0.7 else tw - 1))
		var xs := x0 + (tw - ww) / 2
		for x in ww:
			var u := float(x) / maxf(1.0, ww - 1)
			var tone := 2 if u < 0.18 else (0 if u > 0.82 else 1)
			if y == 0 or (q < 0.12 and u < 0.5):
				tone = mini(3, tone + 1)
			if y == th - 1:
				tone = 0
			c.px(r[tone], xs + x, y0 + y)
	c.px(r[3], x0 + 2, y0 + 1)


static func _crown(c: PixelCanvas, hx: int, rr: int, hs: int, top: int, col: Array, tall: int, gems: bool) -> void:
	c.shade(hx - rr, top - 2, hs, 3, col)
	for i in range(0, hs, 2):
		c.px(col[2], hx - rr + i, top - 2 - tall, 1, tall)
		c.px(col[3], hx - rr + i, top - 2 - tall)
	if gems:
		for i in range(1, hs - 1, 3):
			c.px(Color("e8284a") if i % 2 else Color("3a9aff"), hx - rr + i, top - 1)


static func _back(r: Array) -> Array:
	return [r[0], r[0], r[1], r[1]]


## Weapons; the pivot is the grip in the hand.
static func _weapon(kind: String, metal: Array, gold: Array, gem: Color) -> Dictionary:
	var wood := ramp("wood")
	var c: PixelCanvas
	var pivot: Vector2i
	match kind:
		"pouch":
			c = PixelCanvas.new(12, 12)
			c.blob(6, 7, 4, 3, ramp("leather"))
			c.px(ramp("leather")[0], 4, 4, 5, 1)
			c.px(gold[3], 5, 3, 2, 1)
			c.px(gold[2], 7, 3)
			pivot = Vector2i(6, 3)
		"mace":
			c = PixelCanvas.new(12, 26)
			c.shade(5, 8, 2, 17, wood)
			c.px(ramp("leather")[2], 5, 18, 2, 4)
			c.blob(6, 5, 4, 4, metal)
			for p in [Vector2i(1, 5), Vector2i(11, 5), Vector2i(6, 0), Vector2i(6, 10)]:
				c.px(metal[2], p.x, p.y)
			pivot = Vector2i(6, 20)
		"scales":
			c = PixelCanvas.new(22, 30)
			c.shade(10, 5, 2, 24, gold)
			c.px(gold[2], 2, 6, 18, 1)
			for x in [3, 18]:
				c.px(gold[3], x, 7, 1, 5)
				c.shade(x - 3, 12, 7, 2, gold)
			c.blob(11, 3, 2, 2, gold)
			pivot = Vector2i(11, 23)
		"scepter":
			c = PixelCanvas.new(14, 28)
			c.shade(6, 10, 2, 17, gold)
			c.blob(7, 7, 4, 4, gold)
			c.px(gold[0], 6, 6, 3, 3)
			c.px(gold[3], 6, 6)
			c.px(gold[2], 7, 0, 1, 3)
			c.px(gold[2], 6, 1, 3, 1)
			c.px(gem, 7, 7)
			pivot = Vector2i(7, 22)
		"torch":
			c = PixelCanvas.new(10, 28)
			c.shade(4, 8, 2, 19, wood)
			c.shade(3, 6, 4, 3, metal)
			c.px(Color("d8401a"), 3, 2, 4, 4)
			c.px(Color("ffa030"), 4, 1, 2, 4)
			c.px(Color("fff2a0"), 4, 3, 1, 2)
			pivot = Vector2i(5, 22)
		"chalice":
			c = PixelCanvas.new(12, 14)
			c.shade(2, 1, 8, 5, gold)
			c.px(gold[1], 3, 6, 6, 1)
			c.px(gold[2], 5, 7, 2, 3)
			c.shade(3, 10, 6, 2, gold)
			c.px(gem, 5, 3)
			c.px(Color("8c1a2a"), 3, 1, 6, 1)
			pivot = Vector2i(6, 8)
		"sword":
			c = PixelCanvas.new(10, 30)
			c.shade(4, 1, 3, 20, ramp("silver"))
			c.px(ramp("silver")[3], 4, 1, 1, 18)
			c.shade(1, 21, 8, 2, gold)
			c.shade(4, 23, 3, 5, ramp("leather"))
			c.px(gem, 5, 28)
			pivot = Vector2i(5, 25)
		"dagger":
			c = PixelCanvas.new(8, 16)
			c.shade(3, 1, 2, 8, ramp("silver"))
			c.shade(1, 9, 6, 2, gold)
			c.shade(3, 11, 2, 4, ramp("leather"))
			pivot = Vector2i(4, 12)
		_:  # ledger book
			c = PixelCanvas.new(12, 12)
			c.shade(1, 2, 10, 8, ramp("blood"))
			c.px(Color("e8dcc0"), 2, 3, 8, 1)
			c.px(gold[2], 5, 5, 2, 2)
			pivot = Vector2i(6, 6)
	return c.outline().part(pivot)


# --- Ghosts -------------------------------------------------------------------------

static func _build_ghost(look: Dictionary) -> Dictionary:
	var big: bool = look.get("big", false)
	var gw := 38 if big else 30
	var gh := 54 if big else 44
	var body := 44 if big else 34
	var c := PixelCanvas.new(gw, gh)
	var g := ramp("ghost").map(func(col: Color) -> Color: return col * look["tint"])
	for y in body:
		var w := mini(gw - 12, 7 + y)
		for x in w:
			var rx := gw / 2 - w / 2 + x
			if y > body - 7 and (x * 3 + y) % 4 == 0:
				continue
			var u := float(x) / maxf(1.0, w - 1)
			var tone := 3 if y < 3 else (2 if u < 0.2 else (0 if u > 0.8 else 1))
			c.px(g[tone], rx, 3 + y)
	var sh := ramp("shadow")
	c.blob(gw / 2 - 1, 11, 5, 5, sh)
	c.px(Color("9ef0ff"), gw / 2 - 4, 11)
	c.px(Color("ffffff"), gw / 2, 11)
	if big:  # a maw full of coins
		c.px(sh[0], gw / 2 - 6, 22, 12, 6)
		for i in 5:
			c.px(Color("ffe08a"), gw / 2 - 5 + i * 2, 24 + (i % 2))
	else:  # begging bowl
		c.shade(2, 22, 8, 3, ramp("wood"))
		c.px(Color("ffe08a"), 5, 21)
	var part := c.outline().part(Vector2i(gw / 2, gh - 7))
	return {"ghost": part, "dim": {"H": body, "tw": 16, "leg": 0}}


# --- Background ---------------------------------------------------------------------

## The coin vault: brick wall, arches with gold piles, pillars, stone floor.
static func vault(w: int, h: int, floor_y: int) -> ImageTexture:
	var c := PixelCanvas.new(w, h)
	c.px(Color("0d0a0c"), 0, 0, w, h)
	var bricks := [Color("1c1518"), Color("211a1c"), Color("181214"), Color("241c1e"), Color("1a1416")]
	for y in range(0, floor_y, 6):
		var off := -6 if (y / 6) % 2 else 0
		for bx in range(off, w, 12):
			c.px(bricks[absi(bx * 7 + y * 13) % 5], bx + 1, y + 1, 11, 5)
	var gold := ramp("gold")
	for ax in [w * 0.12, w * 0.5, w * 0.88]:
		var axi := int(ax)
		for yy in 70:
			var half := 18 if yy >= 18 else int(sqrt(18.0 * 18.0 - (18 - yy) * (18 - yy)))
			c.px(Color("08060a"), axi - half, floor_y - 70 + yy, half * 2, 1)
		for i in 40:
			var a := PI + i / 40.0 * PI
			c.px(Color("3a2c22"), int(axi + cos(a) * 19), int(floor_y - 52 + sin(a) * 19), 2, 2)
		_pile(c, axi, floor_y, 15, 9, gold)
	_pile(c, int(w * 0.3), floor_y + 2, 7, 4, gold)
	_pile(c, int(w * 0.68), floor_y + 2, 8, 5, gold)
	for y in range(floor_y, h):
		var t := float(y - floor_y) / maxf(1.0, h - floor_y)
		c.px(Color(0.094 - t * 0.04, 0.075 - t * 0.03, 0.08 - t * 0.03), 0, y, w, 1)
	for y in range(floor_y + 4, h, 7):
		c.px(Color("0e0b0d"), 0, y, w, 1)
	for fx in range(0, w, 23):
		c.px(Color("0e0b0d"), fx, floor_y + 4, 1, h - floor_y - 4)
	for i in 30:
		var cx := (i * 97) % w
		var cy := floor_y + 8 + (i * 31) % maxi(1, h - floor_y - 10)
		c.px(gold[2], cx, cy, 2, 1)
		c.px(gold[3], cx, cy)
	for pxx in [int(w * 0.31), int(w * 0.69)]:
		for y in floor_y:
			c.px(Color("2a2024"), pxx - 5, y, 10, 1)
			c.px(Color("3a2e30"), pxx - 5, y, 2, 1)
			c.px(Color("161012"), pxx + 4, y)
	return c.texture()


static func _pile(c: PixelCanvas, cx: int, cy: int, rx: int, ry: int, gold: Array) -> void:
	for yy in range(-ry, 1):
		for xx in range(-rx, rx + 1):
			if float(xx * xx) / (rx * rx) + float(yy * yy) / (ry * ry) > 1.0:
				continue
			var v := -float(xx) / rx - float(yy) / ry
			c.px(gold[3 if v > 0.9 else (2 if v > 0.1 else (1 if v > -0.6 else 0))], cx + xx, cy + yy)
			if ((xx * 31 + yy * 17) & 15) == 0:
				c.px(Color("fff4b8"), cx + xx, cy + yy)
