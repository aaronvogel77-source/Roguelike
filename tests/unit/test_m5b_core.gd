extends GutTest
## M5b: souls, pacts, skip marks, boss skipping.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


func _planning_run(seed_value := 3) -> RunState:
	var run := RunState.new_run(_db, seed_value)
	run.choose_enemy(0)
	return run


func test_boss_win_gives_two_souls() -> void:
	var run := RunState.new_run(_db, 5)
	while not run.is_boss_fight():
		if run.stage == RunState.Stage.ENEMY_CHOICE:
			run.choose_enemy(0)
		run.apply_battle_result({"victory": true})
		run.skip_reward()
		if run.stage == RunState.Stage.EVENT:
			run.resolve_event("leave")
	var before := run.souls
	run.apply_battle_result({"victory": true})
	assert_gte(run.souls, before + 2)


func test_soul_pack_offers_unowned_pacts() -> void:
	var run := _planning_run()
	run.souls = 5
	run.pacts = ["blood_pact"]
	assert_true(run.buy_soul_pack())
	assert_eq(run.souls, 1, "soul packs cost 4")
	for item in run.open_pack["items"]:
		assert_eq(item["kind"], "pact")
		assert_ne(item["id"], "blood_pact")
	assert_true(run.take_pack_item(0))
	assert_eq(run.pacts.size(), 2)


func test_soul_hunger_makes_soul_packs_pricier() -> void:
	var run := _planning_run()
	run.pacts = ["soul_hunger"]
	assert_eq(run.soul_pack_price(), 5)


func test_blood_pact_multiplies_and_drains() -> void:
	var run := _planning_run()
	run.row = [_fig("the_judge"), null, null]
	run.pacts = ["blood_pact"]
	var entry: Dictionary = run.player_battle_team()[0]
	assert_has(entry["multipliers"], 1.5)
	var result := BattleSimulator.simulate([entry], [{"def": _db.enemies["beggar_ghost"], "level": 1}])
	var drained := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 1 and e["unit"]["health"] == 4:
			drained = true
	assert_true(drained, "5 health -> 4 (10 %, min 1)")


func test_golden_oath_interest_and_doubled_gold() -> void:
	var run := _planning_run()
	run.pacts = ["golden_oath"]
	run.gold = 60
	assert_eq(run.interest(), 10)
	assert_eq(run.reroll_price(), 2)
	assert_eq(run.battle_options()["gold_factor"], 2)
	var midas := {"def": _db.figures["king_midas"], "level": 3}
	var result := BattleSimulator.simulate([midas], [{"def": _db.enemies["vault_warden"], "level": 3}], 10, {"gold_factor": 2})
	var hits: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "damage" and e["source"] == "attack" and e["uid"] == 2)
	# Midas L3: 6 × (1 + 20/10) = 18 (shield absorbs some, so check the multiplier instead).
	var mult_seen := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 1 and absf(e["unit"]["multiplier"] - 3.0) < 0.01:
			mult_seen = true
	assert_true(mult_seen, "20 visible gold -> ×3")


func test_return_pact_revives_two_figures() -> void:
	var team := [{"def": _db.figures["coin_squire"], "level": 1}, {"def": _db.figures["spark_bearer"], "level": 1},
		{"def": _db.figures["blade_apprentice"], "level": 1}]
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["greedy_dragon"], "level": 3}], 0, {"team_revives": 2})
	var revives: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "revive")
	assert_eq(revives.size(), 2)


func test_blade_oath_doubles_player_bleed() -> void:
	var apprentice := {"def": _db.figures["blade_apprentice"], "level": 1, "bonus_health": 20}
	var result := BattleSimulator.simulate([apprentice], [{"def": _db.enemies["vault_warden"], "level": 1}], 0, {"bleed_factor": 2})
	var doubled := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["side"] == 1 and e["unit"]["statuses"].get("bleed", 0) == 2:
			doubled = true
	assert_true(doubled)


func test_vanguard_pact_gathers_shields_to_the_front() -> void:
	var run := _planning_run()
	run.row = [_fig("the_judge"), _fig("coin_squire"), null]
	run.pacts = ["vanguard_pact"]
	var team := run.player_battle_team()
	assert_has(team[0]["multipliers"], 2.0)
	assert_eq(team[1]["bonus_attack"], -1, "rearmost -1 attack")
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["beggar_ghost"], "level": 1}])
	var gathered := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 1 and e["unit"]["statuses"].get("shield", 0) >= 2:
			gathered = true
	assert_true(gathered, "front took the squire's shield")


func test_skip_mark_and_skipping_a_fight() -> void:
	var run := RunState.new_run(_db, 8)
	var mark: String = run.enemy_options[0]["skip_mark"]
	assert_has(_db.items["marks"], mark)
	var gold_before := run.gold
	assert_true(run.skip_fight())
	assert_eq(run.fight, 1)
	assert_eq(run.gold, gold_before, "no gold for skipping")


func test_mega_pack_mark_gives_a_free_mega_pack() -> void:
	var run := RunState.new_run(_db, 8)
	run.enemy_options[0]["skip_mark"] = "mega_pack"
	run.skip_fight()
	run.choose_enemy(0)
	assert_eq(run.packs[0]["size"], "mega")
	assert_eq(run.pack_cost(run.packs[0]), 0)


func test_boss_skip_sacrifices_a_figure_and_last_boss_is_mandatory() -> void:
	var run := RunState.new_run(_db, 6)
	while not run.is_boss_fight():
		run.skip_fight()
	assert_eq(run.stage, RunState.Stage.PLANNING)
	assert_true(run.can_skip_boss())
	run.row[1] = _fig("coin_squire")
	assert_true(run.skip_boss(1))
	assert_null(run.row[1])
	assert_eq(run.act, 2)
	while not run.is_boss_fight():
		run.skip_fight()
	assert_false(run.can_skip_boss(), "the final boss cannot be skipped")
