class_name ContentDb
extends RefCounted
## Loads all game content (figures, enemies, ...) from JSON files in res://data.

const FIGURES_PATH := "res://data/figures.json"
const ENEMIES_PATH := "res://data/enemies.json"
const SUITS := ["coins", "wands", "cups", "swords"]
const RANKS := ["page", "knight", "queen", "king"]

var figures: Dictionary = {}  # id -> definition
var enemies: Dictionary = {}  # id -> definition


static func load_default() -> ContentDb:
	var db := ContentDb.new()
	for entry in _read_json(FIGURES_PATH)["figures"]:
		db.figures[entry["id"]] = entry
	for entry in _read_json(ENEMIES_PATH)["enemies"]:
		db.enemies[entry["id"]] = entry
	return db


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
