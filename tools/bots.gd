class_name BalanceBot
extends RefCounted
## A bot that plays whole runs like a player would: it picks enemies, buys and
## sells figures, rerolls, opens packs, equips items, uses tarot cards, takes
## fusions, plays events and rearranges its row. Strategies differ by a few
## knobs (see STRATEGIES) so their results show where the game is too easy,
## too hard or where one approach dominates.

const STRATEGIES := {
	"Verschwender": {"save": 0, "rerolls": 6, "packs": 1.0, "enemy": "medium", "sell": true, "arrange": false,
		"suit": false, "fuse": true, "events": "greedy", "desc": "gibt alles aus, würfelt oft neu, kauft jedes Pack"},
	"Sparer": {"save": 20, "rerolls": 1, "packs": 0.3, "enemy": "adaptive", "sell": true, "arrange": false,
		"suit": false, "fuse": true, "events": "cheap", "desc": "hält Gold für volle Zinsen, kauft nur das Nötigste"},
	"Leveler": {"save": 5, "rerolls": 3, "packs": 0.5, "enemy": "medium", "sell": true, "arrange": false,
		"suit": false, "fuse": false, "events": "greedy", "merge_bias": 3.0, "desc": "kauft Duplikate und levelt wenige starke Figuren"},
	"Farbspezialist": {"save": 10, "rerolls": 3, "packs": 0.6, "enemy": "adaptive", "sell": true, "arrange": true,
		"suit": true, "fuse": true, "events": "greedy", "desc": "baut eine Tarot-Farbe aus und nutzt ihre Synergien"},
	"Fusionist": {"save": 10, "rerolls": 2, "packs": 0.8, "enemy": "medium", "sell": false, "arrange": true,
		"suit": false, "fuse": true, "events": "fusion", "desc": "sucht Fusionen (Altar, Kerzen, Blutmond)"},
	"Taktiker": {"save": 10, "rerolls": 3, "packs": 0.7, "enemy": "adaptive", "sell": true, "arrange": true,
		"suit": false, "fuse": true, "events": "greedy", "desc": "ausgewogen, wählt Gegner nach eigener Stärke, stellt um"},
	"Stratege": {"save": 8, "rerolls": 3, "packs": 0.7, "enemy": "hard", "sell": true, "arrange": true,
		"suit": false, "fuse": true, "events": "greedy", "plan": true,
		"desc": "nimmt meist die schwere Bande, plant Käufe und Aufstellung gezielt gegen das Gegnerteam"},
}
## The strategist takes the hard band this often (otherwise the hardest it can beat).
const HARD_PICK_CHANCE := 0.8
## Rows up to this size try every order; longer rows improve by swapping pairs.
const FULL_PERMUTATION_SIZE := 4
const RANK_VALUE := {"page": 1.0, "knight": 1.5, "queen": 2.0, "king": 2.6, "legend": 3.2}

var name := ""
var knobs: Dictionary = {}
var run: RunState
var rng := RandomNumberGenerator.new()
var main_suit := ""
var log: Dictionary = {"fusions": 0, "rerolls": 0, "sold": 0, "packs": 0, "tarots": 0, "events": [], "battles": []}


static func create(strategy: String, seed_value: int) -> BalanceBot:
	var bot := BalanceBot.new()
	bot.name = strategy
	bot.knobs = STRATEGIES[strategy]
	bot.rng.seed = seed_value * 7919 + strategy.hash()
	return bot


## Plays the run to its end. Returns the finished RunState.
func play(db: ContentDb, seed_value: int, options: Dictionary = {}) -> RunState:
	run = RunState.new_run(db, seed_value, options)
	var guard := 0
	while run.stage != RunState.Stage.WON and run.stage != RunState.Stage.LOST and guard < 400:
		guard += 1
		if not run.fusion_offer.is_empty():
			_handle_fusion()
			continue
		if not run.treasure.is_empty():
			_handle_treasure()
			continue
		if not run.open_pack.is_empty():
			_handle_pack()
			continue
		match run.stage:
			RunState.Stage.ENEMY_CHOICE:
				run.choose_enemy(_pick_enemy())
			RunState.Stage.PLANNING:
				_plan()
				var station := "A%d K%d" % [run.act, run.fight + 1]
				var mine := _team_power()
				var theirs := EnemyGenerator.power(run.db, run.chosen_enemy.get("team", []))
				var result := BattleSimulator.simulate(run.player_battle_team(), run.enemy_battle_team(), run.gold, run.battle_options())
				log["battles"].append({"station": station, "mine": mine, "theirs": theirs, "won": bool(result["victory"]),
					"difficulty": int(run.chosen_enemy.get("difficulty", 0)), "filled": _filled()})
				run.apply_battle_result(result)
			RunState.Stage.REWARD:
				_reward()
			RunState.Stage.EVENT:
				_event()
	return run


# --- Evaluation ----------------------------------------------------------------------

func _figure_value(def_id: String, level: int = 1) -> float:
	var d: Dictionary = run.db.figures[def_id]
	var value := float(int(d["attack"]) + level - 1) * float(int(d["health"]) + level - 1)
	value *= RANK_VALUE.get(d["rank"], 1.0) * 0.5 + 0.5
	if knobs.get("suit", false) and main_suit != "" and d["suit"] == main_suit:
		value *= 1.8
	return value


func _row_value(figure: Dictionary) -> float:
	if figure.has("fusion"):
		return float(figure["fusion"]["attack"]) * float(figure["fusion"]["health"]) * 1.6
	return _figure_value(figure["def_id"], run.figure_level(figure)) * (1.2 if figure.has("equipment") else 1.0)


func _team_power() -> float:
	var total := 0.0
	for entry in run.player_battle_team():
		var unit := BattleSimulator.preview_unit(entry, BattleSimulator.PLAYER)
		total += unit.effective_attack() * unit.max_health
	return total


## Gold the bot may spend: everything while the row still has free slots
## (a player fills the team first), afterwards it keeps its savings.
func _spendable() -> int:
	if _filled() < run.slot_count():
		return run.gold
	return maxi(run.gold - int(knobs["save"]), 0)


# --- Enemy choice ----------------------------------------------------------------------

func _pick_enemy() -> int:
	var count := run.enemy_options.size()
	if count <= 1:
		return 0
	match knobs["enemy"]:
		"easy":
			return 0
		"medium":
			return mini(1, count - 1)
		"hard":
			if rng.randf() < HARD_PICK_CHANCE:
				return count - 1
	# Adaptive: the hardest option the team beats in a test battle with its
	# best arrangement against exactly that band.
	var pick := 0
	var saved := run.row.duplicate()
	for i in count:
		var enemy := _enemy_team(run.enemy_options[i])
		var score := _best_arrangement(enemy)
		run.row = saved.duplicate()
		if score >= WIN_SCORE:
			pick = i
	return pick


# --- Planning (shop, tarot, arrangement) -------------------------------------------------

func _plan() -> void:
	if main_suit == "":
		main_suit = run.figure_suit(run.row[0]) if run.row[0] != null else "coins"
	_use_tarots()
	if "ritual_candle" in run.tarots and knobs["fuse"] and _filled() >= 2:
		run.start_candle_fusion()
		if not run.fusion_offer.is_empty():
			_handle_fusion()
	# Pacts for souls (all bots that can afford them, except the cautious saver).
	if knobs["save"] < 25 and run.souls >= run.soul_pack_price() and run.pacts.size() < RunState.MAX_PACTS:
		if run.buy_soul_pack():
			_handle_pack()
	var rerolls := 0
	for pass_i in 16:
		var acted := _buy_best_figure()
		if not acted:
			acted = _buy_pack()
		# Reroll when nothing worth buying is left and the budget allows it.
		if not acted and rerolls < int(knobs["rerolls"]) and _spendable() >= run.reroll_price() + _cheapest_need():
			if run.reroll():
				rerolls += 1
				log["rerolls"] += 1
				acted = true
		if not acted:
			break
		_use_tarots()
	if knobs.get("plan", false):
		_plan_purchases()
	# Every bot looks at the enemy band and puts its figures in the order
	# that beats it best (test battles); bots without "arrange" only do so
	# when their simple order would lose.
	var enemy := run.enemy_battle_team()
	if knobs["arrange"]:
		_arrange()
		_best_arrangement(enemy)
	elif _sim_score(enemy) < WIN_SCORE:
		_best_arrangement(enemy)


## Gold to keep after a reroll so something can still be bought (a page costs 3).
func _cheapest_need() -> int:
	return 3 if _filled() < run.slot_count() else 4


func _filled() -> int:
	return run.row.filter(func(f: Variant) -> bool: return f != null).size()


## Buys the most valuable affordable figure: merges first, then free slots,
## then (selling bots) replaces the weakest figure.
func _buy_best_figure() -> bool:
	var best := -1
	var best_score := 0.0
	var best_target := -1
	for i in run.shop.size():
		var id: String = run.shop[i]
		if id == "" or run.price_of(id) > _spendable():
			continue
		var target := run.reward_target(id)
		var score := _figure_value(id)
		if target >= 0 and run.row[target] != null:
			score *= float(knobs.get("merge_bias", 1.6))  # merging levels up
		elif target >= 0:
			# A free slot: more figures matter a lot while the row is not full.
			var empty := run.row.size() - _filled()
			score *= 1.0 + 1.2 * empty
		if target < 0:
			if not knobs["sell"]:
				continue
			var weakest := _weakest()
			if weakest < 0 or _row_value(run.row[weakest]) * 1.4 > score:
				continue
			target = weakest
		if score > best_score:
			best = i
			best_score = score
			best_target = target
	if best < 0:
		return false
	if run.row[best_target] != null and run.reward_target(run.shop[best]) != best_target:
		if not run.sell(best_target):
			return false
		log["sold"] += 1
	return run.buy(best, best_target)


func _weakest() -> int:
	var weakest := -1
	var value := INF
	for i in run.row.size():
		var figure = run.row[i]
		if figure == null or figure.has("fusion"):
			continue
		var v := _row_value(figure)
		if v < value:
			value = v
			weakest = i
	return weakest


func _buy_pack() -> bool:
	var has_free := run.packs.any(func(p: Dictionary) -> bool: return p.get("free", false))
	if not has_free and rng.randf() > float(knobs["packs"]):
		return false
	var best := -1
	var best_score := 0.0
	for i in run.packs.size():
		var pack: Dictionary = run.packs[i]
		if pack.is_empty() or run.pack_cost(pack) > _spendable():
			continue
		var score := 1.0
		match pack["type"]:
			"equipment":
				score = 2.5 if _strongest_with_room() >= 0 else 0.0
			"relic":
				score = 3.0 if run.relics.size() < RunState.MAX_RELICS else 0.0
			"arcana":
				score = 2.0 if run.tarots.size() < RunState.MAX_TAROTS else 0.4
		if pack.get("free", false):
			score += 5.0
		if score > best_score:
			best_score = score
			best = i
	if best < 0 or not run.buy_pack(best):
		return false
	log["packs"] += 1
	_handle_pack()
	return true


func _use_tarots() -> void:
	for guard in 4:
		if run.tarots.is_empty():
			return
		var used := false
		for t in run.tarots.size():
			var card: String = run.tarots[t]
			var target := _strongest()
			if card == "hanged_man":
				target = _weakest()
				if target < 0 or _filled() < 3:
					continue
			if card == "ritual_candle" or target < 0:
				continue
			if run.use_tarot(t, target):
				log["tarots"] += 1
				used = true
				break
		if not used:
			return


func _strongest() -> int:
	var best := -1
	var value := -1.0
	for i in run.row.size():
		if run.row[i] != null and _row_value(run.row[i]) > value:
			value = _row_value(run.row[i])
			best = i
	return best


## Tactical order: the toughest figure in front (index 0), ranged figures and
## those that heal or buff from behind at the back.
func _arrange() -> void:
	# Selection sort by swapping: the best front figure into slot 0, and so on.
	for slot in run.row.size():
		var best := -1
		var value := -1.0
		for j in range(slot, run.row.size()):
			if run.row[j] != null and _front_score(run.row[j]) > value:
				value = _front_score(run.row[j])
				best = j
		if best < 0:
			return
		if best != slot:
			if run.row[slot] != null and run.row[slot]["def_id"] == run.row[best]["def_id"]:
				continue  # moving onto an equal figure would merge them
			run.move(best, slot)


# --- Test battles against the enemy band ---------------------------------------------

## Scores of a test battle: a win is worth WIN_SCORE plus the health left.
const WIN_SCORE := 1000.0


func _enemy_team(option: Dictionary) -> Array:
	return option.get("team", []).map(func(u: Dictionary) -> Dictionary:
		return {"def": run.db.enemies[u["def_id"]], "level": u["level"]})


## Fights the band once in the simulator with the current row.
func _sim_score(enemy: Array) -> float:
	var team := run.player_battle_team()
	if team.is_empty():
		return -INF
	var result := BattleSimulator.simulate(team, enemy, run.gold, run.battle_options())
	var health := {}
	var sides := {}
	for e in result["events"]:
		match e["type"]:
			"start":
				for u in e["player"] + e["enemy"]:
					health[u["uid"]] = int(u["health"])
					sides[u["uid"]] = int(u["side"])
			"update":
				health[e["unit"]["uid"]] = int(e["unit"]["health"])
				sides[e["unit"]["uid"]] = int(e["unit"]["side"])
			"removed":
				health[e["uid"]] = 0
	var mine := 0
	var theirs := 0
	for uid in health:
		if sides[uid] == BattleSimulator.PLAYER:
			mine += maxi(health[uid], 0)
		else:
			theirs += maxi(health[uid], 0)
	return (WIN_SCORE + mine if result["victory"] else 0.0) - theirs


## Puts the row into the order that does best against the band (all orders
## for small rows, pair swaps for longer ones) and returns its score.
func _best_arrangement(enemy: Array) -> float:
	var figures: Array = run.row.filter(func(f: Variant) -> bool: return f != null)
	var empty := run.row.size() - figures.size()
	var best_order: Array = figures.duplicate()
	run.row = _with_empty(best_order, empty)
	var best := _sim_score(enemy)
	if figures.size() <= 1:
		return best
	if figures.size() <= FULL_PERMUTATION_SIZE:
		for order in _permutations(figures):
			run.row = _with_empty(order, empty)
			var score := _sim_score(enemy)
			if score > best:
				best = score
				best_order = order
	else:
		var improved := true
		var rounds := 0
		while improved and rounds < 3:
			improved = false
			rounds += 1
			for a in figures.size():
				for b in range(a + 1, figures.size()):
					var order: Array = best_order.duplicate()
					var tmp: Variant = order[a]
					order[a] = order[b]
					order[b] = tmp
					run.row = _with_empty(order, empty)
					var score := _sim_score(enemy)
					if score > best:
						best = score
						best_order = order
						improved = true
	run.row = _with_empty(best_order, empty)
	return best


func _with_empty(order: Array, empty: int) -> Array:
	var row: Array = order.duplicate()
	for i in empty:
		row.append(null)
	return row


func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var result: Array = []
	for i in items.size():
		var rest: Array = items.duplicate()
		var head: Variant = rest.pop_at(i)
		for tail in _permutations(rest):
			result.append([head] + tail)
	return result


## The strategist tries each affordable shop figure on a copy of the run:
## buys the one that beats the coming band best (with an eye on its value
## for later fights), as long as it improves on not buying.
func _plan_purchases() -> void:
	var enemy := run.enemy_battle_team()
	for pass_i in 4:
		var current := _best_arrangement(enemy)
		var best_index := -1
		var best_total := current + 1.0
		for i in run.shop.size():
			var id: String = run.shop[i]
			if id == "" or run.price_of(id) > _spendable():
				continue
			var trial := RunState.from_dict(run.db, run.to_dict())
			var target := trial.reward_target(id)
			if target < 0:
				var weakest := _weakest_in(trial)
				if weakest < 0 or not trial.sell(weakest):
					continue
				target = trial.reward_target(id)
			if target < 0 or not trial.buy(i, target):
				continue
			var keep := run
			run = trial
			var total := _best_arrangement(enemy) + _figure_value(id) * 2.0
			run = keep
			if total > best_total:
				best_total = total
				best_index = i
		if best_index < 0:
			return
		var id: String = run.shop[best_index]
		var place := run.reward_target(id)
		if place < 0:
			var weakest := _weakest()
			if weakest < 0 or not run.sell(weakest):
				return
			log["sold"] += 1
			place = run.reward_target(id)
		if place < 0 or not run.buy(best_index, place):
			return


func _weakest_in(other: RunState) -> int:
	var keep := run
	run = other
	var index := _weakest()
	run = keep
	return index


func _front_score(figure: Dictionary) -> float:
	var def_id: String = figure["def_id"]
	var d: Dictionary = run.db.figures[def_id]
	var health := float(d["health"]) + run.figure_level(figure)
	if figure.has("fusion"):
		health = float(figure["fusion"]["health"])
	if FigureArt.is_ranged(def_id):
		health *= 0.4
	return health


# --- Packs, rewards, events, fusions ----------------------------------------------------

func _handle_pack() -> void:
	for guard in 8:
		if run.open_pack.is_empty():
			return
		var items: Array = run.open_pack["items"]
		var best := -1
		var best_target := -1
		var best_score := -1.0
		for i in items.size():
			var entry: Dictionary = items[i]
			if entry.get("taken", false):
				continue
			var score := 1.0
			var target := -1
			match entry["kind"]:
				"equipment":
					target = _strongest_with_room()
					score = 3.0 + int(entry["item"]["rarity"])
				"figure":
					target = run.reward_target(entry["def_id"])
					score = _figure_value(entry["def_id"]) * 0.1
				"relic":
					score = 4.0
				"pact":
					score = 2.5
				"tarot":
					score = 2.0
			if run.can_take_pack_item(i, target) and score > best_score:
				best = i
				best_score = score
				best_target = target
		if best < 0:
			run.close_pack()
			return
		run.take_pack_item(best, best_target)


## Boss treasury: savers take gold, a free slot or a weak figure calls for an
## ace, otherwise a relic.
func _handle_treasure() -> void:
	var kinds: Array = run.treasure.map(func(t: Dictionary) -> String: return t["kind"])
	var pick := -1
	if int(knobs["save"]) >= 20:
		pick = kinds.find("gold")
	elif kinds.has("legend_pack") and (_filled() < run.slot_count() or knobs["sell"]):
		pick = kinds.find("legend_pack")
	elif kinds.has("relic"):
		pick = kinds.find("relic")
	if pick < 0:
		pick = kinds.find("gold")
	log["treasure"] = log.get("treasure", []) + [kinds[maxi(pick, 0)]]
	run.take_treasure(maxi(pick, 0))
	# Make room for the ace by selling the weakest figure if the row is full.
	if not run.open_pack.is_empty() and _filled() >= run.slot_count() and knobs["sell"]:
		var weakest := _weakest()
		if weakest >= 0:
			run.sell(weakest)
	_handle_pack()


func _strongest_with_room() -> int:
	var best := -1
	var value := -1.0
	for i in run.row.size():
		var figure = run.row[i]
		if figure != null and run.can_add_object(figure, "equipment") and _row_value(figure) > value:
			value = _row_value(figure)
			best = i
	return best


func _reward() -> void:
	var best := -1
	var value := -1.0
	for i in run.rewards.size():
		var id: String = run.rewards[i]
		if run.reward_target(id) < 0:
			continue
		if _figure_value(id) > value:
			value = _figure_value(id)
			best = i
	if best < 0 or not run.take_reward(best):
		run.skip_reward()


func _event() -> void:
	var id := String(run.event.get("id", ""))
	if not log["events"].has(id):
		log["events"].append(id)
	var style: String = knobs["events"]
	var tries: Array = []
	match id:
		"cursed_well":
			tries = [["throw_10"], ["throw_6"], ["throw_3"]] if style == "greedy" else [["throw_3"]]
		"black_market":
			tries = [["buy_relic"], ["buy_candle"] if style == "fusion" else ["buy_pack"]]
		"altar":
			tries = [["sacrifice_one", [_weakest()]]] if _filled() >= 4 else []
		"fusion_altar":
			tries = [["fuse"]] if knobs["fuse"] else []
		"blood_moon":
			tries = [["blood_fuse"]] if knobs["fuse"] else []
		"soul_trader":
			tries = [["soul_to_gold"]] if style != "fusion" else []
		"mirror":
			tries = [["duplicate", [_strongest()]]]
		"fortune_teller", "grave_robber", "duel":
			tries = []
	for attempt in tries:
		var option: String = attempt[0]
		var targets: Array = attempt[1] if attempt.size() > 1 else []
		if targets.has(-1):
			continue
		if run.event_option_block(option, targets) == "":
			run.resolve_event(option, targets)
			if not run.open_pack.is_empty():
				_handle_pack()
			if not run.fusion_offer.is_empty():
				_handle_fusion()
			if run.stage != RunState.Stage.EVENT:
				return
	if run.stage == RunState.Stage.EVENT:
		run.resolve_event("leave")


## Fuses the two strongest compatible figures (keeping the best abilities), or declines.
func _handle_fusion() -> void:
	if not knobs["fuse"]:
		run.decline_fusion()
		return
	var best_pair := []
	var best_value := -1.0
	for a in run.row.size():
		for b in run.row.size():
			if a == b or run.row[a] == null or run.row[b] == null:
				continue
			if run.fusion_block(a, b) != "":
				continue
			var value := _row_value(run.row[a]) + _row_value(run.row[b])
			if value > best_value:
				best_value = value
				best_pair = [a, b]
	if best_pair.is_empty():
		run.decline_fusion()
		return
	var preview := Fusion.preview(run, best_pair[0], best_pair[1])
	var keep: Array = preview.get("candidates", []).slice(0, int(preview.get("keep", 2)))
	if run.fuse(best_pair[0], best_pair[1], keep):
		log["fusions"] += 1
	else:
		run.decline_fusion()
