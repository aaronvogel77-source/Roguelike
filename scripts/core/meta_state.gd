class_name MetaState
extends RefCounted
## Progress across runs: Seelenglut, unlocked content, vault upgrades,
## occultists, cosmetics, challenges and the grimoire's discoveries.
## Pure data; the UI saves it to user://meta.json.

const SAVE_PATH := "user://meta.json"
const DISCOVERY_KINDS := ["figures", "relics", "tarot", "pacts", "masters", "recipes", "enemies"]

var glut := 0
## Content found in vault chests, as "kind:id" (e.g. "relics:death_bell").
var unlocked: Array = []
var upgrades: Dictionary = {}  # id -> level
var occultists: Array = ["novice"]
var cosmetics: Array = ["back_tarot", "stage_vault", "aura_suits"]
## Worn cosmetics: {"back", "stage", "aura", "skins": {figure id: skin id}}.
var equipped: Dictionary = {"back": "back_tarot", "stage": "stage_vault", "aura": "aura_suits", "skins": {}}
var challenges: Array = []
var discovered: Dictionary = {}  # kind -> [ids]
var runs := 0
var wins := 0


# --- Seelenglut ------------------------------------------------------------------

## Leftover souls -> Seelenglut: the first ones count fully, then half, then a
## quarter, with a cap per run (long runs must not pay endlessly).
static func glut_for_souls(db: ContentDb, souls: int) -> int:
	var rules: Dictionary = db.meta["conversion"]
	var full := int(rules["full"])
	var half := int(rules["half"])
	var value := float(mini(souls, full))
	value += 0.5 * clampi(souls - full, 0, half)
	value += float(rules["rest_share"]) * maxi(souls - full - half, 0)
	return mini(int(floor(value)), int(rules["cap"]))


## Ends a run: converts souls, checks challenges, counts the run.
## Returns {"glut", "occultists": [newly unlocked]}.
func finish_run(run: RunState) -> Dictionary:
	discover_from_run(run)
	var earned := glut_for_souls(run.db, run.souls)
	glut += earned
	runs += 1
	var won := run.stage == RunState.Stage.WON
	if won:
		wins += 1
	if run.act >= 2 or won:  # the act 1 boss fell
		_complete("beat_act1_boss")
	if won:
		_complete("win_run")
	var fresh: Array = []
	for entry in run.db.meta["occultists"]:
		if entry.has("challenge") and entry["challenge"] in challenges and not entry["id"] in occultists:
			occultists.append(entry["id"])
			fresh.append(entry["id"])
	return {"glut": earned, "occultists": fresh}


func _complete(challenge: String) -> void:
	if not challenge in challenges:
		challenges.append(challenge)


# --- Locked content ----------------------------------------------------------------

func is_unlocked(kind: String, id: String) -> bool:
	return ("%s:%s" % [kind, id]) in unlocked


## Locked content for a new run (everything in the lock lists not yet found).
func locked_content(db: ContentDb) -> Dictionary:
	var result := {}
	var lists: Dictionary = db.meta["locked"]
	for kind in lists:
		result[kind] = lists[kind].filter(func(id: String) -> bool: return not is_unlocked(kind, id))
	return result


## Options for RunState.new_run.
func run_options(db: ContentDb, occultist: String) -> Dictionary:
	return {"occultist": occultist if occultist in occultists else "novice",
		"locked": locked_content(db), "upgrades": upgrades.duplicate()}


# --- Vault: chests, upgrades, occultists, cosmetics ---------------------------------

static func chest(db: ContentDb, id: String) -> Dictionary:
	for entry in db.meta["chests"]:
		if entry["id"] == id:
			return entry
	return {}


## Everything a chest can contain, as [kind, id] pairs.
static func chest_pool(db: ContentDb, id: String) -> Array:
	var pool: Array = []
	for kind in chest(db, id).get("pools", []):
		if kind == "skins":
			for cosmetic in db.meta["cosmetics"]:
				if cosmetic["kind"] == "skin":
					pool.append(["skins", cosmetic["id"]])
		else:
			for content_id in db.meta["locked"].get(kind, []):
				pool.append([kind, content_id])
	return pool


## Opens a chest: 3 draws, new finds are unlocked, duplicates give glut back.
## Returns [{"kind", "id", "new"}] or [] when it cannot be afforded.
func open_chest(db: ContentDb, id: String, rng: RandomNumberGenerator) -> Array:
	var price := int(chest(db, id).get("price", 0))
	var pool := chest_pool(db, id)
	if pool.is_empty() or glut < price:
		return []
	glut -= price
	# Legendary skins are very rare: each draw finds one only with a small chance.
	var skins := pool.filter(func(p: Array) -> bool: return p[0] == "skins")
	var others := pool.filter(func(p: Array) -> bool: return p[0] != "skins")
	var results: Array = []
	for i in int(db.meta["chest_size"]):
		var from := others
		if others.is_empty() or (not skins.is_empty() and rng.randf() < float(db.meta.get("legendary_skin_weight", 0.05))):
			from = skins
		var pick: Array = from[rng.randi_range(0, from.size() - 1)]
		var kind: String = pick[0]
		var content_id: String = pick[1]
		var fresh := not (content_id in cosmetics if kind == "skins" else is_unlocked(kind, content_id))
		if fresh:
			if kind == "skins":
				cosmetics.append(content_id)
			else:
				unlocked.append("%s:%s" % [kind, content_id])
		else:
			glut += int(db.meta["duplicate_refund"])
		results.append({"kind": kind, "id": content_id, "new": fresh})
	return results


static func upgrade(db: ContentDb, id: String) -> Dictionary:
	for entry in db.meta["upgrades"]:
		if entry["id"] == id:
			return entry
	return {}


## Price of the next level, or -1 at the maximum.
func upgrade_price(db: ContentDb, id: String) -> int:
	var prices: Array = upgrade(db, id).get("prices", [])
	var level := int(upgrades.get(id, 0))
	return int(prices[level]) if level < prices.size() else -1


func buy_upgrade(db: ContentDb, id: String) -> bool:
	var price := upgrade_price(db, id)
	if price < 0 or glut < price:
		return false
	glut -= price
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	return true


static func occultist(db: ContentDb, id: String) -> Dictionary:
	for entry in db.meta["occultists"]:
		if entry["id"] == id:
			return entry
	return {}


func buy_occultist(db: ContentDb, id: String) -> bool:
	var price := int(occultist(db, id).get("price", -1))
	if id in occultists or price < 0 or glut < price:
		return false
	glut -= price
	occultists.append(id)
	return true


static func cosmetic(db: ContentDb, id: String) -> Dictionary:
	for entry in db.meta["cosmetics"]:
		if entry["id"] == id:
			return entry
	return {}


func buy_cosmetic(db: ContentDb, id: String) -> bool:
	var price := int(cosmetic(db, id).get("price", -1))
	if id in cosmetics or price < 0 or glut < price:
		return false
	glut -= price
	cosmetics.append(id)
	return true


## Wears a cosmetic (a skin toggles on its figure).
func equip(db: ContentDb, id: String) -> bool:
	if not id in cosmetics:
		return false
	var entry := cosmetic(db, id)
	if entry["kind"] == "skin":
		var skins: Dictionary = equipped["skins"]
		if skins.get(entry["figure"], "") == id:
			skins.erase(entry["figure"])
		else:
			skins[entry["figure"]] = id
	else:
		equipped[entry["kind"]] = id
	return true


# --- Grimoire ----------------------------------------------------------------------

func discover(kind: String, id: String) -> void:
	if id == "":
		return
	if not discovered.has(kind):
		discovered[kind] = []
	if not id in discovered[kind]:
		discovered[kind].append(id)


func is_discovered(kind: String, id: String) -> bool:
	return id in discovered.get(kind, [])


## Collects everything the run has shown the player so far.
func discover_from_run(run: RunState) -> void:
	for figure in run.row:
		if figure == null:
			continue
		discover("figures", figure["def_id"])
		if run.db.figures[figure["def_id"]].get("recipe", false):
			discover("recipes", figure["def_id"])
		if figure.has("fusion"):
			for part in figure["fusion"]["parts"]:
				discover("figures", part)
			var definition := Fusion.definition(run.db, figure)
			discover("masters", definition["fusion"]["master"])
	for id in run.shop:
		discover("figures", id)
	for id in run.relics:
		discover("relics", id)
	for id in run.tarots:
		discover("tarot", id)
	for id in run.pacts:
		discover("pacts", id)
	for option in run.enemy_options:
		for unit in option.get("team", []):
			discover("enemies", unit["def_id"])


# --- Saving ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"glut": glut, "unlocked": unlocked, "upgrades": upgrades, "occultists": occultists,
		"cosmetics": cosmetics, "equipped": equipped, "challenges": challenges, "discovered": discovered,
		"runs": runs, "wins": wins}


static func from_dict(data: Dictionary) -> MetaState:
	var meta := MetaState.new()
	meta.glut = int(data.get("glut", 0))
	meta.unlocked = data.get("unlocked", []).duplicate()
	meta.upgrades = data.get("upgrades", {}).duplicate()
	for key in meta.upgrades:
		meta.upgrades[key] = int(meta.upgrades[key])
	meta.occultists = data.get("occultists", ["novice"]).duplicate()
	meta.cosmetics = data.get("cosmetics", meta.cosmetics).duplicate()
	meta.equipped = data.get("equipped", meta.equipped).duplicate(true)
	meta.challenges = data.get("challenges", []).duplicate()
	meta.discovered = data.get("discovered", {}).duplicate(true)
	meta.runs = int(data.get("runs", 0))
	meta.wins = int(data.get("wins", 0))
	return meta


static func load_saved(path: String = SAVE_PATH) -> MetaState:
	if not FileAccess.file_exists(path):
		return MetaState.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(data) if data is Dictionary else MetaState.new()


func save(path: String = SAVE_PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_dict()))
