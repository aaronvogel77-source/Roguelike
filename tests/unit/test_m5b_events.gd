extends GutTest
## M5b: the eight events.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


func _event_run(id: String) -> RunState:
	var run := RunState.new_run(_db, 4)
	run.row = [_fig("the_judge", 9), _fig("coin_squire"), null]
	run.gold = 20
	run.start_event(id)
	return run


func test_at_most_one_event_per_act() -> void:
	var events_per_act := {}
	for seed_value in 30:
		var run := RunState.new_run(_db, seed_value)
		var guard := 0
		while run.stage not in [RunState.Stage.WON, RunState.Stage.LOST] and guard < 40:
			guard += 1
			if run.stage == RunState.Stage.ENEMY_CHOICE:
				run.choose_enemy(0)
			elif run.stage == RunState.Stage.PLANNING:
				run.apply_battle_result({"victory": true})
			elif run.stage == RunState.Stage.REWARD:
				run.skip_reward()
			elif run.stage == RunState.Stage.EVENT:
				if run.is_negative_event():
					# Dangers come on top of the normal events: pay / endure, then move on.
					for option in ["pay_tax", "plague_accept", "flee", "fog_accept"]:
						if run.event_option_block(option) == "":
							run.resolve_event(option)
							break
					run.resolve_event("leave")
					continue
				var key := "%d-%d" % [seed_value, run.act]
				events_per_act[key] = int(events_per_act.get(key, 0)) + 1
				run.resolve_event("leave")
	assert_false(events_per_act.is_empty(), "events still happen")
	for key in events_per_act:
		assert_eq(events_per_act[key], 1, "never two events in one act")


func test_altar_sacrifice_gives_souls() -> void:
	var run := _event_run("altar")
	assert_true(run.resolve_event("sacrifice_one", [0]))
	assert_eq(run.souls, 4 + 2, "king level 2")
	assert_null(run.row[0])


func test_altar_double_sacrifice_opens_a_pact_choice() -> void:
	var run := _event_run("altar")
	assert_true(run.resolve_event("sacrifice_two", [0, 1]))
	assert_eq(run.open_pack["items"].size(), 3)
	assert_eq(run.open_pack["items"][0]["kind"], "pact")


func test_black_market_offers_can_each_be_bought_once() -> void:
	var run := _event_run("black_market")
	assert_true(run.resolve_event("buy_relic"))
	assert_false(run.resolve_event("buy_relic"), "only once")
	assert_eq(run.relics.size(), 1)
	assert_true(run.resolve_event("buy_figure", [2]))
	assert_true(run.resolve_event("leave"))
	assert_eq(run.stage, RunState.Stage.ENEMY_CHOICE)


func test_cursed_well_and_drinking() -> void:
	var run := _event_run("cursed_well")
	assert_true(run.resolve_event("throw_10"))
	# 10 gold: pick one of three rare items, each with exactly 2 affixes.
	assert_eq(run.open_pack["items"].size(), 3)
	for entry in run.open_pack["items"]:
		assert_eq(entry["item"]["rarity"], Items.RARITY_RARE)
		assert_eq(entry["item"]["affixes"].size(), 2)
	var run2 := _event_run("cursed_well")
	assert_true(run2.resolve_event("drink", [1]))
	assert_true(run2.row[1]["cursed"])
	var abilities: Array = run2.player_battle_team()[1]["abilities"]
	assert_true(abilities.any(func(a: Dictionary) -> bool: return a["effect"] == "apply_curse"))


func test_fortune_teller_cancels_the_next_boss_rule() -> void:
	var run := _event_run("fortune_teller")
	run.resolve_event("no_boss_rule")
	run.resolve_event("leave")
	while not run.is_boss_fight():
		if run.stage == RunState.Stage.ENEMY_CHOICE:
			run.skip_fight()
	assert_eq(run.boss_rule(), "")


func test_grave_robber_takes_the_rearmost_figure() -> void:
	var run := _event_run("grave_robber")
	run.resolve_event("rob")
	assert_eq(run.gold, 28)
	assert_null(run.row[1])
	assert_not_null(run.row[0])


func test_mirror_duplicates_for_two_souls() -> void:
	var run := _event_run("mirror")
	run.souls = 2
	assert_true(run.resolve_event("duplicate", [0]))
	assert_eq(run.row[2]["def_id"], "the_judge")
	assert_eq(run.row[2]["xp"], 0)


func test_duel_win_and_loss() -> void:
	var run := _event_run("duel")
	assert_gt(run.duel_team().size(), 0)
	run.apply_duel_result({"victory": true})
	assert_eq(run.souls, 2)
	var run2 := _event_run("duel")
	run2.apply_duel_result({"victory": false})
	assert_null(run2.row[0], "the front figure is lost")
	assert_ne(run2.stage, RunState.Stage.LOST, "not the end of the run")


func test_soul_trader_exchanges_repeatedly() -> void:
	var run := _event_run("soul_trader")
	assert_true(run.resolve_event("gold_to_soul"))
	assert_true(run.resolve_event("gold_to_soul"))
	assert_eq(run.souls, 2)
	assert_eq(run.gold, 10)
	assert_true(run.resolve_event("soul_to_gold"))
	assert_eq(run.gold, 15)


## Every rolled item follows its rarity: affix count, no repeats, nothing
## that duplicates the base effect, drawbacks only on cursed items.
func test_equipment_follows_rarity_rules() -> void:
	var db := _db
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 600:
		var item := Items.roll_equipment(db, 3, rng, 0, i % 5 if i < 400 else -1)
		var rarity: int = item["rarity"]
		assert_eq(item["affixes"].size(), Items.AFFIX_COUNT[rarity])
		var ids: Array = item["affixes"].map(func(a: Dictionary) -> String: return a["id"])
		for id in ids:
			assert_eq(ids.count(id), 1, "no repeated affix")
			var affix: Dictionary = Items._find(db.items["affixes"], id)
			assert_true(rarity >= int(affix.get("min_rarity", 0)))
			var base: Dictionary = Items._find(db.items["equipment"], item["base"])["base"]
			assert_false(Items._same_effect(affix, base), "affix repeats base")
		assert_eq(not item["drawback"].is_empty(), rarity == Items.RARITY_CURSED)
		assert_eq(item.has("unique"), rarity == Items.RARITY_UNIQUE)
		if i >= 400:
			assert_ne(rarity, Items.RARITY_UNIQUE, "unique only from the well")


func test_well_can_give_one_unique_item() -> void:
	var run := _event_run("cursed_well")
	run.flags["force_unique"] = true
	assert_true(run.resolve_event("throw_10"))
	var uniques: Array = run.open_pack["items"].filter(func(e: Dictionary) -> bool:
		return e["item"]["rarity"] == Items.RARITY_UNIQUE)
	assert_eq(uniques.size(), 1)
	assert_true(uniques[0]["item"].has("unique"))
	assert_eq(uniques[0]["item"]["affixes"].size(), 2)


func _with_unique(def_id: String, unique: String) -> Dictionary:
	var item := {"base": "amulet", "rarity": Items.RARITY_UNIQUE, "affixes": [], "drawback": {}, "unique": unique}
	var mods := Items.equipment_modifiers(_db, item)
	return {"def": _db.figures[def_id], "level": 1, "bonus_attack": mods["attack"], "bonus_health": mods["health"],
		"multipliers": mods["multipliers"], "abilities": mods["abilities"]}


func test_unique_effects_work_in_battle() -> void:
	var warlord := Items.equipment_modifiers(_db, {"base": "blade", "rarity": 4, "affixes": [], "drawback": {}, "unique": "warlord"})
	assert_eq(warlord["multipliers"], [1.5])
	# Phoenix feather: the bearer dies once and returns.
	var result := BattleSimulator.simulate([_with_unique("coin_squire", "phoenix_feather")],
		[{"def": _db.enemies["vault_warden"], "level": 3}])
	var revives: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "revive")
	assert_eq(revives.size(), 1)
	# Soul harvest: a kill by the bearer's attack creates a harvest roll.
	var harvest := BattleSimulator.simulate([_with_unique("the_judge", "soul_harvest")],
		[{"def": _db.enemies["beggar_ghost"], "level": 1}])
	var rolls: Array = harvest["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "harvest")
	assert_eq(rolls.size(), 1)
	assert_almost_eq(float(rolls[0]["chance"]), 0.15, 0.001)
