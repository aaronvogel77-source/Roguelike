extends GutTest
## Run loop rules: start, shop, merging, levels, income, slots, rewards, end.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _run(seed_value := 11) -> RunState:
	return RunState.new_run(_db, seed_value)


func _planning_run() -> RunState:
	var run := _run()
	run.choose_enemy(0)
	return run


func _win() -> Dictionary:
	return {"victory": true}


func test_new_run_starts_with_one_page_and_six_gold() -> void:
	var run := _run()
	assert_eq(run.gold, 6)
	assert_eq(run.slot_count(), 3)
	assert_not_null(run.row[0])
	assert_eq(_db.figures[run.row[0]["def_id"]]["rank"], "page")
	assert_eq(run.stage, RunState.Stage.ENEMY_CHOICE)
	assert_eq(run.enemy_options.size(), 3, "easy / medium / hard")


func test_choosing_an_enemy_opens_the_shop() -> void:
	var run := _planning_run()
	assert_eq(run.stage, RunState.Stage.PLANNING)
	assert_eq(run.shop.size(), 3)


func test_buy_costs_the_rank_price() -> void:
	var run := _planning_run()
	run.gold = 20
	run.shop[0] = "the_judge"
	assert_true(run.buy(0, 1))
	assert_eq(run.gold, 20 - 8, "kings cost 8")
	run.shop[1] = "coin_squire"
	assert_true(run.buy(1, 2))
	assert_eq(run.gold, 12 - 3, "pages cost 3")
	assert_not_null(run.row[1])
	assert_eq(run.shop[0], "")


func test_cannot_buy_onto_a_different_figure_or_without_gold() -> void:
	var run := _planning_run()
	run.shop[0] = "the_judge"
	run.row[0] = {"uid": 99, "def_id": "coin_squire", "xp": 0}
	assert_false(run.buy(0, 0))
	run.gold = 2
	assert_false(run.buy(0, 1))


func test_duplicate_merges_and_levels_up_after_three() -> void:
	var run := _planning_run()
	run.gold = 100
	run.row[0] = {"uid": 99, "def_id": "coin_squire", "xp": 0}
	for i in 3:
		run.shop[0] = "coin_squire"
		assert_true(run.buy(0, 0))
	assert_eq(run.figure_level(run.row[0]), 2)
	for i in 3:
		run.shop[0] = "coin_squire"
		run.buy(0, 0)
	assert_eq(run.figure_level(run.row[0]), 3)


func test_sell_value_is_half_price_plus_level_bonus() -> void:
	var run := _planning_run()
	run.row[1] = {"uid": 50, "def_id": "the_judge", "xp": 9}
	var before := run.gold
	assert_true(run.sell(1))
	assert_eq(run.gold, before + 4 + 1, "king 8 / 2 + level 2 bonus")
	assert_null(run.row[1])


func test_move_swaps_figures() -> void:
	var run := _planning_run()
	run.row[1] = {"uid": 50, "def_id": "the_judge", "xp": 0}
	var first = run.row[0]
	assert_true(run.move(0, 1))
	assert_eq(run.row[0]["def_id"], "the_judge")
	assert_eq(run.row[1], first)


func test_reroll_price_rises() -> void:
	var run := _planning_run()
	run.gold = 20
	assert_eq(run.reroll_price(), 5)
	run.reroll()
	assert_eq(run.gold, 15)
	assert_eq(run.reroll_price(), 6)
	run.free_rerolls = 2
	assert_eq(run.reroll_price(), 0)
	run.reroll()
	run.reroll()
	assert_eq(run.gold, 15, "two free rerolls")
	assert_eq(run.reroll_price(), 6)


func test_slots_cannot_be_bought() -> void:
	var run := _planning_run()
	assert_false(run.has_method("buy_slot"), "slots only come from bosses")


func test_income_with_difficulty_bonus_and_interest() -> void:
	var run := _run()
	run.choose_enemy(2)  # hard: +5 and a loot pack
	run.gold = 12
	run.apply_battle_result({"victory": true, "gold_after": 12})
	# 12 gold -> interest 2; income 4 + 5 + 2 = 11 (+ coin figures' win gold).
	var extra := int(run.last_income["extra"])
	assert_eq(run.gold, 23 + extra)
	assert_eq(run.last_income["bonus"], 5)
	assert_eq(run.last_income["interest"], 2)
	assert_true(run.last_income.get("loot", false))
	assert_false(run.open_pack.is_empty(), "loot pack opens right away")


func test_interest_is_capped_at_five() -> void:
	var run := _run()
	run.gold = 80
	assert_eq(run.interest(), 5)


func test_win_gives_third_xp_and_opens_rewards() -> void:
	var run := _planning_run()
	run.apply_battle_result(_win())
	assert_eq(run.row[0]["xp"], 1)
	assert_eq(run.stage, RunState.Stage.REWARD)
	assert_eq(run.rewards.size(), 3)


func test_loss_ends_the_run() -> void:
	var run := _planning_run()
	run.apply_battle_result({"victory": false})
	assert_eq(run.stage, RunState.Stage.LOST)


func test_reward_goes_to_free_slot_or_merges() -> void:
	var run := _planning_run()
	run.apply_battle_result(_win())
	run.rewards[0] = run.row[0]["def_id"]
	assert_eq(run.reward_target(run.rewards[0]), 0, "merges into the matching figure")
	assert_true(run.take_reward(0))
	assert_eq(run.row[0]["xp"], 1 + 3)
	assert_eq(run.stage, RunState.Stage.ENEMY_CHOICE)


func test_skip_reward_gives_two_gold() -> void:
	var run := _planning_run()
	run.apply_battle_result(_win())
	var before := run.gold
	run.skip_reward()
	assert_eq(run.gold, before + 2)


func test_boss_win_adds_a_slot_and_two_acts_win_the_run() -> void:
	var run := _run()
	for i in 6:
		if run.is_boss_fight():
			assert_eq(run.stage, RunState.Stage.PLANNING, "bosses skip the enemy choice")
		else:
			assert_eq(run.stage, RunState.Stage.ENEMY_CHOICE)
			run.choose_enemy(0)
		var slots_before := run.slot_count()
		var was_boss := run.is_boss_fight()
		run.apply_battle_result(_win())
		if was_boss:
			assert_eq(run.slot_count(), slots_before + 1)
		if run.stage == RunState.Stage.REWARD:
			run.skip_reward()
		if run.stage == RunState.Stage.EVENT:
			run.resolve_event("leave")
	assert_eq(run.stage, RunState.Stage.WON)
	assert_eq(run.battles_won, 6)


func test_serialization_round_trip_keeps_rng_position() -> void:
	var run := _planning_run()
	run.reroll()
	var copy := RunState.from_dict(_db, run.to_dict())
	run.gold = 50
	copy.gold = 50
	run.reroll()
	copy.reroll()
	assert_eq(copy.shop, run.shop, "same rng position -> same shop")
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(run.to_dict()))


func test_same_seed_same_run() -> void:
	var a := _run(77)
	var b := _run(77)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))


func test_enemy_budget_grows_with_act_and_difficulty() -> void:
	assert_lt(EnemyGenerator.budget(1, 0, 0), EnemyGenerator.budget(1, 0, 2))
	assert_lt(EnemyGenerator.budget(1, 2, 2), EnemyGenerator.budget(2, 2, 2))


func test_generated_team_respects_budget() -> void:
	var rng := RngStreams.new(3).stream("t")
	for b in [3, 5, 9, 20, 40]:
		var team := EnemyGenerator.generate(_db, b, rng)
		var spent := 0
		for unit in team:
			spent += int(_db.enemies[unit["def_id"]]["cost"]) * unit["level"]
		assert_lte(spent, b)
		assert_lte(team.size(), 6)
		assert_gt(team.size(), 0)


func test_rank_odds_sum_to_one_hundred() -> void:
	for entry in RunState.RANK_ODDS:
		var total := 0
		for value in entry[1]:
			total += value
		assert_eq(total, 100)


func test_no_merging_beyond_max_level() -> void:
	var run := _planning_run()
	run.gold = 100
	run.row[0] = {"uid": 99, "def_id": "coin_squire", "xp": RunState.XP_FOR_LEVEL[2]}
	run.shop[0] = "coin_squire"
	assert_false(run.buy(0, 0), "level 3 cannot merge")
	assert_true(run.buy(0, 1), "a second copy in a free slot is fine")
	assert_eq(run.reward_target("coin_squire"), 1, "rewards merge into the copy that can still level")


func test_moving_onto_an_equal_figure_merges() -> void:
	var run := _planning_run()
	run.row[0] = {"uid": 1, "def_id": "coin_squire", "xp": 2}
	run.row[1] = {"uid": 2, "def_id": "coin_squire", "xp": 1}
	assert_true(run.move(1, 0))
	assert_eq(run.row[0]["xp"], 2 + 1 + 3)
	assert_null(run.row[1])


func test_selling_is_allowed_on_the_reward_screen() -> void:
	var run := _planning_run()
	run.apply_battle_result({"victory": true})
	assert_eq(run.stage, RunState.Stage.REWARD)
	assert_true(run.sell(0))


func test_enemy_options_are_ordered_by_real_strength() -> void:
	for seed_value in 20:
		var rng := RngStreams.new(seed_value).stream("enemy_gen")
		var options := EnemyGenerator.options(_db, "coins", 1, seed_value % 2, rng)
		var powers: Array = options.map(func(o: Dictionary) -> float: return EnemyGenerator.power(_db, o["team"]))
		assert_true(powers[0] <= powers[1] and powers[1] <= powers[2], "easy <= medium <= hard: %s" % str(powers))


func test_first_boss_has_a_small_retinue() -> void:
	assert_eq(EnemyGenerator.budget(1, 2, 2), 2)


func test_figures_can_be_moved_in_events_but_not_at_the_grave() -> void:
	var run := RunState.new_run(_db, 4)
	run.row = [{"uid": 1, "def_id": "coin_squire", "xp": 0}, {"uid": 2, "def_id": "executioner", "xp": 0}, null]
	run.start_event("mirror")
	assert_true(run.move(0, 1))
	run.start_event("grave_robber")
	assert_false(run.move(0, 1), "the grave robber takes the rearmost figure")


func test_difficulties_are_clearly_apart_and_hard_has_company() -> void:
	for seed_value in 30:
		var rng := RngStreams.new(seed_value).stream("enemy_gen")
		for act in [1, 2]:
			for fight in [0, 1]:
				var options := EnemyGenerator.options(_db, "coins", act, fight, rng)
				var powers: Array = options.map(func(o: Dictionary) -> float: return EnemyGenerator.power(_db, o["team"]))
				var step := EnemyGenerator.ACT1_MIN_STEP if act == 1 else EnemyGenerator.MIN_STEP
				assert_true(powers[1] >= powers[0] * step - 0.01, "medium clearly above easy: %s" % str(powers))
				assert_true(powers[2] >= powers[1] * step - 0.01, "hard clearly above medium: %s" % str(powers))
				assert_gte(options[2]["team"].size(), 2, "hard is never a lone enemy")

