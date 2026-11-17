class_name CreatureArt
extends RefCounted
## Pixel art of the enemies: creatures of greed that look nothing like the
## court figures. Each is one sprite drawn facing right (the stage mirrors
## enemies). Returns {"body": part, "H": height, "W": width, "hand": Vector2,
## "float": bool} - "hand" is where projectiles start, relative to the feet.

const R := {
	"ghost": ["1c2630", "3a5060", "6a8a9a", "b8d8e0"],
	"goblin": ["1e2a14", "3e5a28", "6a8a3e", "9ab864"],
	"coat": ["140c1c", "2a1838", "44285a", "5e3c7a"],
	"black": ["08060a", "16121a", "26202c", "3a3242"],
	"gold": ["4a3208", "9a6a14", "d9a530", "ffe08a"],
	"silver": ["28324a", "5a6c8c", "9db0d0", "e2ecff"],
	"wood": ["1e1208", "3c2414", "5c3a20", "7e5430"],
	"iron": ["1e2024", "3e434c", "6b7380", "a9b2bf"],
	"stone": ["1a1a1e", "34343c", "54545e", "7a7a86"],
	"dragon": ["2a0808", "5a1414", "8c2420", "c8463a"],
	"belly": ["5a3a10", "a8742a", "d8aa4a", "f4d888"],
	"toad": ["1e2410", "3e4a1e", "667a32", "92a64c"],
	"leather": ["24160e", "4a2e1c", "704a2e", "94683f"],
	"red": ["2a0608", "5a0c12", "8c1a22", "c03038"],
}
const EYE_RED := Color("ff4040")
const EYE_GOLD := Color("ffd25a")
const EYE_CYAN := Color("9ef0ff")
const TOOTH := Color("f2ece0")

static var _cache: Dictionary = {}


static func ramp(name: String) -> Array:
	return R[name].map(func(hex: String) -> Color: return Color(hex))


static func has_art(id: String) -> bool:
	return HandmadeArt.has_creature(id) or id in ["beggar_ghost", "debt_collector", "the_changer", "greedmaw",
		"vault_warden", "coin_thrower", "greedy_dragon", "mirror_coin", "boss_tax_collector", "boss_golden_wall"]


static func build(id: String) -> Dictionary:
	if not _cache.has(id):
		_cache[id] = _make(id)
	return _cache[id]


static func _make(id: String) -> Dictionary:
	if HandmadeArt.has_creature(id):  # pixel-by-pixel art wins over drawn art
		var made := HandmadeArt.creature(id)
		return _result(made["canvas"], made["feet"], made["hand"])
	match id:
		"debt_collector":
			return _debt_collector()
		"coin_thrower":
			return _coin_thrower()
		"the_changer":
			return _the_changer()
		"greedmaw":
			return _greedmaw()
		"vault_warden":
			return _vault_warden()
		"greedy_dragon":
			return _greedy_dragon()
		"mirror_coin":
			return _mirror_coin()
		"boss_tax_collector":
			return _boss_tax_collector()
		"boss_golden_wall":
			return _boss_golden_wall()
	return _beggar_ghost()


static func _result(c: PixelCanvas, pivot: Vector2i, hand: Vector2, floating := false) -> Dictionary:
	c.outline()
	return {"body": c.part(pivot), "H": pivot.y, "W": c.w, "hand": hand, "float": floating}


# --- Normal enemies ------------------------------------------------------------------

## Bettlergeist: a tattered ghost dragging a chain, holding out a bowl.
static func _beggar_ghost() -> Dictionary:
	var c := PixelCanvas.new(32, 46)
	var g := ramp("ghost")
	for y in 34:
		var w := mini(18, 6 + y)
		for x in w:
			if y > 27 and (x * 3 + y) % 4 == 0:
				continue
			var u := float(x) / maxf(1.0, w - 1)
			c.px(g[3 if y < 3 else (2 if u < 0.2 else (0 if u > 0.8 else 1))], 16 - w / 2 + x, 4 + y)
	c.blob(17, 12, 5, 5, ramp("black"))
	c.px(EYE_CYAN, 15, 12)
	c.px(Color.WHITE, 19, 12)
	c.px(g[0], 17, 16, 3, 1)
	for i in 6:  # chain trailing behind
		c.px(ramp("iron")[2 if i % 2 else 1], 3 + i * 2, 38 + (i % 2), 2, 1)
	c.shade(22, 22, 8, 3, ramp("wood"))
	c.px(ramp("gold")[3], 25, 21)
	c.shade(20, 22, 3, 3, g)
	return _result(c, Vector2i(16, 40), Vector2(10, -20), true)


## Schuldeneintreiber: a hunched goblin in a long coat and top hat, ledger and quill.
static func _debt_collector() -> Dictionary:
	var c := PixelCanvas.new(36, 48)
	var skin := ramp("goblin")
	var coat := ramp("coat")
	c.shade(12, 38, 3, 8, ramp("black"))
	c.shade(18, 38, 3, 8, ramp("black"))
	c.px(ramp("black")[2], 18, 45, 6, 1)
	c.px(ramp("black")[2], 10, 45, 5, 1)
	c.blob(16, 30, 9, 10, coat)  # hunched coat
	c.px(coat[0], 9, 34, 14, 6)
	for y in range(36, 41):
		c.px(coat[1 if y % 2 else 2], 9 + (y - 36), y, 2, 1)
	c.blob(23, 18, 7, 6, skin)  # head pushed forward
	c.px(skin[1], 29, 19, 4, 2)  # long nose
	c.px(skin[0], 32, 20, 1, 1)
	c.px(EYE_GOLD, 25, 16, 2, 1)
	c.px(Color.BLACK, 26, 16)
	c.px(skin[0], 24, 22, 4, 1)  # thin grin
	c.px(TOOTH, 25, 22)
	c.px(skin[2], 17, 14, 2, 1)  # ear
	c.px(skin[1], 16, 13, 2, 1)
	c.shade(17, 6, 11, 7, ramp("black"))  # top hat
	c.px(ramp("black")[2], 15, 12, 15, 1)
	c.px(ramp("gold")[2], 17, 10, 11, 1)
	c.shade(25, 27, 8, 6, ramp("red"))  # ledger
	c.px(Color("e8dcc0"), 26, 28, 6, 1)
	c.px(ramp("gold")[2], 28, 30, 2, 2)
	c.px(Color("e8dcc0"), 31, 22, 1, 6)  # quill
	c.px(Color.WHITE, 31, 21, 2, 2)
	return _result(c, Vector2i(16, 46), Vector2(12, -18))


## Münzwerfer: a small goblin with a coin sack on its back and a sling.
static func _coin_thrower() -> Dictionary:
	var c := PixelCanvas.new(34, 40)
	var skin := ramp("goblin")
	c.blob(9, 22, 7, 8, ramp("leather"))  # sack
	for p in [Vector2i(6, 16), Vector2i(10, 15), Vector2i(8, 18)]:
		c.px(ramp("gold")[3], p.x, p.y, 2, 1)
	c.shade(15, 31, 3, 7, skin)
	c.shade(20, 31, 3, 7, skin)
	c.blob(18, 25, 6, 7, ramp("leather"))
	c.px(ramp("leather")[0], 13, 28, 11, 1)
	c.blob(21, 14, 6, 6, skin)
	c.px(skin[3], 14, 9, 3, 2)  # big ear
	c.px(skin[2], 12, 8, 2, 2)
	c.px(EYE_GOLD, 23, 12, 2, 2)
	c.px(Color.BLACK, 24, 12)
	c.px(TOOTH, 24, 17, 2, 1)
	c.px(skin[1], 26, 14, 2, 1)
	c.px(ramp("leather")[1], 25, 20, 2, 7)  # raised arm with sling
	c.px(ramp("leather")[2], 26, 6, 1, 15)
	c.blob(27, 5, 2, 2, ramp("gold"))
	return _result(c, Vector2i(18, 38), Vector2(9, -33))


## Der Wechsler: a floating two-faced mask, half gold and half black, with
## coins circling and a tattered cloak below.
static func _the_changer() -> Dictionary:
	var c := PixelCanvas.new(38, 50)
	var cloak := ramp("coat")
	for y in range(20, 46):
		var w := 14 - (y - 20) / 4
		for x in w:
			if y > 38 and (x + y) % 3 == 0:
				continue
			c.px(cloak[1 if x % 3 else 2], 19 - w / 2 + x, y)
	var gold := ramp("gold")
	var black := ramp("black")
	for y in range(-10, 11):
		for x in range(-9, 10):
			if x * x / 81.0 + y * y / 110.0 > 1.0:
				continue
			var col: Color = (gold[2] if x < -4 else gold[1]) if x < 0 else (black[1] if x < 5 else black[0])
			if y < -6:
				col = gold[3] if x < 0 else black[2]
			c.px(col, 19 + x, 14 + y)
	c.px(EYE_RED, 14, 12, 3, 2)
	c.px(Color.WHITE, 22, 12, 3, 2)
	c.px(black[0], 13, 19, 5, 1)
	c.px(gold[3], 21, 19, 5, 1)
	for p in [Vector2i(3, 10), Vector2i(34, 18), Vector2i(5, 30), Vector2i(32, 34)]:
		c.blob(p.x, p.y, 2, 2, gold)
	c.shade(30, 26, 3, 4, ramp("goblin"))  # bony hand with a coin
	c.blob(33, 25, 2, 2, gold)
	return _result(c, Vector2i(19, 48), Vector2(14, -24), true)


## Gierschlund: a treasure chest mimic with teeth, tongue and claws.
static func _greedmaw() -> Dictionary:
	var c := PixelCanvas.new(38, 38)
	var wood := ramp("wood")
	var iron := ramp("iron")
	for p in [6, 12, 22, 28]:  # claws
		c.px(ramp("black")[2], p, 32, 3, 4)
		c.px(TOOTH, p + 2, 35)
	c.shade(4, 18, 30, 15, wood)  # chest body
	c.px(iron[2], 4, 22, 30, 2)
	c.px(iron[2], 4, 29, 30, 2)
	c.shade(17, 22, 4, 5, ramp("gold"))  # lock
	c.px(ramp("red")[1], 6, 13, 26, 6)  # open maw
	c.px(ramp("red")[3], 20, 15, 10, 4)  # tongue
	c.px(ramp("red")[2], 28, 18, 4, 6)
	for x in range(6, 32, 3):
		c.px(TOOTH, x, 13, 2, 2)
		c.px(TOOTH, x + 1, 17, 2, 2)
	for i in 5:
		c.px(ramp("gold")[3], 9 + i * 4, 16)
	for y in 9:  # lid tilted open
		c.px(wood[2] if y < 2 else wood[1], 3 + y, 4 + y / 2 + 0, 31 - y, 1)
	c.px(iron[2], 3, 7, 31, 1)
	c.px(EYE_GOLD, 25, 5, 2, 2)
	c.px(EYE_GOLD, 30, 6, 2, 2)
	return _result(c, Vector2i(19, 36), Vector2(14, -14))


## Tresorwächter: a stone golem with a round vault door in its chest and huge fists.
static func _vault_warden() -> Dictionary:
	var c := PixelCanvas.new(46, 62)
	var stone := ramp("stone")
	var iron := ramp("iron")
	c.shade(12, 46, 8, 14, stone)
	c.shade(26, 46, 8, 14, stone)
	c.shade(6, 18, 34, 30, stone)
	for y in range(22, 46, 6):  # stone blocks
		c.px(stone[0], 6, y, 34, 1)
	c.blob(23, 32, 9, 9, iron)  # vault door
	c.blob(23, 32, 6, 6, ramp("gold"))
	for i in 6:
		var a := i / 6.0 * TAU
		c.px(iron[0], 23 + int(cos(a) * 5), 32 + int(sin(a) * 5), 2, 2)
	c.px(iron[3], 22, 31, 2, 2)
	c.shade(14, 6, 18, 13, stone)  # head
	c.px(Color.BLACK, 17, 11, 13, 3)
	c.px(EYE_CYAN, 19, 12, 9, 1)
	c.shade(0, 22, 8, 20, stone)  # arms
	c.shade(38, 22, 8, 20, stone)
	c.shade(0, 40, 9, 10, iron)  # fists
	c.shade(37, 40, 9, 10, iron)
	return _result(c, Vector2i(23, 60), Vector2(18, -40))


## Gieriger Drache: a small red dragon with a gold belly, folded wings and horns.
static func _greedy_dragon() -> Dictionary:
	var c := PixelCanvas.new(52, 46)
	var red := ramp("dragon")
	var belly := ramp("belly")
	for i in 14:  # tail
		c.px(red[1 if i % 3 else 2], 2 + i, 34 + int(sin(i * 0.5) * 3), 3, 2)
	c.px(red[3], 1, 33, 2, 2)
	for p in [14, 20, 28, 34]:  # legs
		c.shade(p, 36, 4, 8, red)
		c.px(TOOTH, p + 3, 43)
	c.blob(24, 30, 13, 9, red)  # body
	c.blob(26, 34, 9, 5, belly)
	for i in 10:  # folded wing
		c.px(red[0], 12 + i, 18 + i / 2, 12 - i, 1)
	c.px(red[2], 12, 18, 12, 1)
	for y in range(8, 24):  # neck
		c.px(red[1], 32 + (24 - y) / 3, y, 6, 1)
		c.px(belly[2], 36 + (24 - y) / 3, y, 2, 1)
	c.blob(40, 9, 7, 5, red)  # head
	c.px(red[2], 44, 10, 6, 3)  # snout
	c.px(TOOTH, 45, 13, 1, 1)
	c.px(TOOTH, 48, 13, 1, 1)
	c.px(EYE_GOLD, 41, 7, 2, 1)
	c.px(red[3], 36, 2, 2, 3)  # horns
	c.px(red[3], 34, 1, 2, 2)
	c.px(Color("ffa030"), 50, 11, 2, 1)  # ember from the nostril
	return _result(c, Vector2i(26, 44), Vector2(22, -34))


## Spiegelmünze: a floating silver coin with a sly face in its mirror and bat wings.
static func _mirror_coin() -> Dictionary:
	var c := PixelCanvas.new(44, 42)
	var silver := ramp("silver")
	for i in 7:  # wings
		c.px(ramp("black")[2], 2 + i, 12 + i, 8 - i, 2)
		c.px(ramp("black")[2], 34, 12 + i, 8 - i, 2)
	c.blob(22, 18, 13, 13, silver)
	c.blob(22, 18, 10, 10, [silver[1], silver[2], silver[3], Color.WHITE])
	c.px(EYE_RED, 18, 15, 2, 2)
	c.px(EYE_RED, 25, 15, 2, 2)
	c.px(silver[0], 17, 22, 10, 1)
	c.px(silver[0], 26, 21)
	c.px(silver[0], 17, 21)
	c.px(Color.WHITE, 15, 10, 3, 1)
	c.px(silver[0], 21, 32, 2, 6)  # dangling chain
	return _result(c, Vector2i(22, 40), Vector2(14, -22), true)


# --- Bosses (2-3 slots wide) -----------------------------------------------------------

## Der Steuereintreiber: a bloated toad-goblin king on a coin sack, holding a ledger.
static func _boss_tax_collector() -> Dictionary:
	var c := PixelCanvas.new(66, 76)
	var toad := ramp("toad")
	var gold := ramp("gold")
	c.blob(30, 66, 24, 9, ramp("leather"))  # coin sack seat
	for i in 9:
		c.px(gold[3], 12 + i * 5, 60 + (i % 3), 3, 1)
	c.blob(30, 46, 22, 19, toad)  # belly
	c.blob(32, 50, 14, 12, [toad[1], toad[2], toad[3], Color("c8d47a")])
	c.blob(36, 20, 14, 12, toad)  # head
	c.px(toad[0], 30, 26, 20, 2)  # wide mouth
	c.px(TOOTH, 34, 26, 2, 1)
	c.px(TOOTH, 44, 26, 2, 1)
	c.blob(32, 15, 3, 3, [Color("b8b090"), Color("e8e0b0"), Color("f8f0d0"), Color.WHITE])
	c.blob(43, 15, 3, 3, [Color("b8b090"), Color("e8e0b0"), Color("f8f0d0"), Color.WHITE])
	c.px(Color.BLACK, 33, 15, 2, 2)
	c.px(Color.BLACK, 44, 15, 2, 2)
	c.shade(26, 3, 20, 5, gold)  # crown
	for i in range(0, 20, 4):
		c.px(gold[3], 26 + i, 0, 2, 3)
	c.px(Color("e8284a"), 35, 4, 2, 2)
	c.shade(48, 36, 14, 11, ramp("red"))  # tax ledger
	c.px(Color("e8dcc0"), 49, 37, 12, 1)
	for y in range(39, 46, 2):
		c.px(Color("e8dcc0"), 50, y, 9, 1)
	c.shade(10, 38, 6, 12, toad)  # arm
	return _result(c, Vector2i(32, 74), Vector2(20, -38))


## Die Goldene Mauer: a wall of gold bricks come alive, with a carved face.
static func _boss_golden_wall() -> Dictionary:
	var c := PixelCanvas.new(84, 94)
	var gold := ramp("gold")
	var stone := ramp("stone")
	for y in range(8, 92, 7):
		var off := 0 if (y / 7) % 2 else 6
		var inset := maxi(0, 14 - y / 3)
		for x in range(4 + inset + off - 6, 80 - inset, 12):
			c.shade(maxi(x, 4 + inset), y, mini(11, 80 - inset - maxi(x, 4 + inset)), 6, gold)
	for p in [Vector2i(20, 30), Vector2i(60, 52), Vector2i(34, 70)]:  # cracks
		for i in 6:
			c.px(gold[0], p.x + i, p.y + (i % 3), 1, 2)
	c.px(stone[0], 26, 30, 12, 6)  # eye sockets
	c.px(stone[0], 48, 30, 12, 6)
	c.px(EYE_RED, 29, 32, 6, 2)
	c.px(EYE_RED, 51, 32, 6, 2)
	c.px(stone[0], 30, 52, 26, 8)  # mouth
	for x in range(31, 55, 4):
		c.px(TOOTH, x, 52, 2, 3)
	c.shade(0, 44, 10, 30, gold)  # stubby arms
	c.shade(74, 44, 10, 30, gold)
	return _result(c, Vector2i(42, 92), Vector2(30, -50))
