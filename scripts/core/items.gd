class_name Items
extends RefCounted
## Objects of a run: equipment (rolled with random affixes), relics, tarot
## cards and the packs they come in. Pure data helpers, no UI.
##
## An equipment instance: {"base": "blade", "rarity": 0-3,
##   "affixes": [{"id", "value"}], "drawback": {"id", "value"} or {}}

const RARITY_COMMON := 0
const RARITY_MAGIC := 1
const RARITY_RARE := 2
const RARITY_CURSED := 3
## Only from the cursed well (10 gold, small chance): 2 affixes + 1 unique effect.
const RARITY_UNIQUE := 4
const AFFIX_COUNT := [0, 1, 2, 2, 2]
## Equipment rarity odds by act (common, magic, rare, cursed) - good items are rare.
const RARITY_ODDS := [[1, [85, 13, 2, 0]], [2, [75, 19, 5, 1]], [3, [65, 24, 8, 3]]]


# --- Equipment --------------------------------------------------------------------

## forced_rarity >= 0 skips the rarity roll (events that promise a rarity).
## Every item follows AFFIX_COUNT for its rarity; affixes never repeat and
## never duplicate the base effect (a torch gets no extra "burning hits").
static func roll_equipment(db: ContentDb, act: int, rng: RandomNumberGenerator, rarity_bonus: int = 0,
		forced_rarity: int = -1) -> Dictionary:
	var bases: Array = db.items["equipment"]
	var base: Dictionary = bases[rng.randi_range(0, bases.size() - 1)]
	var rarity := forced_rarity if forced_rarity >= 0 else mini(_roll_rarity(act, rng) + rarity_bonus, RARITY_CURSED)
	var item := {"base": base["id"], "rarity": rarity, "affixes": [], "drawback": {}}
	var pool: Array = db.items["affixes"].filter(func(a: Dictionary) -> bool:
		return rarity >= int(a.get("min_rarity", 0)) and not _same_effect(a, base["base"]))
	for i in AFFIX_COUNT[rarity]:
		if pool.is_empty():
			break
		var index := rng.randi_range(0, pool.size() - 1)
		var affix: Dictionary = pool[index]
		pool.remove_at(index)
		item["affixes"].append({"id": affix["id"], "value": _roll_value(affix, rng)})
	if rarity == RARITY_CURSED:
		var drawbacks: Array = db.items["drawbacks"]
		var drawback: Dictionary = drawbacks[rng.randi_range(0, drawbacks.size() - 1)]
		item["drawback"] = {"id": drawback["id"], "value": _roll_value(drawback, rng)}
	if rarity == RARITY_UNIQUE:
		var uniques: Array = db.items["uniques"]
		item["unique"] = uniques[rng.randi_range(0, uniques.size() - 1)]["id"]
	return item


## Whether an affix does the same as an equipment base (same stat or same effect).
static func _same_effect(affix: Dictionary, base: Dictionary) -> bool:
	if affix.has("stat") and base.get("stat", "") == affix["stat"]:
		return true
	if affix.has("ability") and base.has("ability"):
		return String(affix["ability"]).split("|")[2] == base["ability"]["effect"]
	return false


static func equipment_price(db: ContentDb, item: Dictionary) -> int:
	return db.items["equipment_prices"][int(item["rarity"])]


## Battle modifiers of an equipment: {"attack", "health", "abilities", "multipliers", "run_gold"}.
static func equipment_modifiers(db: ContentDb, item: Dictionary) -> Dictionary:
	var mods := {"attack": 0, "health": 0, "abilities": [], "multipliers": [], "run_gold": 0}
	var base: Dictionary = _find(db.items["equipment"], item["base"])["base"]
	_apply_part(mods, base, base.get("value", 0))
	for affix in item["affixes"]:
		_apply_part(mods, _find(db.items["affixes"], affix["id"]), affix["value"])
	if not item.get("drawback", {}).is_empty():
		var drawback: Dictionary = item["drawback"]
		_apply_part(mods, _find(db.items["drawbacks"], drawback["id"]), drawback["value"])
	if item.has("unique"):
		var unique := _find(db.items["uniques"], item["unique"])
		_apply_part(mods, unique, unique.get("value", 0))
	return mods


static func _apply_part(mods: Dictionary, part: Dictionary, value: Variant) -> void:
	if part.has("stat"):
		mods[part["stat"]] += int(value)
	elif part.has("ability"):
		var ability: Variant = part["ability"]
		if ability is String:  # "trigger|target|effect" shorthand in the affix pool
			var bits: PackedStringArray = ability.split("|")
			ability = {"trigger": bits[0], "target": bits[1], "effect": bits[2], "values": [value, value, value]}
		mods["abilities"].append(ability)
	elif part.get("mult", false):
		mods["multipliers"].append(float(value))
	elif part.has("run_gold"):
		mods["run_gold"] += int(part["run_gold"])


static func _roll_rarity(act: int, rng: RandomNumberGenerator) -> int:
	var odds: Array = RARITY_ODDS[0][1]
	for entry in RARITY_ODDS:
		if act >= entry[0]:
			odds = entry[1]
	return _weighted_index(odds, rng)


static func _roll_value(part: Dictionary, rng: RandomNumberGenerator) -> Variant:
	if part.has("run_gold"):
		return int(part["run_gold"])
	var low: Variant = part.get("min", 0)
	var high: Variant = part.get("max", low)
	if low is float or high is float:
		if is_equal_approx(float(low), float(high)):
			return float(low)
		return snappedf(rng.randf_range(float(low), float(high)), 0.05)
	return rng.randi_range(int(low), int(high))


# --- Packs ------------------------------------------------------------------------

## A shop pack: {"type": "equipment|arcana|relic|court", "size": "normal|jumbo|mega"}.
static func roll_pack(db: ContentDb, rng: RandomNumberGenerator) -> Dictionary:
	var rules: Dictionary = db.items["packs"]
	return {"type": _weighted_key(rules["type_weights"], rng),
		"size": _weighted_key(_size_weights(rules), rng)}


static func pack_price(db: ContentDb, pack: Dictionary) -> int:
	var rules: Dictionary = db.items["packs"]
	return int(rules["types"][pack["type"]]["price"]) + int(rules["sizes"][pack["size"]]["extra_price"])


static func pack_picks(db: ContentDb, pack: Dictionary) -> int:
	return int(db.items["packs"]["sizes"][pack["size"]]["picks"])


static func pack_choice_count(db: ContentDb, pack: Dictionary) -> int:
	var rules: Dictionary = db.items["packs"]
	var size: Dictionary = rules["sizes"][pack["size"]]
	if size.has("set_choices"):
		return int(size["set_choices"])
	return int(rules["types"][pack["type"]]["choices"]) + int(size.get("extra_choices", 0))


## Contents of an opened pack: entries {"kind": "equipment|tarot|relic|figure", ...}.
## force_legend: debug tool, the first card of an arcana pack is a legendary figure.
static func pack_contents(db: ContentDb, pack: Dictionary, act: int, rng: RandomNumberGenerator,
		owned_relics: Array = [], force_legend: bool = false) -> Array:
	var count := pack_choice_count(db, pack)
	var rarity_bonus := 0  # bigger packs give more choice, not better items
	var result: Array = []
	match pack["type"]:
		"equipment":
			for i in count:
				result.append({"kind": "equipment", "item": roll_equipment(db, act, rng, rarity_bonus)})
		"arcana":
			# Tarot cards without duplicates; each card has a tiny chance to be
			# a legendary figure instead (the only way to get aces).
			var chance: float = db.items["packs"]["legend_chance"][pack["size"]]
			var cards: Array = []
			for i in count:
				if (force_legend and i == 0) or rng.randf() < chance:
					var legends := db.legendary_figures()
					result.append({"kind": "figure", "def_id": legends[rng.randi_range(0, legends.size() - 1)]["id"]})
					continue
				if cards.is_empty():
					cards = db.items["tarot"].duplicate()
				var index := rng.randi_range(0, cards.size() - 1)
				result.append({"kind": "tarot", "id": cards[index]})
				cards.remove_at(index)
		"relic":
			var relics: Array = db.items["relics"].map(func(r: Dictionary) -> String: return r["id"]).filter(
				func(id: String) -> bool: return not id in owned_relics)
			for i in mini(count, relics.size()):
				var index := rng.randi_range(0, relics.size() - 1)
				result.append({"kind": "relic", "id": relics[index]})
				relics.remove_at(index)
	return result


static func relic_price(db: ContentDb, relic_id: String) -> int:
	return int(_find(db.items["relics"], relic_id)["price"])


# --- Helpers ----------------------------------------------------------------------

static func _size_weights(rules: Dictionary) -> Dictionary:
	var weights := {}
	for size in rules["sizes"]:
		weights[size] = rules["sizes"][size]["weight"]
	return weights


static func _weighted_key(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys := weights.keys()
	keys.sort()
	var values: Array = keys.map(func(k: String) -> int: return int(weights[k]))
	return keys[_weighted_index(values, rng)]


static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var roll := rng.randi_range(1, total)
	for i in weights.size():
		roll -= int(weights[i])
		if roll <= 0:
			return i
	return weights.size() - 1


static func _find(list: Array, id: String) -> Dictionary:
	for entry in list:
		if entry["id"] == id:
			return entry
	push_error("Unknown item id: " + id)
	return {}
