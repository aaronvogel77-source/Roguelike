class_name ContentDb
extends RefCounted
## Loads all game content (figures, enemies, ...) from JSON files in res://data.

const FIGURES_PATH := "res://data/figures.json"
const ENEMIES_PATH := "res://data/enemies.json"
const REGIONS_PATH := "res://data/regions.json"
const ITEMS_PATH := "res://data/items.json"
const SUITS := ["coins", "wands", "cups", "swords"]
const RANKS := ["page", "knight", "queen", "king"]
## Legendary figures (aces) only come from court packs.
const LEGEND_RANK := "legend"

var figures: Dictionary = {}  # id -> definition
var enemies: Dictionary = {}  # id -> definition
var regions: Dictionary = {}  # id -> definition (themes, blessing)
var bosses: Dictionary = {}  # id -> definition (region, act, rule)
## Equipment bases, affixes, relics, tarot cards, pack rules.
var items: Dictionary = {}


static func load_default() -> ContentDb:
	var db := ContentDb.new()
	for entry in _read_json(FIGURES_PATH)["figures"]:
		db.figures[entry["id"]] = entry
	for entry in _read_json(ENEMIES_PATH)["enemies"]:
		db.enemies[entry["id"]] = entry
	db.items = _read_json(ITEMS_PATH)
	var region_data := _read_json(REGIONS_PATH)
	for entry in region_data["regions"]:
		db.regions[entry["id"]] = entry
	for entry in region_data["bosses"]:
		db.bosses[entry["id"]] = entry
		# Boss figures fight like enemies, so they are looked up like enemies.
		db.enemies[entry["unit"]["id"]] = entry["unit"]
	return db


## Figures that can appear in the shop (no legendary aces).
func regular_figures() -> Array:
	return figures.values().filter(func(f: Dictionary) -> bool: return f["rank"] != LEGEND_RANK)


func legendary_figures() -> Array:
	var result := figures.values().filter(func(f: Dictionary) -> bool: return f["rank"] == LEGEND_RANK)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return result


## Normal enemies (without boss figures) - the pool the generator draws from.
func regular_enemies() -> Array:
	return enemies.values().filter(func(e: Dictionary) -> bool: return not e.get("boss", false))


## Bosses of a region for an act (the pool the boss is drawn from).
func bosses_for(region: String, act: int) -> Array:
	var result: Array = []
	for boss in bosses.values():
		if boss["region"] == region and int(boss["act"]) == act:
			result.append(boss)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return result


## Translation key for a figure or enemy name, e.g. FIG_KING_MIDAS.
static func name_key(definition: Dictionary) -> String:
	var prefix := "ENEMY_" if definition.has("cost") else "FIG_"
	return prefix + String(definition["id"]).to_upper()


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Missing content file: " + path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Invalid JSON in " + path)
	return parsed
