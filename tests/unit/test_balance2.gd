extends GutTest
## Balancing round 2: coin figures, suit bonuses, rewards, boss treasury.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _planning_run(seed_value := 3) -> RunState:
	var run := RunState.new_run(_db, seed_value)
	run.choose_enemy(0)
	return run


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


func test_start_gold_is_six() -> void:
	assert_eq(RunState.new_run(_db, 1).gold, 6)


func test_coin_squire_pays_gold_after_a_win() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("coin_squire", RunState.XP_FOR_LEVEL[2]), null]
	run.apply_battle_result({"victory": true, "gold_after": 0})
	assert_eq(run.last_income["extra"], 1 + 2, "level 1: +1, level 3: +2")


func test_coin_figures_raise_the_interest_cap() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("gold_armored"), _fig("the_judge")]
	run.gold = 100
	assert_eq(run.interest(), RunState.MAX_INTEREST + 2)


func test_cups_gain_health_per_cup_figure() -> void:
	var run := _planning_run()
	run.row = [_fig("altar_server"), _fig("blood_drinker"), _fig("the_judge")]
	var team := run.player_battle_team()
	assert_eq(team[0]["bonus_health"], 4)
	assert_eq(team[1]["bonus_health"], 4)
	assert_eq(team[2]["bonus_health"], 0)
	assert_has(team[0]["sources"], "suit_cups")


func test_swords_bleed_every_enemy_per_two_sword_figures() -> void:
	var run := _planning_run()
	run.row = [_fig("blade_apprentice"), _fig("executioner"), _fig("coin_squire")]
	var team := run.player_battle_team()
	var bonus: Array = team[0]["abilities"].filter(func(a: Dictionary) -> bool: return a.get("suit_bonus", false))
	assert_eq(bonus.size(), 1)
	assert_eq(bonus[0]["effect"], "apply_bleed")
	assert_eq(int(bonus[0]["values"][0]), 1)
	# A single sword figure gives nothing yet.
	run.row = [_fig("blade_apprentice"), null, null]
	var single: Array = run.player_battle_team()[0]["abilities"].filter(func(a: Dictionary) -> bool: return a.get("suit_bonus", false))
	assert_eq(single.size(), 0)


func test_wands_burn_the_front_enemy_per_wand_figure() -> void:
	var run := _planning_run()
	run.row = [_fig("spark_bearer"), _fig("enraged_one"), null]
	var team := run.player_battle_team()
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["vault_warden"], "level": 1}])
	var burned := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["side"] == 1 and e["unit"]["statuses"].get("burn", 0) >= 2:
			burned = true
			break
	assert_true(burned, "2 wand figures -> 2 burn at battle start")


func test_golden_scales_multiplies_rearmost_by_gold() -> void:
	var team := [{"def": _db.figures["golden_scales"], "level": 1}, {"def": _db.figures["the_judge"], "level": 1}]
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["vault_warden"], "level": 1}], 20)
	var seen := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 2 and absf(e["unit"]["multiplier"] - 1.2) < 0.001:
			seen = true
	assert_true(seen, "20 gold -> ×(1 + 4 × 0.05)")


func test_boss_win_opens_the_treasury() -> void:
	var run := RunState.new_run(_db, 5)
	run.fight = 2
	run.stage = RunState.Stage.ENEMY_CHOICE
	run._roll_enemy_options()
	run.choose_enemy(0)
	run.apply_battle_result({"victory": true, "gold_after": run.gold})
	assert_eq(run.treasure.size(), 3)
	var kinds: Array = run.treasure.map(func(t: Dictionary) -> String: return t["kind"])
	assert_has(kinds, "relic")
	assert_has(kinds, "legend_pack")
	assert_has(kinds, "gold")
	var before := run.gold
	assert_true(run.take_treasure(kinds.find("gold")))
	assert_eq(run.gold, before + RunState.TREASURE_GOLD)
	assert_true(run.treasure.is_empty())


func test_legend_pack_holds_three_legends() -> void:
	var run := _planning_run()
	run.treasure = [{"kind": "legend_pack"}]
	assert_true(run.take_treasure(0))
	assert_eq(run.open_pack["items"].size(), 3)
	for item in run.open_pack["items"]:
		assert_eq(_db.figures[item["def_id"]]["rank"], "legend")
	assert_eq(run.open_pack["picks_left"], 1)


func test_full_relic_bar_turns_the_relic_into_souls() -> void:
	var run := _planning_run()
	run.relics = ["war_chest", "whetstone", "death_bell"]
	run._roll_treasure()
	assert_eq(run.treasure[0]["kind"], "souls")


func test_hard_win_puts_a_free_loot_pack_in_the_next_shop() -> void:
	var run := RunState.new_run(_db, 4)
	run.choose_enemy(2)
	run.apply_battle_result({"victory": true, "gold_after": run.gold})
	run._roll_shop()
	var loot: Array = run.packs.filter(func(p: Dictionary) -> bool: return p.get("loot", false))
	assert_eq(loot.size(), 1)
	assert_true(loot[0]["free"])
	assert_has(RunState.LOOT_PACK_TYPES, loot[0]["type"])


func test_shop_never_rolls_relic_packs() -> void:
	var stream := RandomNumberGenerator.new()
	stream.seed = 9
	for i in 300:
		assert_ne(Items.roll_pack(_db, stream)["type"], "relic")


func test_treasure_survives_saving() -> void:
	var run := _planning_run()
	run.treasure = [{"kind": "gold", "amount": 12}]
	var loaded := RunState.from_dict(_db, str_to_var(var_to_str(run.to_dict())))
	assert_eq(loaded.treasure, run.treasure)
