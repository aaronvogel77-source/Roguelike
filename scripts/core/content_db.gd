class_name ContentDb
extends RefCounted
## Loads all game content (figures, enemies, ...) from JSON files in res://data.

const FIGURES_PATH := "res://data/figures.json"
const ENEMIES_PATH := "res://data/enemies.json"
const REGIONS_PATH := "res://data/regions.json"
const ITEMS_PATH := "res://data/items.json"
const FUSION_PATH := "res://data/fusion.json"
const META_PATH := "res://data/meta.json"
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
## Fusion rules, the 10 master abilities and the secret recipes.
var fusion: Dictionary = {}
## Meta progression: currency rules, locked content, chests, upgrades, occultists.
var meta: Dictionary = {}
## Content not yet unlocked in the vault (only set on a run's own copy).
var locked_figures: Array = []
## Figures taken out of the game entirely (balancing tools: "without this card").
var banned_figures: Array = []


static func load_default() -> ContentDb:
	var db := ContentDb.new()
	for entry in _read_json(FIGURES_PATH)["figures"]:
		db.figures[entry["id"]] = entry
	for entry in _read_json(ENEMIES_PATH)["enemies"]:
		db.enemies[entry["id"]] = entry
	db.items = _read_json(ITEMS_PATH)
	db.fusion = _read_json(FUSION_PATH)
	db.meta = _read_json(META_PATH)
	var region_data := _read_json(REGIONS_PATH)
	for entry in region_data["regions"]:
		db.regions[entry["id"]] = entry
	for entry in region_data["bosses"]:
		db.bosses[entry["id"]] = entry
		# Boss figures fight like enemies, so they are looked up like enemies.
		db.enemies[entry["unit"]["id"]] = entry["unit"]
	return db


## Figures that can appear in the shop (no legendary aces, no recipe figures).
func regular_figures() -> Array:
	return figures.values().filter(func(f: Dictionary) -> bool: return f["rank"] != LEGEND_RANK and not f["id"] in banned_figures)


## Legendary aces from arcana packs (secret recipe figures never appear there).
func legendary_figures(include_locked: bool = false) -> Array:
	var result := figures.values().filter(func(f: Dictionary) -> bool:
		return f["rank"] == LEGEND_RANK and not f.get("recipe", false) and not f["id"] in banned_figures \
			and (include_locked or not f["id"] in locked_figures))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return result


## A copy for one run: locked content is taken out of every pool, and the
## pack-luck upgrade raises the chance of legendary cards in arcana packs.
## Figure/relic definitions stay, so saved runs and lookups keep working.
func for_run(locked: Dictionary, pack_luck: int = 0) -> ContentDb:
	var copy := ContentDb.new()
	copy.figures = figures
	copy.enemies = enemies
	copy.regions = regions
	copy.bosses = bosses
	copy.fusion = fusion
	copy.meta = meta
	copy.items = items.duplicate(true)
	copy.locked_figures = locked.get("figures", []).duplicate()
	copy.banned_figures = locked.get("banned_figures", []).duplicate()
	var locked_relics: Array = locked.get("relics", [])
	copy.items["relics"] = copy.items["relics"].filter(func(r: Dictionary) -> bool: return not r["id"] in locked_relics)
	copy.items["tarot"] = copy.items["tarot"].filter(func(id: String) -> bool: return not id in locked.get("tarot", []))
	copy.items["pacts"] = copy.items["pacts"].filter(func(id: String) -> bool: return not id in locked.get("pacts", []))
	copy.items["events"]["ids"] = copy.items["events"]["ids"].filter(func(id: String) -> bool: return not id in locked.get("events", []))
	if pack_luck > 0:
		var chances: Dictionary = copy.items["packs"]["legend_chance"]
		for size in chances:
			chances[size] = float(chances[size]) * (1.0 + 0.5 * pack_luck)
	return copy


## Normal enemies (without boss figures) - the pool the generator draws from.
## act: only enemies that may appear in that act (elites have "min_act": 2).
func regular_enemies(act: int = 99) -> Array:
	return enemies.values().filter(func(e: Dictionary) -> bool:
		return not e.get("boss", false) and int(e.get("min_act", 1)) <= act)


## Bosses of a region for an act (the pool the boss is drawn from).
func bosses_for(region: String, act: int) -> Array:
	var result: Array = []
	for boss in bosses.values():
		if boss["region"] == region and int(boss["act"]) == act:
			result.append(boss)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return result


## Shown name: fusions carry a built name ("Glut-Henker"), others are translated.
static func display_name(definition: Dictionary) -> String:
	if definition.has("fusion_name"):
		return definition["fusion_name"]
	return TranslationServer.translate(name_key(definition))


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
