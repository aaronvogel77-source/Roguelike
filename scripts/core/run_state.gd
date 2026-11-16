class_name RunState
extends RefCounted
## The complete state of one run plus every player action on it.
## Pure logic: no UI, fully serializable (save games in M7, undo in M3).
##
## Cycle: ENEMY_CHOICE → PLANNING (shop) → battle → REWARD → ENEMY_CHOICE ...
## A lost battle ends the run (LOST); beating the last boss wins it (WON).

enum Stage { ENEMY_CHOICE, PLANNING, REWARD, WON, LOST }

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
	return 1 + reroll_count


## Tarot suit of a figure (the Wheel of Fortune can change it).
func figure_suit(figure: Dictionary) -> String:
	return figure.get("suit", db.figures[figure["def_id"]]["suit"])


func price_of(def_id: String) -> int:
	return RANK_PRICES[db.figures[def_id]["rank"]]


## Half the rank price (rounded down) plus 1 per level above 1.
func sell_value(figure: Dictionary) -> int:
	return price_of(figure["def_id"]) / 2 + figure_level(figure) - 1


func interest() -> int:
	return mini(gold / GOLD_PER_INTEREST, MAX_INTEREST)


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
	chosen_enemy = enemy_options[index]
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
	if stage not in [Stage.PLANNING, Stage.REWARD] or row_index < 0 or row_index >= row.size() or row[row_index] == null:
		return false
	gold += sell_value(row[row_index])
	row[row_index] = null
	return true


## Moves a figure. Onto an equal figure below max level it merges (the moved
## copy's experience plus one duplicate); onto another figure the two swap.
func move(from_index: int, to_index: int) -> bool:
	if stage != Stage.PLANNING or from_index == to_index:
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
	if stage != Stage.PLANNING or from_index < 0 or from_index >= row.size() or row[from_index] == null:
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


func reroll() -> bool:
	if stage != Stage.PLANNING or gold < reroll_price():
		return false
	gold -= reroll_price()
	reroll_count += 1
	_roll_shop()
	return true


# --- Packs, relics, tarot ----------------------------------------------------------

## Buys and opens a pack. Its contents wait in open_pack until picked.
## force_legend: debug tool for testing legendary figures.
func buy_pack(index: int, force_legend: bool = false) -> bool:
	if stage != Stage.PLANNING or not open_pack.is_empty() or index < 0 or index >= packs.size():
		return false
	var pack: Dictionary = packs[index]
	if pack.is_empty() or gold < Items.pack_price(db, pack):
		return false
	gold -= Items.pack_price(db, pack)
	packs[index] = {}
	_open(pack, force_legend)
	return true


## Debug: opens a free mega court pack whose first card is legendary.
func debug_legend_pack() -> void:
	_open({"type": "court", "size": "mega"}, true)


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
			return target_index >= 0 and target_index < row.size() and row[target_index] != null
		"tarot":
			return tarots.size() < MAX_TAROTS
		"relic":
			return relics.size() < MAX_RELICS
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
	match tarots[tarot_index]:
		"strength":
			figure["bonus_attack"] = int(figure.get("bonus_attack", 0)) + 2
			figure["bonus_health"] = int(figure.get("bonus_health", 0)) + 2
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
	return options


## Applies a finished battle. Returns the new stage.
func apply_battle_result(result: Dictionary) -> Stage:
	gold = int(result.get("gold_after", gold))
	if not result["victory"]:
		stage = Stage.LOST
		return stage
	battles_won += 1
	for figure in row:
		if figure != null:
			figure["xp"] = mini(int(figure["xp"]) + XP_PER_WIN, XP_FOR_LEVEL[2])
	var paid_interest := interest()
	var bonus := int(chosen_enemy.get("bonus", 0))
	var extra := TeamBuilder.gold_after_win(self)
	gold = maxi(gold + BASE_INCOME + bonus + paid_interest + extra, 0)
	last_income = {"base": BASE_INCOME, "bonus": bonus, "interest": paid_interest, "extra": extra}
	if is_boss_fight() and slot_count() < MAX_SLOTS:
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
	stage = Stage.ENEMY_CHOICE
	_roll_enemy_options()
	# A boss is not chosen: the run goes straight to its shop.
	# (M5 brings boss skipping, which will need the choice screen again.)
	if is_boss_fight() and enemy_options.size() == 1:
		choose_enemy(0)


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
	chosen_enemy = {}


func _roll_shop() -> void:
	shop.clear()
	for i in SHOP_FIGURE_SLOTS:
		shop.append(_random_figure_id(rng.stream("shop")))
	packs.clear()
	for i in SHOP_PACK_SLOTS:
		packs.append(Items.roll_pack(db, rng.stream("packs")))


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
