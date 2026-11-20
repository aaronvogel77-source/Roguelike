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
	"pale": ["4a3e44", "8c7e86", "c8bcc2", "eee6ea"],
	"drowned": ["1a3a3a", "3a6a66", "6a9a92", "a8d0c4"],
	"fire": ["5a1404", "b03a10", "f07a20", "ffd060"],
	"spirit_gold": ["6a4a10", "c89a30", "f0d070", "fff8d0"],
	"spirit_water": ["1a3a6a", "3a6aa8", "7aaae0", "d0ecff"],
	"iron": ["1e2024", "3e434c", "6b7380", "a9b2bf"],
	"steel": ["24303c", "4c5c6e", "8094aa", "c8d6e6"],
	"silver": ["28324a", "5a6c8c", "9db0d0", "e2ecff"],
	"gold": ["4a3208", "9a6a14", "d9a530", "ffe08a"],
	"ash": ["141214", "2a2628", "48424a", "6e666e"],
	"leather": ["24160e", "4a2e1c", "704a2e", "94683f"],
	"wood": ["1e1208", "3c2414", "5c3a20", "7e5430"],
	"hair": ["1a100a", "3a2414", "5c3a20", "7a5230"],
	"beard": ["2a2420", "6a625a", "a8a096", "d8d2c8"],
	"seaweed": ["0e2a1a", "1e4a2a", "3a7a3e", "6aa85a"],
	"fur": ["3a3430", "8a8278", "d8d0c4", "ffffff"],
	"linen": ["6a6458", "b0a890", "e0d8c0", "fffaf0"],
	"judge": ["0a080c", "1c1820", "302a36", "4a4252"],
	"sea": ["0e2a34", "1e4a5a", "3a7a86", "6aaab0"],
	"flame": ["8a1a04", "d8401a", "ffa030", "fff2a0"],
	"ghost": ["1c2630", "3a5060", "6a8a9a", "b8d8e0"],
	"shadow": ["0a080d", "1b1722", "2b2535", "3d3449"],
	"coins": ["0e1e14", "1e3c26", "2f5e3a", "4c8456"],
	"wands": ["2a0c10", "5a1820", "8c2a30", "b8464a"],
	"cups": ["0c1a2e", "1a3458", "2c5288", "4a78b8"],
	"swords": ["1a1626", "342c4a", "54487a", "7a6ca8"],
	# Enemies (fallback bodies): corrupted bronze, sickly skin, dark red cloth
	"bronze": ["1e140a", "4a3218", "7a5428", "a87e44"],
	"sick": ["1e2418", "3e4a32", "66764e", "94a274"],
	"blood": ["1e0608", "3c0c10", "601820", "88282e"],
	# Legendary skins
	"charcoal": ["0e0a08", "241a16", "3a2c26", "54443a"],
	"lava": ["8a1a04", "e04010", "ff9a20", "fff0a0"],
	"ice": ["2a5a8a", "6aa8d8", "b8e4ff", "ffffff"],
	"frost": ["1c2e4a", "3a5a8a", "8ab0dc", "dcefff"],
	"void": ["06040c", "120c22", "221838", "3a2c5a"],
	"polished": ["7a5410", "d8a830", "ffe070", "fffbe0"],
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
## Figures that fight from range (they throw or cast instead of running).
const RANGED := ["coin_squire", "spark_bearer", "blade_apprentice", "altar_server", "mistress_of_embers",
	"coin_thrower", "the_changer"]
## Each figure's own design, matching its name and ability. Keys override the
## rank defaults: torso (plate/robe/gown/leather/bare), head, weapon, shield,
## skin, robe (cloth ramp for robes), cape, extras (satchel, golden_hand, drip,
## halo, apron, collar).
const SPECS := {
	# Coins: servants, gold armour, scales and the golden king
	"coin_squire": {"torso": "leather", "head": "cap", "weapon": "pouch", "extras": ["satchel"]},
	"gold_armored": {"torso": "plate", "head": "helm", "weapon": "mace", "shield": "tower", "metal": "gold", "bulk_by_gold": true},
	"golden_scales": {"torso": "gown", "head": "tiara", "weapon": "scales", "long_hair": true},
	"king_midas": {"torso": "robe", "robe": "gold", "head": "crown", "beard": true, "weapon": "orb", "extras": ["golden_hand"], "cape": 32, "fur": true},
	# Wands: torchbearer, berserker, ember witch, the burnt king
	"spark_bearer": {"torso": "leather", "head": "hood", "weapon": "torch"},
	"enraged_one": {"torso": "bare", "head": "flame_hair", "weapon": "club", "shield": "none", "cape": 0},
	"mistress_of_embers": {"torso": "gown", "head": "flame_crown", "weapon": "ember_staff", "long_hair": true},
	"ash_king": {"torso": "plate", "metal": "ash", "head": "ash_crown", "beard": true, "weapon": "flame_sword", "cape": 32},
	# Cups: acolyte, vampire knight, priestess, the drowned king
	"altar_server": {"torso": "robe", "robe": "linen", "head": "none", "weapon": "censer"},
	"blood_drinker": {"torso": "plate", "metal": "ash", "head": "none", "skin": "pale", "eyes": "ff3040", "weapon": "goblet", "shield": "none", "cape": 18, "extras": ["collar"]},
	"chalice_of_return": {"torso": "gown", "head": "veil", "weapon": "chalice", "long_hair": true},
	"drowned_king": {"torso": "robe", "robe": "sea", "head": "seaweed_crown", "skin": "drowned", "beard": true, "weapon": "trident", "extras": ["drip"], "cape": 30},
	# Swords: knife thrower, executioner, duelist, the judge
	"blade_apprentice": {"torso": "leather", "head": "headband", "weapon": "knives"},
	"executioner": {"torso": "bare", "head": "exec_hood", "weapon": "axe", "shield": "none", "cape": 0, "extras": ["apron"]},
	"clear_blade": {"torso": "plate", "metal": "silver", "head": "feather_hat", "weapon": "rapier", "long_hair": true},
	"the_judge": {"torso": "robe", "robe": "judge", "head": "wig", "weapon": "greatsword", "cape": 30},
	# Aces: spirits of their suit
	"ace_of_coins": {"torso": "robe", "robe": "gold", "head": "crown", "skin": "spirit_gold", "weapon": "orb", "extras": ["halo", "golden_hand"], "cape": 34},
	"ace_of_wands": {"torso": "plate", "metal": "gold", "head": "flame_crown", "skin": "fire", "weapon": "flame_sword", "extras": ["halo"], "cape": 34},
	"ace_of_cups": {"torso": "gown", "head": "veil", "skin": "spirit_water", "weapon": "chalice", "long_hair": true, "extras": ["halo", "drip"]},
	"ace_of_swords": {"torso": "plate", "metal": "silver", "head": "winged_helm", "weapon": "crystal_sword", "extras": ["halo"], "cape": 34},
	# Secret recipes
	"midas_scales": {"torso": "robe", "robe": "gold", "head": "crown", "beard": true, "weapon": "scales", "extras": ["golden_hand", "halo"], "cape": 34, "fur": true},
	"ash_flood_king": {"torso": "plate", "metal": "ash", "head": "ash_crown", "skin": "drowned", "beard": true, "weapon": "trident", "extras": ["drip"], "cape": 34},
}

## Legendary skins from the vault mirror: completely new parts plus an
## animated effect theme ("fx"), drawn by the FigureActor.
const SKINS := {
	"skin_hell_executioner": {"skin": "charcoal", "torso": "bare", "head": "spike_helm", "weapon": "hell_axe",
		"extras": ["lava_cracks", "apron"], "eyes": "ff8020", "cape": 0, "fx": "hellfire"},
	"skin_frost_king": {"skin": "frost", "robe": "ice", "head": "ice_crown", "weapon": "ice_trident",
		"extras": ["frost_beard"], "cloth": "frost", "cape": 32, "eyes": "b8e4ff", "fx": "frost"},
	"skin_star_judge": {"robe": "void", "head": "void_hood", "weapon": "void_greatsword", "extras": ["starry"],
		"cloth": "void", "cape": 32, "eyes": "c080ff", "skin": "void", "fx": "void"},
	"skin_sun_midas": {"torso": "plate", "metal": "polished", "robe": "polished", "head": "ray_crown",
		"weapon": "sun_scepter", "extras": ["golden_hand", "light_wings"], "cape": 0, "fur": false, "fx": "sun"},
}
## Theme colours of the skin effects (trails, sparks, banner).
const FX_COLORS := {
	"hellfire": ["ff5a10", "ffd060"], "frost": ["8ad0ff", "ffffff"],
	"void": ["9a50ff", "e0c0ff"], "sun": ["ffd040", "fffbe0"],
}

static var _cache: Dictionary = {}
## The player's gold, so gold-dependent looks (Gold-Armored) can grow with it.
static var gold_hint := 0


static func ramp(name: String) -> Array:
	return RAMPS[name].map(func(hex: String) -> Color: return Color(hex))


static func is_ranged(def_id: String) -> bool:
	return def_id in RANGED


## Armour bulk of the Gold-Armored by gold owned (0 thin ... 3 massive).
static func gold_bulk(gold: int) -> int:
	return 3 if gold >= 25 else (2 if gold >= 12 else (1 if gold >= 5 else 0))


## The look of a player figure (fusions: their built definition).
static func look_for_figure(definition: Dictionary) -> Dictionary:
	var rank := String(definition.get("rank", "page"))
	var r: int = RANK_INDEX.get(rank, 0)
	var suit := String(definition.get("suit", "coins"))
	var id := String(definition.get("id", ""))
	var fusion: Dictionary = definition.get("fusion", {})
	var stage := int(fusion.get("stage", 0))
	var recipe := bool(definition.get("recipe", false))
	var legend := rank == "legend"
	var spec: Dictionary = SPECS.get(id, {})
	var bulk := gold_bulk(gold_hint) if spec.get("bulk_by_gold", false) else 0
	var look := {
		"dim": DIMS[r],
		"metal": "gold" if legend or recipe else MATERIAL_BY_RANK[r],
		"cloth": suit,
		"skin": "skin",
		"gem": GEMS.get(suit, "1e9a4e"),
		"head": ["cap", "helm", "tiara", "crown"][r],
		"torso": "plate",
		"robe": suit,
		"beard": r == 3,
		"long_hair": r == 2,
		"cape": [0, 12, 24, 32][r],
		"fur": r == 3,
		"weapon": "sword",
		"shield": "round" if r == 1 else "none",
		"gems_in_crown": legend or recipe or stage >= 2,
		"gild": stage,
		"shimmer": recipe,
		"eyes": null,
		"extras": [],
		"bulk": bulk,
		"bulky": spec.get("bulk_by_gold", false),
	}
	for key in spec:
		if key != "bulk_by_gold":
			look[key] = spec[key]
	var skin_id := String(Cosmetics.skins.get(id, ""))
	var skin: Dictionary = SKINS.get(skin_id, {})
	for key in skin:
		look[key] = skin[key]
	if stage > 0 and fusion.has("parts"):
		_fuse_look(look, fusion)
	# Hand-made pixel art replaces the drawn parts: a skin's own art first,
	# fusions keep the main figure's head and body (weapons come from the partner).
	if skin_id != "" and HandmadeArt.has(skin_id):
		look["handmade"] = skin_id
	elif HandmadeArt.has(id):
		look["handmade"] = id
	if stage > 0:
		look["handmade_only"] = ["head", "torso"]
	if look["eyes"] is String:
		look["eyes"] = Color(look["eyes"])
	look["key"] = "fig:%s:%s:%d:%d:%d:%s:%s" % [id, suit, stage, 1 if recipe else 0, bulk, ",".join(fusion.get("parts", [])), skin_id]
	return look


## A fusion keeps the main figure's body (torso, head, skin, robe, cape) and
## takes the weapon, shield and extras of the partner; a third part lends its
## cape, a fourth its shield or trinkets. Every part keeps its own colours.
## Each stage makes the figure a little taller and broader.
static func _fuse_look(look: Dictionary, fusion: Dictionary) -> void:
	var parts: Array = fusion["parts"]
	var suits: Array = fusion.get("suits", [])
	var ranks: Array = fusion.get("part_ranks", [])
	var stage := int(fusion.get("stage", parts.size() - 1))
	var partner := String(fusion.get("partner", parts[1]))
	var partner_index := maxi(parts.find(partner), 1)
	var others: Array = []
	for i in range(1, parts.size()):
		if i != partner_index:
			others.append(i)
	look["grow"] = stage
	var colours := func(i: int) -> Array:
		var spec: Dictionary = SPECS.get(parts[i], {})
		var r: int = RANK_INDEX.get(ranks[i] if i < ranks.size() else "page", 0)
		var metal := String(spec.get("metal", MATERIAL_BY_RANK[r]))
		return [metal, GEMS.get(suits[i] if i < suits.size() else "coins", "1e9a4e"), r]
	# Partner: weapon, shield and trinkets in its own metal and gem.
	var p_spec: Dictionary = SPECS.get(partner, {})
	var p_col: Array = colours.call(partner_index)
	look["weapon"] = p_spec.get("weapon", "sword")
	look["weapon_metal"] = p_col[0]
	look["weapon_gem"] = p_col[1]
	var p_shield := String(p_spec.get("shield", "round" if p_col[2] == 1 else "none"))
	if p_shield != "none":
		look["shield"] = p_shield
		look["shield_metal"] = p_col[0]
		look["shield_gem"] = p_col[1]
	var extras: Array = look.get("extras", []).duplicate()
	for extra in p_spec.get("extras", []):
		if extra in ["satchel", "golden_hand", "drip", "halo"] and not extra in extras:
			extras.append(extra)
	# Third part: its cloak (in its suit colour), fourth: shield or trinkets.
	if others.size() >= 1:
		var i: int = others[0]
		look["cape"] = maxi(int(look.get("cape", 0)), 26)
		look["cape_cloth"] = suits[i] if i < suits.size() else look["cloth"]
	if others.size() >= 2:
		var i: int = others[1]
		var spec: Dictionary = SPECS.get(parts[i], {})
		var col: Array = colours.call(i)
		var shield := String(spec.get("shield", "round" if col[2] == 1 else "none"))
		if shield != "none" and not look.has("shield_metal"):
			look["shield"] = shield
			look["shield_metal"] = col[0]
			look["shield_gem"] = col[1]
		for extra in spec.get("extras", []):
			if extra in ["satchel", "golden_hand", "drip", "halo"] and not extra in extras:
				extras.append(extra)
	look["extras"] = extras


## Enemies without their own creature art: corrupted figure bodies.
static func look_for_enemy(definition: Dictionary) -> Dictionary:
	var id := String(definition.get("id", ""))
	var boss := bool(definition.get("boss", false))
	var cost := int(definition.get("cost", 2))
	var r := 3 if boss else clampi(cost - 1, 0, 3)
	return {
		"key": "enemy:" + id,
		"dim": BOSS_DIM if boss else DIMS[r],
		"metal": "bronze", "cloth": "blood", "robe": "blood", "skin": "sick", "gem": "ff3040",
		"head": ["hood", "helm", "helm", "crown"][r], "torso": "plate",
		"beard": false, "long_hair": false,
		"cape": 34 if boss else (12 if r >= 2 else 0), "fur": boss,
		"weapon": "scepter" if boss else "book", "shield": "none",
		"gems_in_crown": boss, "gild": 0, "shimmer": false, "eyes": Color("ff4040"), "extras": [], "bulk": 0,
	}


static func build(look: Dictionary) -> Dictionary:
	var key: String = look["key"]
	if not _cache.has(key):
		_cache[key] = _build_figure(look)
	return _cache[key]


# --- Figures ------------------------------------------------------------------------

static func _build_figure(look: Dictionary) -> Dictionary:
	var d: Dictionary = look["dim"].duplicate()
	var grow := int(look.get("grow", 0))
	if grow > 0:  # fusions: a little taller and broader per stage
		d["H"] = int(d["H"]) + grow * 3
		d["leg"] = int(d["leg"]) + grow
		d["torso"] = int(d["torso"]) + grow
		d["tw"] = int(d["tw"]) + grow
		d["arm"] = int(d["arm"]) + (grow + 1) / 2
		d["legW"] = int(d["legW"]) + (1 if grow >= 2 else 0)
	var bulk := int(look.get("bulk", 0))
	if look.get("bulky", false):  # Gold-Armored: slim with little gold, massive with a lot
		d["tw"] = int(d["tw"]) - 3 + bulk * 3
		d["legW"] = int(d["legW"]) - 1 + (bulk + 1) / 2
		d["arm"] = int(d["arm"]) + bulk / 2
	var metal := ramp(look["metal"])
	var cloth := ramp(look["cloth"])
	var skin := ramp(look["skin"])
	var gold := ramp("gold")
	var gem := Color(look["gem"])
	var gild := int(look["gild"])
	var extras: Array = look.get("extras", [])
	var torso_kind: String = look.get("torso", "plate")
	var robe := ramp(look.get("robe", look["cloth"]))
	var parts := {"dim": d}
	var leg_w: int = d["legW"]
	var leg: int = d["leg"]

	# Legs (covered by robes and gowns, so they stay plain there)
	for side in ["B", "F"]:
		var back: bool = side == "B"
		var pants := metal
		if torso_kind in ["leather", "bare"]:
			pants = ramp("leather")
		elif torso_kind in ["robe", "gown"]:
			pants = robe
		var tone := _back(pants) if back else pants
		var c := PixelCanvas.new(leg_w + 5, leg + 3)
		c.shade(1, 1, leg_w, leg - 5, tone)
		if not back and torso_kind == "plate":
			c.px(pants[3], 2, int(leg * 0.45), leg_w - 2, 1)
		var boot := _back(ramp("leather")) if back else ramp("leather")
		if torso_kind == "plate":
			boot = tone
		c.shade(1, leg - 5, leg_w, 4, boot)
		c.shade(1, leg - 2, leg_w + 2, 2, boot)
		c.px(gold[2] if gild >= 1 else boot[3], 1, leg - 5, leg_w, 1)
		if "drip" in extras and not back:
			c.px(Color("7ac8e8"), 2, leg - 9, 1, 2)
		parts["leg" + side] = c.outline().part(Vector2i(1 + leg_w / 2, 1))

	parts["torso"] = _torso(look, d, metal, robe, skin, gold, gem)
	parts["torso_h"] = d["torso"]
	parts["head"] = _head(look, d, metal, skin, gold, gem)

	# Arms with hands (Midas: one golden hand)
	var arm: int = d["arm"]
	for side in ["B", "F"]:
		var back: bool = side == "B"
		var c := PixelCanvas.new(6 + (2 if bulk >= 2 else 0), arm + 3)
		var sleeve := metal
		if torso_kind == "bare":
			sleeve = skin
		elif torso_kind in ["robe", "gown"]:
			sleeve = robe
		elif torso_kind == "leather":
			sleeve = ramp("leather")
		var s := _back(sleeve) if back else sleeve
		var aw := 4 + (2 if bulk >= 2 else 0)
		c.shade(1, 1, aw, arm - 4, s)
		c.px(gold[2] if gild >= 1 else s[3], 1, arm - 5, aw, 1)
		var hand := gold if ("golden_hand" in extras and not back) else skin
		c.shade(1, arm - 4, 4, 4, _back(hand) if back else hand)
		if bulk >= 1 and torso_kind == "plate":
			c.blob(3, 3, 3, 2, s)
		parts["arm" + side] = c.outline().part(Vector2i(3, 2))
	parts["arm_len"] = arm - 3

	var weapon_metal := ramp(look["weapon_metal"]) if look.has("weapon_metal") else metal
	var weapon_gem := Color(look["weapon_gem"]) if look.has("weapon_gem") else gem
	parts["weapon"] = _weapon(look["weapon"], weapon_metal, gold, weapon_gem)
	var shield: String = look.get("shield", "none")
	if shield == "round" or shield == "tower":
		var tall := shield == "tower"
		var metal_s := ramp(look["shield_metal"]) if look.has("shield_metal") else metal
		var gem_s := Color(look["shield_gem"]) if look.has("shield_gem") else gem
		var s := PixelCanvas.new(12 if not tall else 14, 15 if not tall else 24)
		var sh_w := 10 if not tall else 12
		var sh_h := 10 if not tall else 20
		s.shade(1, 1, sh_w, sh_h, metal_s)
		s.px(metal_s[1], 2, sh_h + 1, sh_w - 2, 1)
		s.px(metal_s[0], sh_w / 2, sh_h + 2, 2, 1)
		s.px(gem_s.darkened(0.2), sh_w / 2 - 1, 3, 4, 4)
		s.px(gem_s.lightened(0.4), sh_w / 2 - 1, 3)
		if tall:
			for y in range(9, sh_h, 4):
				s.px(metal_s[3], 2, y, sh_w - 2, 1)
		parts["shield"] = s.outline().part(Vector2i(sh_w / 2 + 1, 5))
	if "light_wings" in extras:  # Sonnenkönig: wings of light behind the shoulders
		var wc := PixelCanvas.new(40, 40)
		var pol := ramp("polished")
		var root := Vector2(34, 26)
		# A filled wing sweeping up and back, feather tips scalloped.
		for step in 60:
			var a := -3.0 + step / 60.0 * 1.55
			var feather := float(step % 10) / 10.0
			var reach := 30.0 - absf(a + 2.2) * 14.0 - feather * 4.0
			for r in int(reach):
				var p := root + Vector2(cos(a), sin(a)) * r
				var q := r / maxf(reach, 1.0)
				var col: Color = Color("fffbe0") if q > 0.8 else (Color("fff0b0") if q > 0.5 else pol[2])
				if step % 10 == 0 and q > 0.35:
					col = pol[1]  # feather lines
				wc.px(col, int(p.x), int(p.y))
		parts["cape"] = wc.outline().part(Vector2i(32, 24))
	var cape_len: int = look["cape"]
	if cape_len > 0 and not "light_wings" in extras:
		var c := PixelCanvas.new(18, cape_len + 3)
		var cape_col := ramp("wands") if look["metal"] == "ash" else cloth
		if look.has("cape_cloth"):
			cape_col = ramp(look["cape_cloth"])
		if "collar" in extras:
			cape_col = ramp("blood")
		for y in cape_len:
			var cw := 6 + mini(9, y >> 1)
			var x0 := 16 - cw
			for x in cw:
				var tone := 0 if x == 0 else (1 if x < 2 else (1 if (x + y) % 7 == 0 else 2))
				c.px(cape_col[tone], x0 + x, 1 + y)
			if look["fur"]:
				c.px(Color("f2ece4"), x0, 1 + y, 2, 1)
				if y % 3 == 1:
					c.px(Color("141012"), x0, 1 + y)
			elif gild >= 1:
				c.px(gold[2], x0, 1 + y)
			if look["metal"] == "ash" and (x0 + y) % 5 == 0:
				c.px(Color("ffa030"), x0 + 1, 1 + y)  # smouldering edge
		if look["fur"]:
			c.px(ramp("fur")[2], 9, 1, 8, 2)
		if "collar" in extras:  # high vampire collar
			c.px(cape_col[2], 11, 0, 5, 3)
		parts["cape"] = c.outline().part(Vector2i(14, 1))
	if look.has("handmade"):
		HandmadeArt.apply(look["handmade"], parts, look.get("handmade_only", []))
	return parts


## The torso: plate armour, robe, gown, leather vest or bare chest.
static func _torso(look: Dictionary, d: Dictionary, metal: Array, robe: Array, skin: Array, gold: Array, gem: Color) -> Dictionary:
	var kind: String = look.get("torso", "plate")
	var extras: Array = look.get("extras", [])
	var gild := int(look["gild"])
	var bulk := int(look.get("bulk", 0))
	var tw: int = d["tw"]
	var th: int = d["torso"]
	var long := kind in ["robe", "gown"]
	var extra_h := int(d["leg"]) - 4 if long else 0
	var c := PixelCanvas.new(tw + 16, th + extra_h + 9)
	var x0 := 8
	var y0 := 5
	var cx := x0 + tw / 2 - 1
	var belt := y0 + th - 3
	match kind:
		"robe", "gown":
			for y in th + extra_h:
				var widen := 0 if kind == "robe" else maxi(0, (y - th + 2) / 3)
				var w := tw + widen * 2
				for x in w:
					var u := float(x) / maxf(1.0, w - 1)
					var tone := 2 if u < 0.2 else (0 if u > 0.8 else 1)
					if (x + y) % 6 == 0 and y > th:
						tone = maxi(0, tone - 1)  # folds
					c.px(robe[tone], x0 - widen + x, y0 + y)
			c.px(gold[2], x0, y0 + th + extra_h - 1, tw, 1)  # golden hem
			c.px(gold[1] if kind == "robe" else metal[1], x0, belt, tw, 1)
			if kind == "gown":  # metal bodice over the dress
				_torso_shape(c, x0 + 1, y0, tw - 2, th - 4, metal)
				c.px(gem.darkened(0.2), cx, y0 + 4, 3, 3)
				c.px(gem.lightened(0.45), cx, y0 + 4)
			else:
				c.px(robe[3], x0 + 2, y0 + 1, 1, th + extra_h - 3)  # front seam light
				c.px(gold[2], cx, y0 + 3, 3, 3)
				c.px(gem, cx + 1, y0 + 4)
		"leather":
			var lr := ramp("leather")
			_torso_shape(c, x0, y0, tw, th, lr)
			for y in range(4, th - 3, 3):
				c.px(lr[0], x0 + 2, y0 + y, tw - 4, 1)
			c.px(lr[3], x0 + 2, y0 + 2, 1, th - 5)
			c.px(gem, cx + 1, y0 + 4, 2, 2)
			c.px(lr[0], x0, belt, tw, 1)
			c.px(ramp("iron")[3], cx, belt)
			if "satchel" in extras:  # money bag on the hip
				c.blob(x0 + 1, belt + 2, 3, 3, lr)
				c.px(gold[3], x0, belt, 2, 1)
		"bare":
			_torso_shape(c, x0, y0, tw, th, skin)
			c.px(skin[0], cx - 1, y0 + 5, 4, 1)  # chest line
			c.px(skin[0], cx, y0 + 8, 2, 1)
			for i in tw:  # diagonal strap
				c.px(ramp("leather")[1], x0 + i, y0 + 1 + i * (th - 4) / tw, 1, 2)
			c.px(ramp("leather")[0], x0, belt, tw, 2)
			c.px(ramp("iron")[3], cx, belt)
			if "apron" in extras:  # executioner's leather apron
				c.shade(x0 + 2, belt + 1, tw - 4, 5, ramp("leather"))
			if "lava_cracks" in extras:  # glowing cracks through charred skin
				var lava := ramp("lava")
				var x := cx - 3
				for y in range(1, th - 2):
					x += [-1, 1, 0, 1, -1][y % 5]
					c.px(lava[1] if y % 3 else lava[2], x, y0 + y)
				for p in [Vector2i(x0 + 1, y0 + 4), Vector2i(x0 + 2, y0 + 5), Vector2i(x0 + tw - 3, y0 + 7), Vector2i(x0 + tw - 2, y0 + 8)]:
					c.px(lava[2], p.x, p.y)
		_:  # plate armour with filigree and a chest gem
			_torso_shape(c, x0, y0, tw, th, metal)
			for y in range(3, th - 1, 3):
				for x in range(2, tw - 2, 2):
					c.px(metal[3], x0 + x, y0 + y)
			c.px(metal[0], cx - 1, y0 + 4, 5, 5)
			c.px(gem.darkened(0.25), cx, y0 + 5, 3, 3)
			c.px(gem.lightened(0.45), cx, y0 + 5)
			c.px(gold[1] if gild >= 1 else metal[0], x0, belt, tw, 1)
			if bulk >= 1:  # pauldrons, bigger with more gold
				c.blob(x0 + 1, y0 + 1, 1 + bulk * 2, 1 + bulk, metal)
				c.blob(x0 + tw - 2, y0 + 1, 1 + bulk * 2, 1 + bulk, metal)
			if bulk >= 2:  # layered plates over the belly
				for y in range(th / 2, th - 2, 2):
					c.px(metal[0], x0 + 1, y0 + y, tw - 2, 1)
			if bulk >= 3:  # spikes on the shoulders
				for i in 3:
					c.px(metal[3], x0 - 3 + i * 2, y0 - 3 - (i % 2), 1, 3)
					c.px(metal[3], x0 + tw - 2 + i * 2, y0 - 3 - (i % 2), 1, 3)
	if gild >= 2:
		c.px(gold[2], x0 + 1, y0, tw - 2, 1)
	if "starry" in extras:  # a robe full of stars
		for i in 18:
			var sx := x0 + (i * 7) % tw
			var sy := y0 + 2 + (i * 11) % maxi(1, th + extra_h - 4)
			c.px(Color("f0e8ff") if i % 3 == 0 else Color("9a70e0"), sx, sy)
		c.px(Color("c080ff"), cx, y0 + 3, 3, 3)
	if "drip" in extras:
		for p in [Vector2i(x0 + 2, y0 + th - 2), Vector2i(x0 + tw - 3, y0 + th + 2)]:
			c.px(Color("7ac8e8"), p.x, p.y, 1, 2)
	return c.outline().part(Vector2i(x0 + tw / 2, y0 + th))


## The head with face and headgear (canvas with headroom), pivot at the neck.
static func _head(look: Dictionary, d: Dictionary, metal: Array, skin: Array, gold: Array, gem: Color) -> Dictionary:
	var hs: int = d["head"]
	var hw := hs + 20
	var hh := hs + 24
	var c := PixelCanvas.new(hw, hh)
	var hx := hw / 2
	var rr := hs / 2
	var hy := hh - 3 - rr
	var top := hy - rr
	var kind: String = look["head"]
	var extras: Array = look.get("extras", [])
	var eyes: Variant = look["eyes"]
	var hair := ramp("hair")
	if look["skin"] == "drowned":
		hair = ramp("seaweed")
	elif look["skin"] in ["spirit_gold", "fire"]:
		hair = ramp("flame") if look["skin"] == "fire" else ramp("gold")
	elif look["skin"] == "spirit_water":
		hair = ramp("cups")
	if "halo" in extras:
		for i in 20:
			var a := i / 20.0 * TAU
			c.px(gold[3], hx + int(cos(a) * (rr + 3)), top - 6 + int(sin(a) * 2))
	if kind == "hood":
		c.blob(hx - 1, hy - 1, rr + 2, rr + 2, ramp(look["cloth"]))
		c.blob(hx + 2, hy + 1, rr - 1, rr - 1, ramp("shadow"))
		var eye: Color = eyes if eyes != null else Color("ffd25a")
		c.px(eye, hx + 1, hy)
		c.px(eye, hx + 4, hy)
		return c.outline().part(Vector2i(hx - 1, hh - 3))
	if kind == "spike_helm":  # Höllenhenker: closed iron helm, glowing visor, lava-tipped spikes
		var iron := ramp("charcoal")
		var lava := ramp("lava")
		c.blob(hx, hy, rr + 1, rr + 1, iron)
		c.px(iron[0], hx - rr - 1, hy + rr - 1, rr * 2 + 3, 2)
		c.px(lava[2], hx, hy - 1, rr + 1, 1)  # glowing visor slit
		c.px(lava[3], hx + 2, hy - 1, 2, 1)
		c.px(lava[1], hx + 1, hy + 1, 1, 3)
		for i in 5:
			var sx := hx - rr + i * (rr * 2) / 4
			var tall := 6 + (3 if i == 2 else (1 if i % 2 else 0))
			c.px(iron[2], sx, top - tall + 1, 1, tall)
			c.px(lava[2], sx, top - tall)
			c.px(lava[3], sx, top - tall - 1)
		return c.outline().part(Vector2i(hx - 1, hh - 3))
	if kind == "void_hood":  # Sternenrichter: a hood of night sky with violet eyes
		var night := ramp("void")
		c.blob(hx - 1, hy - 1, rr + 2, rr + 2, night)
		c.blob(hx + 2, hy + 1, rr - 1, rr - 1, [Color("020104"), Color("040208"), Color("06040c"), Color("080610")])
		for i in 6:
			c.px(Color("e0d0ff") if i % 2 else Color("8a70c0"), hx - rr + (i * 5) % (rr * 2), top + (i * 3) % rr)
		c.px(Color("c080ff"), hx + 1, hy, 2, 1)
		c.px(Color("c080ff"), hx + 4, hy, 2, 1)
		c.px(Color("f0e0ff"), hx + 1, hy)
		c.px(Color("f0e0ff"), hx + 4, hy)
		return c.outline().part(Vector2i(hx - 1, hh - 3))
	if kind == "exec_hood":  # black executioner's hood with eye holes, pointed top
		var black := ramp("judge")
		c.blob(hx, hy, rr + 1, rr + 1, black)
		for i in 5:
			c.px(black[1], hx - 1 + i / 2, top - 1 - i, 3 - i / 2, 1)
		c.px(Color.BLACK, hx + 1, hy - 1, 5, 2)
		c.px(Color("e8dcc0"), hx + 2, hy - 1)
		c.px(Color("e8dcc0"), hx + 4, hy - 1)
		c.px(black[0], hx - rr - 1, hy + rr, rr * 2 + 2, 2)
		return c.outline().part(Vector2i(hx - 1, hh - 3))
	# Face
	c.blob(hx, hy, rr, rr, skin)
	c.px(skin[0], hx - rr + 1, hy, 2, 3)
	c.px(Color("f4ece0") if eyes == null else eyes, hx + 2, hy - 1, 2, 1)
	c.px(Color("1a0e08") if eyes == null else Color(eyes).lightened(0.4), hx + 3, hy - 1)
	c.px(skin[0], hx + 1, hy - 3, 3, 1)
	c.px(skin[2], hx + rr, hy, 1, 2)
	c.px(skin[0], hx + 2, hy + 3, 2, 1)
	# Hair
	var hair_shape := func(color_top: Color, color: Color) -> void:
		for y in range(top - 1, top + 4):
			for x in range(hx - rr, hx + rr - 1):
				if (x - hx) * (x - hx) + (y - hy) * (y - hy) <= (rr + 1) * (rr + 1):
					c.px(color_top if y == top - 1 else color, x, y)
		c.px(color, hx - rr, hy - 2, 3, 6)
	if kind not in ["helm", "winged_helm", "flame_hair", "wig", "veil", "feather_hat"]:
		hair_shape.call(hair[2], hair[1])
	if look["long_hair"]:
		c.px(hair[1], hx - rr - 1, hy - 2, 3, hs + 2)
		c.px(hair[2], hx - rr - 1, hy - 2, 1, hs)
	if look["beard"]:
		var beard_ramp := ramp("seaweed") if look["skin"] == "drowned" else ramp("beard")
		if "frost_beard" in extras:
			beard_ramp = ramp("ice")
		c.shade(hx - 1, hy + 2, 6, 6, beard_ramp)
	match kind:
		"cap":
			c.shade(hx - rr, top - 2, hs + 1, 4, metal)
			c.px(metal[0], hx + rr - 1, top + 1, 3, 1)
			var feather := gem.lightened(0.2)
			c.px(feather, hx - rr - 1, top - 3, 4, 1)
			c.px(feather, hx - rr - 3, top - 4, 3, 1)
			c.px(feather, hx - rr - 4, top - 5, 2, 1)
		"helm", "winged_helm":
			c.shade(hx - rr - 1, top - 2, hs + 2, hs + 1, metal)
			c.px(PixelCanvas.OUTLINE, hx, hy - 1, rr + 2, 1)
			c.px(PixelCanvas.OUTLINE, hx + 2, hy + 2, rr, 1)
			c.px(metal[3], hx - rr + 1, top, 1, hs - 3)
			if kind == "winged_helm":
				for i in 6:
					c.px(Color.WHITE if i % 2 else Color("d8e0f0"), hx - rr - 2 - i, top + 2 - i, 2 + i / 2, 1)
			else:
				for i in 5:
					c.px(gem if i % 2 == 0 else gem.darkened(0.3), hx - 2 + i, top - 4 - (i & 1))
		"tiara":
			_crown(c, hx, rr, hs, top, gold, 1, look["gems_in_crown"])
		"crown":
			_crown(c, hx, rr, hs, top, gold, 4 if look["gems_in_crown"] else 2, true)
		"ash_crown":
			_crown(c, hx, rr, hs, top, ramp("ash"), 3, false)
			for i in range(0, hs, 3):
				c.px(Color("ffa030"), hx - rr + i, top - 4)
		"flame_crown", "flame_hair":
			var flame := ramp("flame")
			for i in hs + 2:
				var tall := 3 + (i * 7) % 5 + (2 if kind == "flame_hair" else 0)
				c.px(flame[1], hx - rr - 1 + i, top - tall + 2, 1, tall)
				c.px(flame[2], hx - rr - 1 + i, top - tall + 3, 1, maxi(1, tall - 3))
				c.px(flame[3], hx - rr - 1 + i, top - tall + 2)
			if kind == "flame_crown":
				c.shade(hx - rr, top - 1, hs, 2, gold)
		"ice_crown":  # Frostkönig: jagged shards of ice
			var ice := ramp("ice")
			c.shade(hx - rr, top - 1, hs, 2, ice)
			for i in hs:
				var tall := 4 + (i * 5) % 7
				if i % 2:
					continue
				c.px(ice[1], hx - rr + i, top - tall, 2, tall)
				c.px(ice[2], hx - rr + i, top - tall, 1, tall - 1)
				c.px(ice[3], hx - rr + i, top - tall)
		"ray_crown":  # Sonnenkönig: golden crown with long sun rays
			var pol := ramp("polished")
			for i in 9:
				var a := PI + (i + 0.5) / 9.0 * PI
				var length := 9 if i % 2 == 0 else 6
				for r in range(3, length):
					c.px(pol[3] if r > length - 3 else pol[2], hx + int(cos(a) * (rr + r)), top + 2 + int(sin(a) * (rr + r) * 0.8))
			_crown(c, hx, rr, hs, top, pol, 4, true)
		"seaweed_crown":
			var sea := ramp("seaweed")
			_crown(c, hx, rr, hs, top, ramp("sea"), 2, false)
			for i in range(0, hs, 3):
				c.px(sea[2], hx - rr + i, top, 1, 6 + i % 4)
		"veil":
			hair_shape.call(hair[2], hair[1])
			for y in range(top - 1, hy + rr + 6):
				c.px(Color(0.95, 0.93, 0.88), hx - rr - 2, y, 3, 1)
			c.px(Color(0.95, 0.93, 0.88), hx - rr - 1, top - 1, hs, 2)
			_crown(c, hx, rr, hs, top - 1, gold, 1, true)
		"feather_hat":
			hair_shape.call(hair[2], hair[1])
			var brim := ramp(look["cloth"])
			c.shade(hx - rr - 3, top, hs + 6, 2, brim)
			c.shade(hx - rr + 1, top - 4, hs - 2, 5, brim)
			for i in 8:  # long feather sweeping back
				c.px(Color.WHITE if i % 3 else gem.lightened(0.3), hx - rr - 1 - i, top - 3 - i / 2, 2, 1)
		"headband":
			c.px(ramp(look["cloth"])[2], hx - rr, top + 2, hs, 2)
			c.px(ramp(look["cloth"])[1], hx - rr - 3, top + 3, 3, 1)
			c.px(ramp(look["cloth"])[1], hx - rr - 4, top + 5, 2, 1)
		"wig":  # the judge's white wig and little black cap
			var wig := ramp("beard")
			for y in range(top - 1, hy + rr + 2):
				c.px(wig[3] if y % 2 else wig[2], hx - rr - 1, y, 3, 1)
			c.blob(hx - 1, top, rr, 2, wig)
			c.shade(hx - 2, top - 3, 5, 2, ramp("judge"))
	return c.outline().part(Vector2i(hx - 1, hh - 3))


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
	var silver := ramp("silver")
	var flame := ramp("flame")
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
		"club":  # spiked club glowing with embers
			c = PixelCanvas.new(14, 28)
			for y in 22:
				var w := 2 + y / 7
				c.px(wood[1 if y % 4 else 2], 7 - w / 2, 22 - y, w, 1)
			for p in [Vector2i(3, 3), Vector2i(10, 5), Vector2i(4, 9), Vector2i(11, 2)]:
				c.px(flame[2], p.x, p.y, 2, 1)
			c.px(flame[3], 7, 1)
			pivot = Vector2i(7, 21)
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
		"orb":  # a golden apple / orb resting in the golden hand
			c = PixelCanvas.new(12, 12)
			c.blob(6, 5, 4, 4, gold)
			c.px(gold[3], 4, 3, 2, 1)
			c.px(Color("2f5e3a"), 6, 0, 2, 2)
			pivot = Vector2i(6, 9)
		"torch":
			c = PixelCanvas.new(10, 28)
			c.shade(4, 8, 2, 19, wood)
			c.shade(3, 6, 4, 3, metal)
			c.px(flame[1], 3, 2, 4, 4)
			c.px(flame[2], 4, 1, 2, 4)
			c.px(flame[3], 4, 3, 1, 2)
			pivot = Vector2i(5, 22)
		"ember_staff":  # tall staff with a floating ember orb
			c = PixelCanvas.new(14, 34)
			c.shade(6, 10, 2, 23, wood)
			c.px(gold[2], 4, 9, 6, 1)
			c.blob(7, 5, 3, 3, flame)
			c.px(flame[3], 6, 4)
			c.px(flame[2], 3, 2)
			c.px(flame[2], 11, 3)
			pivot = Vector2i(7, 27)
		"chalice":
			c = PixelCanvas.new(14, 16)
			c.shade(2, 1, 10, 6, gold)
			c.px(gold[1], 3, 7, 8, 1)
			c.px(gold[2], 6, 8, 2, 4)
			c.shade(4, 12, 6, 2, gold)
			c.px(gem, 6, 3)
			c.px(Color("8ac8ff"), 3, 1, 8, 1)  # holy water glimmer
			pivot = Vector2i(7, 10)
		"goblet":  # the blood drinker's goblet, filled red
			c = PixelCanvas.new(10, 14)
			c.shade(2, 1, 6, 5, silver)
			c.px(Color("8c1a2a"), 2, 1, 6, 2)
			c.px(Color("c8283a"), 3, 1, 2, 1)
			c.px(silver[2], 4, 6, 2, 4)
			c.shade(2, 10, 6, 2, silver)
			pivot = Vector2i(5, 8)
		"censer":  # incense burner on a chain, a wisp of smoke
			c = PixelCanvas.new(12, 22)
			for y in 10:
				c.px(gold[2] if y % 2 else gold[1], 6, y, 1, 1)
			c.blob(6, 14, 4, 3, gold)
			c.px(gold[0], 3, 14, 7, 1)
			c.px(Color("d0d0d8"), 9, 9, 1, 2)
			c.px(Color("e8e8f0"), 10, 7, 1, 2)
			pivot = Vector2i(6, 1)
		"trident":
			c = PixelCanvas.new(14, 36)
			c.shade(6, 10, 2, 25, ramp("sea"))
			c.px(ramp("sea")[3], 2, 9, 10, 1)
			for x in [2, 6, 10]:
				c.px(ramp("sea")[3], x, 2, 2, 7)
				c.px(Color.WHITE, x, 1)
			pivot = Vector2i(7, 27)
		"sword", "greatsword", "flame_sword", "crystal_sword", "rapier":
			var big := kind == "greatsword"
			var thin := kind == "rapier"
			var length := 30 if big else (24 if thin else 20)
			var blade_w := 1 if thin else (4 if big else 3)
			var blade := silver
			if kind == "flame_sword":
				blade = flame
			elif kind == "crystal_sword":
				blade = ["2a6a9a", "6ab0e0", "b8e4ff", "ffffff"].map(func(h: String) -> Color: return Color(h))
			c = PixelCanvas.new(12, length + 12)
			c.shade(5 - blade_w / 2, 1, blade_w, length, blade)
			c.px(blade[3], 5 - blade_w / 2, 1, 1, length - 2)
			c.shade(1, length + 1, 9, 2, gold)
			c.shade(4, length + 3, 3, 5 if big else 4, ramp("leather"))
			c.px(gem, 5, length + 8)
			if kind == "flame_sword":
				for y in range(2, length, 4):
					c.px(flame[3], 7, y)
			pivot = Vector2i(5, length + 5)
		"hell_axe":  # Höllenhenker: a huge charred axe with a lava edge
			var iron := ramp("charcoal")
			var lava := ramp("lava")
			c = PixelCanvas.new(22, 38)
			c.shade(10, 4, 2, 33, iron)
			for y in 16:
				var w := 4 + mini(y, 15 - y)
				c.px(iron[1], 12, 2 + y, w, 1)
				c.px(iron[2], 12, 2 + y, 1, 1)
				c.px(lava[2], 12 + w - 1, 2 + y)
				c.px(lava[3] if y % 3 == 0 else lava[1], 12 + w - 2, 2 + y)
			for y in range(6, 34, 5):
				c.px(lava[1], 10, y, 2, 1)
			c.px(lava[2], 9, 1, 4, 2)
			pivot = Vector2i(11, 30)
		"ice_trident":  # Frostkönig: a trident of clear ice
			var ice := ramp("ice")
			c = PixelCanvas.new(16, 40)
			c.shade(7, 10, 2, 29, ice)
			c.px(ice[3], 7, 11, 1, 26)
			c.px(ice[2], 2, 9, 12, 2)
			for x in [2, 7, 12]:
				c.px(ice[1], x, 1, 2, 9)
				c.px(ice[3], x, 1, 1, 7)
				c.px(Color.WHITE, x, 0)
			c.px(ice[2], 5, 24, 6, 2)
			pivot = Vector2i(8, 30)
		"void_greatsword":  # Sternenrichter: a black blade with a violet core
			var night := ramp("void")
			c = PixelCanvas.new(14, 46)
			c.shade(4, 1, 6, 32, night)
			c.px(Color("c080ff"), 6, 2, 2, 30)
			c.px(Color("f0e0ff"), 6, 3, 1, 26)
			for y in range(4, 32, 6):
				c.px(Color("e0d0ff"), 5 if y % 12 else 8, y)
			c.shade(1, 33, 12, 2, night)
			c.px(Color("c080ff"), 6, 33, 2, 2)
			c.shade(5, 35, 4, 6, ramp("shadow"))
			c.px(Color("c080ff"), 6, 41, 2, 2)
			pivot = Vector2i(7, 38)
		"sun_scepter":  # Sonnenkönig: a golden staff crowned by the sun
			var pol := ramp("polished")
			c = PixelCanvas.new(20, 34)
			c.shade(9, 11, 2, 22, pol)
			c.blob(10, 7, 4, 4, pol)
			c.px(Color.WHITE, 9, 5, 2, 2)
			for i in 12:
				var a := i / 12.0 * TAU
				var r := 7 if i % 2 == 0 else 6
				c.px(pol[3] if i % 2 == 0 else pol[2], 10 + int(cos(a) * r), 7 + int(sin(a) * r))
			pivot = Vector2i(10, 26)
		"axe":  # executioner's great axe
			c = PixelCanvas.new(18, 34)
			c.shade(8, 4, 2, 29, wood)
			for y in 12:
				var w := 3 + mini(y, 11 - y)
				c.px(silver[1], 10, 2 + y, w, 1)
				c.px(silver[3], 10 + w - 1, 2 + y)
			c.px(Color("6a0c14"), 11, 6, 2, 2)  # a dark stain
			pivot = Vector2i(9, 26)
		"knives":  # a fan of throwing knives
			c = PixelCanvas.new(14, 14)
			for i in 3:
				c.px(silver[2], 3 + i * 3, 1 + i, 1, 7)
				c.px(silver[3], 3 + i * 3, 1 + i)
				c.px(ramp("leather")[1], 3 + i * 3, 8 + i, 1, 3)
			pivot = Vector2i(6, 10)
		"dagger":
			c = PixelCanvas.new(8, 16)
			c.shade(3, 1, 2, 8, silver)
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

## The battle background picked in the vault mirror.
static func background(style: String, w: int, h: int, floor_y: int) -> ImageTexture:
	match style:
		"stage_cathedral":
			return cathedral(w, h, floor_y)
		"stage_graveyard":
			return graveyard(w, h, floor_y)
	return vault(w, h, floor_y)


## The ruined cathedral, painted with light (CryptArt).
static func cathedral(w: int, h: int, floor_y: int) -> ImageTexture:
	return CryptArt.cathedral(w, h, floor_y)


## The moonlit graveyard, painted with light (CryptArt).
static func graveyard(w: int, h: int, floor_y: int) -> ImageTexture:
	return CryptArt.graveyard(w, h, floor_y)


## The treasure vault, painted with light (CryptArt): moonlit window, torches,
## deep arches with gold, niches and a flagstone floor.
static func vault(w: int, h: int, floor_y: int) -> ImageTexture:
	return CryptArt.stage(w, h, floor_y)
