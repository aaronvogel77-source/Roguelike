class_name RunState
extends RefCounted
## The complete state of one run plus every player action on it.
## Pure logic: no UI, fully serializable (save games in M7, undo in M3).
##
## Cycle: ENEMY_CHOICE → PLANNING (shop) → battle → REWARD → ENEMY_CHOICE ...
## A lost battle ends the run (LOST); beating the last boss wins it (WON).

enum Stage { ENEMY_CHOICE, PLANNING, REWARD, WON, LOST, EVENT }

const ACTS := 2  # vertical slice: one region, two acts
const FIGHTS_PER_ACT := 3
const START_GOLD := 8
const START_SLOTS := 3
const MAX_SLOTS := 6
## Shop price by rank (page, knight, queen, king).
const RANK_PRICES := {"page": 3, "knight": 4, "queen": 6, "king": 8, "legend": 10}
const SHOP_FIGURE_SLOTS := 3
const BASE_INCOME := 4
const GOLD_PER_INTEREST := 5
const MAX_INTEREST := 5
const SHOP_PACK_SLOTS := 2
const MAX_RELICS := 3
const MAX_TAROTS := 2
const MAX_PACTS := 3
const BOSS_SOULS := 2
const DEATH_SOUL_CHANCE := 0.05
## Objects per figure (equipment, blessing, each Strength card).
const MAX_OBJECTS := 2
const KILL_SOUL_CHANCE := 0.25  # Soul Hunger pact
## Soul value of a sacrificed figure: rank value + level.
const RANK_SOUL_VALUE := {"page": 1, "knight": 2, "queen": 3, "king": 4, "legend": 5}
const REWARD_CHOICES := 3
const REWARD_SKIP_GOLD := 2
## Experience is counted in thirds: a duplicate gives 3 (= 1 XP), a win 1 (= 1/3 XP).
const XP_PER_DUPLICATE := 3
const XP_PER_WIN := 1
const XP_FOR_LEVEL := [0, 9, 18]
const RANKS := ["page", "knight", "queen", "king"]
## Shop rank odds in percent (page, knight, queen, king) from the given act on.
const RANK_ODDS := [
	[1, [68, 25, 5, 2]],
	[2, [50, 32, 14, 4]],
	[3, [40, 33, 20, 7]],
	[5, [30, 33, 25, 12]],
]

var db: ContentDb
var rng: RngStreams
var stage: Stage = Stage.ENEMY_CHOICE
## Region (tarot suit) of the current act. The slice only has the coin region.
var region := "coins"
var act := 1
var fight := 0  # 0 = small, 1 = big, 2 = boss
var gold := START_GOLD
## Battle row, front first. Each entry is null or {"uid", "def_id", "xp"} plus
## optional "equipment", "blessing", "bonus_attack", "bonus_health", "suit".
var row: Array = []
## Shop offers: figure ids, "" for a bought slot.
var shop: Array = []
## Shop packs: {"type", "size"} or {} once bought.
var packs: Array = []
## The pack being opened: {"pack", "items", "picks_left"} or {}.
var open_pack: Dictionary = {}
var relics: Array = []  # relic ids, max 3
var tarots: Array = []  # tarot ids, max 2
var pacts: Array = []  # pact ids, max 3
var souls := 0
## One-shot effects for the next shop (from skip marks): "mega_pack", "royal_shop".
var next_shop: Array = []
## Run-wide flags, e.g. "no_boss_rule" (fortune teller).
var flags: Dictionary = {}
## Current event: {"id", "used": [options], "resolved", "result", ...offers} or {}.
var event: Dictionary = {}
var fights_since_event := 0
var reroll_count := 0
var enemy_options: Array = []
var chosen_enemy: Dictionary = {}
var rewards: Array = []
var next_uid := 1
var battles_won := 0
## Breakdown of the last payout, for the UI.
var last_income: Dictionary = {}


static func new_run(content: ContentDb, seed_value: int) -> RunState:
	var run := RunState.new()
	run.db = content
	run.rng = RngStreams.new(seed_value)
	run.row.resize(START_SLOTS)
	var pages := run._figure_ids_of_rank("page")
	var start_id: String = pages[run.rng.stream("start").randi_range(0, pages.size() - 1)]
	run.row[0] = run._new_figure(start_id)
	run._roll_enemy_options()
	return run


# --- Queries ---------------------------------------------------------------------

func slot_count() -> int:
	return row.size()


static func level_for_xp(xp: int) -> int:
	if xp >= XP_FOR_LEVEL[2]:
		return 3
	if xp >= XP_FOR_LEVEL[1]:
		return 2
	return 1


func figure_level(figure: Dictionary) -> int:
	return level_for_xp(int(figure["xp"]))


func reroll_price() -> int:
	return 1 + reroll_count + (1 if "golden_oath" in pacts else 0)


## Objects on a figure: equipment, blessing and every Strength card.
func figure_objects(figure: Dictionary) -> int:
	return (1 if figure.has("equipment") else 0) + (1 if figure.has("blessing") else 0) + int(figure.get("strength", 0))


func object_limit(figure: Dictionary) -> int:
	return MAX_OBJECTS + int(figure.get("extra_object_slots", 0))


## Whether a new object fits (replacing equipment/blessing does not count).
func can_add_object(figure: Dictionary, kind: String) -> bool:
	if kind == "equipment" and figure.has("equipment"):
		return true
	if kind == "blessing" and figure.has("blessing"):
		return true
	return figure_objects(figure) < object_limit(figure)


## Tarot suit of a figure (the Wheel of Fortune can change it).
func figure_suit(figure: Dictionary) -> String:
	return figure.get("suit", db.figures[figure["def_id"]]["suit"])


func price_of(def_id: String) -> int:
	return RANK_PRICES[db.figures[def_id]["rank"]]


## Half the rank price (rounded down) plus 1 per level above 1.
func sell_value(figure: Dictionary) -> int:
	return price_of(figure["def_id"]) / 2 + figure_level(figure) - 1


func interest_cap() -> int:
	var cap := MAX_INTEREST
	if "golden_oath" in pacts:
		cap = 10
	if "return_pact" in pacts:
		cap = mini(cap, 3)
	return cap


func interest() -> int:
	return mini(gold / GOLD_PER_INTEREST, interest_cap())


func is_boss_fight() -> bool:
	return fight == 2


func can_place(def_id: String, row_index: int) -> bool:
	if row_index < 0 or row_index >= row.size():
		return false
	var target: Variant = row[row_index]
	# Merging is only possible below the maximum level.
	return target == null or (target["def_id"] == def_id and figure_level(target) < 3)


## Battle entries for the simulator, front first, with all run modifiers.
func player_battle_team() -> Array:
	return TeamBuilder.player_team(self)


func enemy_battle_team() -> Array:
	return chosen_enemy.get("team", []).map(func(u: Dictionary) -> Dictionary:
		return {"def": db.enemies[u["def_id"]], "level": u["level"]})


# --- Actions (each returns true on success) ---------------------------------------

func choose_enemy(index: int) -> bool:
	if stage != Stage.ENEMY_CHOICE or index < 0 or index >= enemy_options.size():
		return false
	chosen_enemy = enemy_options[index].duplicate(true)
	# The fortune teller can cancel the next boss rule.
	if chosen_enemy.get("kind", "") == "boss" and flags.get("no_boss_rule", false):
		chosen_enemy["rule"] = ""
		flags.erase("no_boss_rule")
	stage = Stage.PLANNING
	reroll_count = 0
	_roll_shop()
	return true


## Buys a shop figure into a row slot: an empty slot places it, a slot with
## the same figure merges it (+1 XP).
func buy(shop_index: int, row_index: int) -> bool:
	if stage != Stage.PLANNING or shop_index < 0 or shop_index >= shop.size():
		return false
	var def_id: String = shop[shop_index]
	if def_id == "" or gold < price_of(def_id) or not can_place(def_id, row_index):
		return false
	gold -= price_of(def_id)
	shop[shop_index] = ""
	_place(def_id, row_index)
	return true


## Selling works while planning and on the reward screen (to make room).
func sell(row_index: int) -> bool:
	if stage not in [Stage.PLANNING, Stage.REWARD, Stage.EVENT] or row_index < 0 or row_index >= row.size() or row[row_index] == null:
		return false
	gold += sell_value(row[row_index])
	row[row_index] = null
	return true


## Moves a figure. Onto an equal figure below max level it merges (the moved
## copy's experience plus one duplicate); onto another figure the two swap.
func move(from_index: int, to_index: int) -> bool:
	if stage not in [Stage.PLANNING, Stage.REWARD] or from_index == to_index:
		return false
	if from_index < 0 or to_index < 0 or from_index >= row.size() or to_index >= row.size():
		return false
	if row[from_index] == null:
		return false
	var target: Variant = row[to_index]
	if target != null and target["def_id"] == row[from_index]["def_id"] and figure_level(target) < 3:
		var combined := int(target["xp"]) + int(row[from_index]["xp"]) + XP_PER_DUPLICATE
		target["xp"] = mini(combined, XP_FOR_LEVEL[2])
		row[from_index] = null
		return true
	var moving: Variant = row[from_index]
	row[from_index] = row[to_index]
	row[to_index] = moving
	return true


## Inserts a figure between two others: it ends up directly behind the figure
## at after_index (-1 = at the very front); the figures in between shift.
func insert_between(from_index: int, after_index: int) -> bool:
	if stage not in [Stage.PLANNING, Stage.REWARD] or from_index < 0 or from_index >= row.size() or row[from_index] == null:
		return false
	if after_index < -1 or after_index >= row.size():
		return false
	var target := after_index + 1
	if target == from_index or target == from_index + 1:
		return false  # already there
	var moving: Variant = row[from_index]
	var order := row.duplicate()
	order.remove_at(from_index)
	if from_index < target:
		target -= 1
	order.insert(target, moving)
	row = order
	return true


## Rerolls the figure offers only; packs stay until the next shop.
func reroll() -> bool:
	if stage != Stage.PLANNING or gold < reroll_price():
		return false
	gold -= reroll_price()
	reroll_count += 1
	shop.clear()
	for i in SHOP_FIGURE_SLOTS:
		shop.append(_random_figure_id(rng.stream("shop")))
	return true


# --- Souls, pacts, skipping ---------------------------------------------------------

## Souls from a won battle: 10 % per fallen own figure, Soul Hunger 25 % per kill.
func _collect_souls(result: Dictionary) -> void:
	var stream := rng.stream("souls")
	var gained := 0
	for event in result.get("events", []):
		if event["type"] != "removed":
			continue
		if event["side"] == BattleSimulator.PLAYER and stream.randf() < DEATH_SOUL_CHANCE:
			gained += 1
		elif event["side"] == BattleSimulator.ENEMY and "soul_hunger" in pacts and stream.randf() < KILL_SOUL_CHANCE:
			gained += 1
	souls += gained
	last_income["souls"] = gained


func soul_pack_price() -> int:
	return int(db.items["packs"]["soul_pack"]["price_souls"]) + (1 if "soul_hunger" in pacts else 0)


## Seelen-Pack: pacts you do not own yet, pick one.
func buy_soul_pack() -> bool:
	if stage != Stage.PLANNING or not open_pack.is_empty() or souls < soul_pack_price() or pacts.size() >= MAX_PACTS:
		return false
	souls -= soul_pack_price()
	open_pacts(int(db.items["packs"]["soul_pack"]["choices"]))
	return true


func open_pacts(count: int) -> void:
	var pool: Array = db.items["pacts"].filter(func(id: String) -> bool: return not id in pacts)
	var items: Array = []
	var stream := rng.stream("pact_contents")
	for i in mini(count, pool.size()):
		var index := stream.randi_range(0, pool.size() - 1)
		items.append({"kind": "pact", "id": pool[index]})
		pool.remove_at(index)
	open_pack = {"pack": {"type": "soul", "size": "normal"}, "items": items, "picks_left": 1}


## Gives a pact back (soul trader): +2 souls.
func return_pact(index: int) -> bool:
	if index < 0 or index >= pacts.size():
		return false
	pacts.remove_at(index)
	souls += 2
	return true


## Skips a normal fight for its mark (no gold, no experience, no event).
func skip_fight() -> bool:
	if stage != Stage.ENEMY_CHOICE or is_boss_fight() or enemy_options.is_empty():
		return false
	match enemy_options[0].get("skip_mark", ""):
		"souls":
			souls += 2
		"experience":
			for figure in row:
				if figure != null:
					figure["xp"] = mini(int(figure["xp"]) + XP_PER_DUPLICATE, XP_FOR_LEVEL[2])
		"mega_pack", "royal_shop":
			next_shop.append(enemy_options[0]["skip_mark"])
	_advance_fight()
	_next_enemy_choice()
	return true


## Skips an act boss by sacrificing a figure (no slot, no souls).
## The last boss of the run cannot be skipped.
func can_skip_boss() -> bool:
	return stage == Stage.PLANNING and is_boss_fight() and act < ACTS


func skip_boss(sacrifice_index: int) -> bool:
	if not can_skip_boss() or sacrifice_index < 0 or sacrifice_index >= row.size() or row[sacrifice_index] == null:
		return false
	row[sacrifice_index] = null
	_advance_fight()
	_next_enemy_choice()
	return true


func _advance_fight() -> void:
	fight += 1
	if fight >= FIGHTS_PER_ACT:
		fight = 0
		act += 1


func _next_enemy_choice() -> void:
	stage = Stage.ENEMY_CHOICE
	_roll_enemy_options()
	if is_boss_fight() and enemy_options.size() == 1:
		choose_enemy(0)


# --- Events ------------------------------------------------------------------------

## After a won battle: ~40 % chance, guaranteed after 3 battles without one.
func _roll_event() -> bool:
	var rules: Dictionary = db.items["events"]
	fights_since_event += 1
	var stream := rng.stream("events")
	if stream.randf() >= float(rules["chance"]) and fights_since_event < int(rules["pity_after"]):
		return false
	fights_since_event = 0
	var ids: Array = rules["ids"]
	start_event(ids[stream.randi_range(0, ids.size() - 1)])
	return true


## Starts an event (also used by tests and the debug menu).
func start_event(id: String) -> void:
	var stream := rng.stream("events")
	event = {"id": id, "used": [], "resolved": false, "result": ""}
	match id:
		"black_market":
			var relic_pool: Array = db.items["relics"].map(func(r: Dictionary) -> String: return r["id"]).filter(
				func(r: String) -> bool: return not r in relics)
			event["relic"] = relic_pool[stream.randi_range(0, relic_pool.size() - 1)] if not relic_pool.is_empty() else ""
			var types := ["equipment", "arcana", "relic"]
			event["pack_type"] = types[stream.randi_range(0, types.size() - 1)]
			var royals := _figure_ids_of_rank("queen") + _figure_ids_of_rank("king")
			event["figure"] = royals[stream.randi_range(0, royals.size() - 1)]
		"duel":
			var budget := int(round(EnemyGenerator.budget(act, 1, 2) * 1.2))
			event["team"] = EnemyGenerator.generate(db, budget, rng.stream("enemy_gen"), "")
	stage = Stage.EVENT


## Price/requirement check for an event option ("" = available, else a reason key).
func event_option_block(option: String, targets: Array = []) -> String:
	if event.is_empty() or (event["resolved"] and option != "leave"):
		return "done"
	if option in event["used"]:
		return "done"
	var figures := targets.filter(func(i: int) -> bool: return i >= 0 and i < row.size() and row[i] != null)
	match option:
		"sacrifice_one", "drink", "train":
			return "" if figures.size() == 1 else "target"
		"sacrifice_two":
			return "" if figures.size() == 2 and figures[0] != figures[1] and pacts.size() < MAX_PACTS else "target"
		"buy_relic":
			return "" if gold >= 4 and relics.size() < MAX_RELICS and event.get("relic", "") != "" else "cost"
		"buy_pack":
			return "" if gold >= 6 else "cost"
		"buy_figure":
			if gold < price_of(event["figure"]) / 2:
				return "cost"
			return "" if targets.size() == 1 and can_place(event["figure"], targets[0]) else "target"
		"throw_3", "throw_6", "throw_10":
			return "" if gold >= int(option.split("_")[1]) else "cost"
		"mega_arcana":
			return "" if souls >= 1 else "cost"
		"duplicate":
			if souls < 2 or not row.has(null):
				return "cost"
			return "" if figures.size() == 1 else "target"
		"soul_to_gold":
			return "" if souls >= 1 else "cost"
		"gold_to_soul":
			return "" if gold >= 5 else "cost"
		"return_pact":
			return "" if targets.size() == 1 and targets[0] < pacts.size() else "target"
	return ""


## Resolves an event option. Most options end the event; shops and the soul
## trader allow several actions until "leave".
func resolve_event(option: String, targets: Array = []) -> bool:
	if event_option_block(option, targets) != "":
		return false
	var final := true
	match option:
		"leave":
			event = {}
			_next_enemy_choice()
			return true
		"sacrifice_one":
			var figure: Dictionary = row[targets[0]]
			souls += RANK_SOUL_VALUE[db.figures[figure["def_id"]]["rank"]] + figure_level(figure)
			row[targets[0]] = null
		"sacrifice_two":
			row[targets[0]] = null
			row[targets[1]] = null
			open_pacts(3)
		"buy_relic":
			gold -= 4
			relics.append(event["relic"])
			final = false
		"buy_pack":
			gold -= 6
			_open({"type": event["pack_type"], "size": "mega"}, false)
			final = false
		"buy_figure":
			gold -= price_of(event["figure"]) / 2
			_place(event["figure"], targets[0])
			final = false
		"throw_3", "throw_6", "throw_10":
			# 3 gold: magic item, 6: rare item, 10: pick one of three rare items.
			var amount := int(option.split("_")[1])
			gold -= amount
			var rarity: int = Items.RARITY_MAGIC if amount == 3 else Items.RARITY_RARE
			var items: Array = []
			for i in (3 if amount == 10 else 1):
				items.append({"kind": "equipment", "item": Items.roll_equipment(db, act, rng.stream("events"), 0, rarity)})
			open_pack = {"pack": {"type": "equipment", "size": "normal"}, "items": items, "picks_left": 1}
		"drink":
			var figure: Dictionary = row[targets[0]]
			figure["bonus_attack"] = int(figure.get("bonus_attack", 0)) + 3
			figure["bonus_health"] = int(figure.get("bonus_health", 0)) + 3
			figure["cursed"] = true
		"tarot":
			_open({"type": "arcana", "size": "normal"}, false)
		"no_boss_rule":
			flags["no_boss_rule"] = true
		"mega_arcana":
			souls -= 1
			_open({"type": "arcana", "size": "mega"}, false)
		"rob":
			gold += 8
			var pool: Array = db.items["relics"].map(func(r: Dictionary) -> String: return r["id"]).filter(
				func(r: String) -> bool: return not r in relics)
			if relics.size() < MAX_RELICS and not pool.is_empty():
				relics.append(pool[rng.stream("events").randi_range(0, pool.size() - 1)])
			else:
				gold += 4
			for i in range(row.size() - 1, -1, -1):
				if row[i] != null:
					row[i] = null
					break
		"small":
			gold += 3
		"duplicate":
			souls -= 2
			_place(row[targets[0]]["def_id"], row.find(null))
		"train":
			row[targets[0]]["xp"] = mini(int(row[targets[0]]["xp"]) + XP_PER_DUPLICATE, XP_FOR_LEVEL[2])
		"soul_to_gold":
			souls -= 1
			gold += 5
			final = false
		"gold_to_soul":
			gold -= 5
			souls += 1
			final = false
		"return_pact":
			return_pact(targets[0])
			final = false
		"fight":
			return true  # the UI plays the duel, then calls apply_duel_result()
		"decline":
			pass
		_:
			return false
	if final:
		event["resolved"] = true
	elif option in ["buy_relic", "buy_pack", "buy_figure"]:
		event["used"].append(option)  # each offer can be bought once
	return true


## Duel opponent team as battle entries.
func duel_team() -> Array:
	return event.get("team", []).map(func(u: Dictionary) -> Dictionary:
		return {"def": db.enemies[u["def_id"]], "level": u["level"]})


## Win: a relic (or gold) and 2 souls. Loss: the front figure is lost, not the run.
func apply_duel_result(result: Dictionary) -> void:
	gold = int(result.get("gold_after", gold))
	if result["victory"]:
		souls += 2
		var pool: Array = db.items["relics"].map(func(r: Dictionary) -> String: return r["id"]).filter(
			func(r: String) -> bool: return not r in relics)
		if relics.size() < MAX_RELICS and not pool.is_empty():
			relics.append(pool[rng.stream("events").randi_range(0, pool.size() - 1)])
			event["result"] = "duel_won_relic"
		else:
			gold += 3
			event["result"] = "duel_won_gold"
	else:
		for i in row.size():
			if row[i] != null:
				row[i] = null
				break
		event["result"] = "duel_lost"
	event["resolved"] = true


# --- Packs, relics, tarot ----------------------------------------------------------

## Buys and opens a pack. Its contents wait in open_pack until picked.
## force_legend: debug tool for testing legendary figures.
func buy_pack(index: int, force_legend: bool = false) -> bool:
	if stage != Stage.PLANNING or not open_pack.is_empty() or index < 0 or index >= packs.size():
		return false
	var pack: Dictionary = packs[index]
	if pack.is_empty() or gold < pack_cost(pack):
		return false
	gold -= pack_cost(pack)
	packs[index] = {}
	_open(pack, force_legend)
	return true


func pack_cost(pack: Dictionary) -> int:
	return 0 if pack.get("free", false) else Items.pack_price(db, pack)


## Debug: opens a free mega arcana pack whose first card is legendary.
func debug_legend_pack() -> void:
	_open({"type": "arcana", "size": "mega"}, true)


func _open(pack: Dictionary, force_legend: bool) -> void:
	open_pack = {
		"pack": pack,
		"items": Items.pack_contents(db, pack, act, rng.stream("pack_contents"), relics, force_legend),
		"picks_left": Items.pack_picks(db, pack),
	}


## Whether a pack item can be taken; target_index is a row slot where needed.
func can_take_pack_item(item_index: int, target_index: int = -1) -> bool:
	if open_pack.is_empty() or item_index < 0 or item_index >= open_pack["items"].size():
		return false
	var entry: Dictionary = open_pack["items"][item_index]
	if entry.get("taken", false):
		return false
	match entry["kind"]:
		"equipment":
			return target_index >= 0 and target_index < row.size() and row[target_index] != null \
				and can_add_object(row[target_index], "equipment")
		"tarot":
			return tarots.size() < MAX_TAROTS
		"relic":
			return relics.size() < MAX_RELICS
		"pact":
			return pacts.size() < MAX_PACTS
		"figure":
			return can_place(entry["def_id"], target_index)
	return false


## Kind of target a pack item needs: "figure" (row figure), "slot" (row slot) or "".
func pack_item_target(item_index: int) -> String:
	var kind: String = open_pack["items"][item_index]["kind"]
	if kind == "equipment":
		return "figure"
	if kind == "figure":
		return "slot"
	return ""


func take_pack_item(item_index: int, target_index: int = -1) -> bool:
	if not can_take_pack_item(item_index, target_index):
		return false
	var entry: Dictionary = open_pack["items"][item_index]
	match entry["kind"]:
		"equipment":
			row[target_index]["equipment"] = entry["item"].duplicate(true)
		"tarot":
			tarots.append(entry["id"])
		"relic":
			relics.append(entry["id"])
		"pact":
			pacts.append(entry["id"])
		"figure":
			_place(entry["def_id"], target_index)
	entry["taken"] = true
	open_pack["picks_left"] = int(open_pack["picks_left"]) - 1
	if open_pack["picks_left"] <= 0:
		open_pack = {}
	return true


func close_pack() -> void:
	open_pack = {}


func sell_relic(index: int) -> bool:
	if index < 0 or index >= relics.size():
		return false
	gold += Items.relic_price(db, relics[index]) / 2
	relics.remove_at(index)
	return true


## Uses a tarot card on a row figure.
func use_tarot(tarot_index: int, row_index: int) -> bool:
	if stage != Stage.PLANNING or tarot_index < 0 or tarot_index >= tarots.size():
		return false
	if row_index < 0 or row_index >= row.size() or row[row_index] == null:
		return false
	var figure: Dictionary = row[row_index]
	var card: String = tarots[tarot_index]
	if card == "strength" and not can_add_object(figure, "strength"):
		return false
	if card in ["star", "sun"] and not can_add_object(figure, "blessing"):
		return false
	match card:
		"strength":
			figure["bonus_attack"] = int(figure.get("bonus_attack", 0)) + 2
			figure["bonus_health"] = int(figure.get("bonus_health", 0)) + 2
			figure["strength"] = int(figure.get("strength", 0)) + 1
		"magician":
			figure["xp"] = mini(int(figure["xp"]) + XP_PER_DUPLICATE, XP_FOR_LEVEL[2])
		"star":
			figure["blessing"] = "star"
		"sun":
			figure["blessing"] = "sun"
		"hanged_man":
			gold += price_of(figure["def_id"])
			row[row_index] = null
		"wheel_of_fortune":
			var suits := ContentDb.SUITS.filter(func(s: String) -> bool: return s != figure_suit(figure))
			figure["suit"] = suits[rng.stream("tarot").randi_range(0, suits.size() - 1)]
		_:
			return false
	tarots.remove_at(tarot_index)
	return true


## Rule of the chosen boss ("" for normal fights).
func boss_rule() -> String:
	return chosen_enemy.get("rule", "")


## Battle options: region blessing and boss rules.
func battle_options() -> Dictionary:
	var options := {}
	var blessing: Dictionary = db.regions.get(region, {}).get("blessing", {})
	if not blessing.is_empty():
		options["blessing"] = blessing
	if boss_rule() == "gold_zero":
		options["gold_zero"] = true
	var status_bonus := TeamBuilder.status_bonus(self)
	if not status_bonus.is_empty():
		options["status_bonus"] = status_bonus
	if "golden_oath" in pacts:
		options["gold_factor"] = 2
	if "ash_pact" in pacts:
		options["burn_factor_vs_enemy"] = 2.0
		options["burn_spread"] = true
	if "blade_oath" in pacts:
		options["bleed_factor"] = 2
		options["player_heal_factor"] = 0.75
	if "return_pact" in pacts:
		options["team_revives"] = 2
	return options


## Applies a finished battle. Returns the new stage.
func apply_battle_result(result: Dictionary) -> Stage:
	gold = int(result.get("gold_after", gold))
	if not result["victory"]:
		stage = Stage.LOST
		return stage
	battles_won += 1
	_collect_souls(result)
	for figure in row:
		if figure != null:
			figure["xp"] = mini(int(figure["xp"]) + XP_PER_WIN, XP_FOR_LEVEL[2])
	var paid_interest := interest()
	var bonus := int(chosen_enemy.get("bonus", 0))
	var extra := TeamBuilder.gold_after_win(self)
	gold = maxi(gold + BASE_INCOME + bonus + paid_interest + extra, 0)
	last_income = {"base": BASE_INCOME, "bonus": bonus, "interest": paid_interest, "extra": extra}
	if is_boss_fight():
		souls += BOSS_SOULS
		last_income["souls"] = int(last_income.get("souls", 0)) + BOSS_SOULS
		if slot_count() < MAX_SLOTS:
			row.append(null)
			last_income["slot"] = true
	fight += 1
	if fight >= FIGHTS_PER_ACT:
		fight = 0
		act += 1
	if act > ACTS:
		stage = Stage.WON
		return stage
	stage = Stage.REWARD
	_roll_rewards()
	return stage


## Takes a reward figure: merges into a matching figure, else the first free slot.
func take_reward(index: int) -> bool:
	if stage != Stage.REWARD or index < 0 or index >= rewards.size():
		return false
	var target := reward_target(rewards[index])
	if target < 0:
		return false
	_place(rewards[index], target)
	_finish_reward()
	return true


func skip_reward() -> bool:
	if stage != Stage.REWARD:
		return false
	gold += REWARD_SKIP_GOLD
	_finish_reward()
	return true


## Row slot a reward would go to, or -1 if there is no room.
func reward_target(def_id: String) -> int:
	for i in row.size():
		if row[i] != null and row[i]["def_id"] == def_id and figure_level(row[i]) < 3:
			return i
	for i in row.size():
		if row[i] == null:
			return i
	return -1


# --- Internals --------------------------------------------------------------------

func _finish_reward() -> void:
	rewards.clear()
	if _roll_event():
		return
	# A boss is not chosen: the run goes straight to its shop.
	_next_enemy_choice()


func _place(def_id: String, row_index: int) -> void:
	if row[row_index] == null:
		row[row_index] = _new_figure(def_id)
	else:
		row[row_index]["xp"] = mini(int(row[row_index]["xp"]) + XP_PER_DUPLICATE, XP_FOR_LEVEL[2])


func _new_figure(def_id: String) -> Dictionary:
	var figure := {"uid": next_uid, "def_id": def_id, "xp": 0}
	next_uid += 1
	return figure


func _roll_enemy_options() -> void:
	enemy_options = EnemyGenerator.options(db, region, act, fight, rng.stream("enemy_gen"))
	if not is_boss_fight():
		var marks: Array = db.items["marks"]
		var mark: String = marks[rng.stream("marks").randi_range(0, marks.size() - 1)]
		for option in enemy_options:
			option["skip_mark"] = mark
	chosen_enemy = {}


func _roll_shop() -> void:
	shop.clear()
	for i in SHOP_FIGURE_SLOTS:
		shop.append(_random_figure_id(rng.stream("shop")))
	packs.clear()
	for i in SHOP_PACK_SLOTS:
		packs.append(Items.roll_pack(db, rng.stream("packs")))
	# Skip marks: a free mega pack / two guaranteed queens or kings.
	if "mega_pack" in next_shop:
		packs[0] = {"type": packs[0]["type"], "size": "mega", "free": true}
	if "royal_shop" in next_shop:
		var royals := _figure_ids_of_rank("queen") + _figure_ids_of_rank("king")
		for i in 2:
			shop[i] = royals[rng.stream("shop").randi_range(0, royals.size() - 1)]
	next_shop.clear()


func _roll_rewards() -> void:
	rewards.clear()
	for i in REWARD_CHOICES:
		rewards.append(_random_figure_id(rng.stream("rewards")))


func _random_figure_id(stream: RandomNumberGenerator) -> String:
	var odds: Array = RANK_ODDS[0][1]
	for entry in RANK_ODDS:
		if act >= entry[0]:
			odds = entry[1]
	var roll := stream.randi_range(1, 100)
	var rank_index := 0
	var total := 0
	for i in odds.size():
		total += odds[i]
		if roll <= total:
			rank_index = i
			break
	var candidates := _figure_ids_of_rank(RANKS[rank_index])
	return candidates[stream.randi_range(0, candidates.size() - 1)]


func _figure_ids_of_rank(rank: String) -> Array:
	var ids: Array = []
	for figure in db.regular_figures():
		if figure["rank"] == rank:
			ids.append(figure["id"])
	ids.sort()
	return ids


# --- Serialization (undo now, save games in M7) -------------------------------------

func to_dict() -> Dictionary:
	return {
		"rng": rng.to_dict(), "stage": stage, "region": region, "act": act, "fight": fight, "gold": gold,
		"row": row.duplicate(true), "shop": shop.duplicate(), "packs": packs.duplicate(true),
		"open_pack": open_pack.duplicate(true), "relics": relics.duplicate(), "tarots": tarots.duplicate(),
		"pacts": pacts.duplicate(), "souls": souls, "next_shop": next_shop.duplicate(), "flags": flags.duplicate(),
		"event": event.duplicate(true), "fights_since_event": fights_since_event,
		"reroll_count": reroll_count, "enemy_options": enemy_options.duplicate(true),
		"chosen_enemy": chosen_enemy.duplicate(true), "rewards": rewards.duplicate(),
		"next_uid": next_uid, "battles_won": battles_won, "last_income": last_income.duplicate(),
	}


static func from_dict(content: ContentDb, data: Dictionary) -> RunState:
	var run := RunState.new()
	run.db = content
	run.rng = RngStreams.from_dict(data["rng"])
	run.stage = int(data["stage"]) as Stage
	run.region = data.get("region", "coins")
	run.act = int(data["act"])
	run.fight = int(data["fight"])
	run.gold = int(data["gold"])
	run.packs = data.get("packs", []).duplicate(true)
	run.open_pack = data.get("open_pack", {}).duplicate(true)
	run.relics = data.get("relics", []).duplicate()
	run.tarots = data.get("tarots", []).duplicate()
	run.pacts = data.get("pacts", []).duplicate()
	run.souls = int(data.get("souls", 0))
	run.next_shop = data.get("next_shop", []).duplicate()
	run.flags = data.get("flags", {}).duplicate()
	run.event = data.get("event", {}).duplicate(true)
	run.fights_since_event = int(data.get("fights_since_event", 0))
	run.row = data["row"].duplicate(true)
	run.shop = data["shop"].duplicate()
	run.reroll_count = int(data["reroll_count"])
	run.enemy_options = data["enemy_options"].duplicate(true)
	run.chosen_enemy = data["chosen_enemy"].duplicate(true)
	run.rewards = data["rewards"].duplicate()
	run.next_uid = int(data["next_uid"])
	run.battles_won = int(data["battles_won"])
	run.last_income = data["last_income"].duplicate()
	return run
