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
const START_GOLD := 10
const START_SLOTS := 3
const MAX_SLOTS := 6
const FIGURE_PRICE := 3
const SHOP_FIGURE_SLOTS := 3
const BASE_INCOME := 5
const GOLD_PER_INTEREST := 5
const MAX_INTEREST := 5
const SLOT_PRICES := [6, 8, 10]
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
var act := 1
var fight := 0  # 0 = small, 1 = big, 2 = boss
var gold := START_GOLD
var slots_bought := 0
## Battle row, front first. Each entry is null or {"uid", "def_id", "xp"}.
var row: Array = []
## Shop offers: figure ids, "" for a bought slot.
var shop: Array = []
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


func slot_price() -> int:
	if slot_count() >= MAX_SLOTS or slots_bought >= SLOT_PRICES.size():
		return -1
	return SLOT_PRICES[slots_bought]


func sell_value(figure: Dictionary) -> int:
	return 1 + figure_level(figure) - 1


func interest() -> int:
	return mini(gold / GOLD_PER_INTEREST, MAX_INTEREST)


func is_boss_fight() -> bool:
	return fight == 2


func can_place(def_id: String, row_index: int) -> bool:
	if row_index < 0 or row_index >= row.size():
		return false
	var target: Variant = row[row_index]
	return target == null or target["def_id"] == def_id


## Battle entries ({"def", "level"}) for the simulator, front first.
func player_battle_team() -> Array:
	var team: Array = []
	for figure in row:
		if figure != null:
			team.append({"def": db.figures[figure["def_id"]], "level": figure_level(figure)})
	return team


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
	if def_id == "" or gold < FIGURE_PRICE or not can_place(def_id, row_index):
		return false
	gold -= FIGURE_PRICE
	shop[shop_index] = ""
	_place(def_id, row_index)
	return true


func sell(row_index: int) -> bool:
	if stage != Stage.PLANNING or row_index < 0 or row_index >= row.size() or row[row_index] == null:
		return false
	gold += sell_value(row[row_index])
	row[row_index] = null
	return true


## Moves a figure; if the target holds a figure, the two swap places.
func move(from_index: int, to_index: int) -> bool:
	if stage != Stage.PLANNING or from_index == to_index:
		return false
	if from_index < 0 or to_index < 0 or from_index >= row.size() or to_index >= row.size():
		return false
	if row[from_index] == null:
		return false
	var moving: Variant = row[from_index]
	row[from_index] = row[to_index]
	row[to_index] = moving
	return true


func reroll() -> bool:
	if stage != Stage.PLANNING or gold < reroll_price():
		return false
	gold -= reroll_price()
	reroll_count += 1
	_roll_shop()
	return true


func buy_slot() -> bool:
	var price := slot_price()
	if stage != Stage.PLANNING or price < 0 or gold < price:
		return false
	gold -= price
	slots_bought += 1
	row.append(null)
	return true


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
	gold += BASE_INCOME + bonus + paid_interest
	last_income = {"base": BASE_INCOME, "bonus": bonus, "interest": paid_interest}
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
		if row[i] != null and row[i]["def_id"] == def_id:
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
	enemy_options = EnemyGenerator.options(db, act, fight, rng.stream("enemy_gen"))
	chosen_enemy = {}


func _roll_shop() -> void:
	shop.clear()
	for i in SHOP_FIGURE_SLOTS:
		shop.append(_random_figure_id(rng.stream("shop")))


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
	for figure in db.figures.values():
		if figure["rank"] == rank:
			ids.append(figure["id"])
	ids.sort()
	return ids


# --- Serialization (undo now, save games in M7) -------------------------------------

func to_dict() -> Dictionary:
	return {
		"rng": rng.to_dict(), "stage": stage, "act": act, "fight": fight, "gold": gold,
		"slots_bought": slots_bought, "row": row.duplicate(true), "shop": shop.duplicate(),
		"reroll_count": reroll_count, "enemy_options": enemy_options.duplicate(true),
		"chosen_enemy": chosen_enemy.duplicate(true), "rewards": rewards.duplicate(),
		"next_uid": next_uid, "battles_won": battles_won, "last_income": last_income.duplicate(),
	}


static func from_dict(content: ContentDb, data: Dictionary) -> RunState:
	var run := RunState.new()
	run.db = content
	run.rng = RngStreams.from_dict(data["rng"])
	run.stage = int(data["stage"]) as Stage
	run.act = int(data["act"])
	run.fight = int(data["fight"])
	run.gold = int(data["gold"])
	run.slots_bought = int(data["slots_bought"])
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
