extends GutTest
## Second region (Glutmark / wands): region order per run, enemy pool by
## region, ability blessing, boss rules.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func test_two_regions_one_per_act_in_random_order() -> void:
	var firsts := {}
	for seed_value in 30:
		var run := RunState.new_run(_db, seed_value)
		assert_eq(run.region_order.size(), RunState.ACTS)
		assert_eq(run.region_order[0], run.region)
		assert_eq(run.region_order[0], run.region_order[1], "two antes per region")
		assert_ne(run.region_order[1], run.region_order[2], "then the other region")
		assert_eq(run.region_order.slice(0, 4), run.region_order.slice(4, 8), "A A B B A A B B")
		firsts[run.region] = true
	assert_eq(firsts.size(), 2, "both regions can come first")


func test_guided_run_starts_in_the_coins() -> void:
	for seed_value in 10:
		var run := RunState.new_run(_db, seed_value, {"coins_first": true})
		assert_eq(run.region, "coins")


func test_enemy_bands_use_their_region_only() -> void:
	var rng := RandomNumberGenerator.new()
	for region in ["coins", "wands"]:
		for act in [1, 2]:
			for fight in 3:
				rng.seed = act * 10 + fight
				for option in EnemyGenerator.options(_db, region, act, fight, rng):
					for unit in option["team"]:
						assert_eq(_db.enemies[unit["def_id"]].get("region", "coins"), region, unit["def_id"])


func test_act_change_switches_the_region_and_survives_saving() -> void:
	var run := RunState.new_run(_db, 5)
	run.act = 2
	run._enter_act_region()
	assert_eq(run.region, run.region_order[1])
	var loaded := RunState.from_dict(_db, run.to_dict())
	assert_eq(loaded.region_order, run.region_order)
	assert_eq(loaded.region, run.region)


func test_wands_blessing_burns_the_front_enemy() -> void:
	var run := RunState.new_run(_db, 3)
	run.region = "wands"
	run.row = [{"uid": 1, "def_id": "spark_bearer", "xp": 0}, {"uid": 2, "def_id": "coin_squire", "xp": 0}, null]
	var team := run.player_battle_team()
	var blessed: Array = team.filter(func(e: Dictionary) -> bool:
		return e["abilities"].any(func(a: Dictionary) -> bool: return a.get("blessing", false)))
	assert_eq(blessed.size(), 1, "only the wand figure")
	var enemy := [{"def": {"id": "dummy", "attack": 0, "health": 30}, "level": 1}]
	var result := BattleSimulator.simulate(team, enemy, 0, run.battle_options())
	var burned := false
	for event in result["events"]:
		if event["type"] == "update" and event["unit"]["uid"] > team.size() and int(event["unit"]["statuses"].get("burn", 0)) > 0:
			burned = true
	assert_true(burned, "the enemy burns at battle start")


func test_burning_floor_and_melting_shields() -> void:
	var player := [{"def": {"id": "p", "attack": 0, "health": 50}, "level": 1}]
	var enemy := [{"def": {"id": "e", "attack": 0, "health": 50}, "level": 1}]
	var floor_result := BattleSimulator.simulate(player, enemy, 0, {"burning_floor": true})
	var burns: Array = floor_result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "damage" and e["source"] == "burn")
	assert_true(burns.any(func(e: Dictionary) -> bool: return e["uid"] == 1), "player front burns")
	assert_true(burns.any(func(e: Dictionary) -> bool: return e["uid"] == 2), "enemy front burns")
	var shielded := [{"def": {"id": "p", "attack": 0, "health": 50}, "level": 1, "abilities": [
		{"trigger": "battle_start", "target": "self", "effect": "gain_shield", "values": [8, 8, 8]}]}]
	var melt := BattleSimulator.simulate(shielded, enemy, 0, {"melting_shields": true})
	var shields: Array = []
	for event in melt["events"]:
		if event["type"] == "update" and event["unit"]["uid"] == 1:
			shields.append(int(event["unit"]["statuses"].get("shield", 0)))
	assert_has(shields, 4, "8 shields halve to 4")
	assert_has(shields, 2, "then to 2")


func test_every_region_has_a_boss_for_each_ante() -> void:
	for region in _db.regions.keys():
		for ante in range(1, RunState.ACTS + 1):
			assert_false(_db.bosses_for(region, EnemyGenerator.boss_tier(ante)).is_empty(), "%s ante %d" % [region, ante])


func test_late_antes_scale_enemy_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var early: Array = EnemyGenerator.options(_db, "coins", 2, 1, rng)
	rng.seed = 4
	var late: Array = EnemyGenerator.options(_db, "coins", 6, 1, rng)
	assert_false(early[0]["team"][0].has("scale"), "ante 2: no factor")
	var scale: Array = late[0]["team"][0]["scale"]
	assert_almost_eq(float(scale[1]), pow(EnemyGenerator.ANTE_HEALTH, 4), 0.001)
	var unit: Dictionary = late[0]["team"][0]
	var definition: Dictionary = EnemyGenerator.unit_def(_db, unit)
	assert_gt(int(definition["health"]), int(_db.enemies[unit["def_id"]]["health"]))
	rng.seed = 9
	var boss: Dictionary = EnemyGenerator.options(_db, "wands", 3, 2, rng)[0]
	assert_eq(boss["boss_id"], "pyre_abbot", "ante 3: act-1 type again")
	var boss_unit: Dictionary = boss["team"][0]
	assert_almost_eq(float(boss_unit["scale"][1]), EnemyGenerator.ANTE_HEALTH * EnemyGenerator.AWAKENED.y, 0.001, "awakened")


func test_imprint_on_level_three_and_crown_choice() -> void:
	var run := RunState.new_run(_db, 2)
	run.row = [{"uid": 1, "def_id": "coin_squire", "xp": RunState.XP_FOR_LEVEL[2]}, null, null]
	assert_true(run.can_place("coin_squire", 0), "a duplicate on level III imprints")
	for i in RunState.MAX_IMPRINT:
		run._place("coin_squire", 0)
	assert_eq(int(run.row[0]["bonus_attack"]), RunState.MAX_IMPRINT)
	assert_eq(int(run.row[0]["bonus_health"]), RunState.MAX_IMPRINT)
	assert_false(run.can_place("coin_squire", 0), "imprint is capped")
	run.row.resize(RunState.MAX_SLOTS)
	run.crown_offer = true
	assert_true(run.take_crown("relic"))
	assert_eq(run.relic_slots, RunState.CROWN_MAX_RELICS)
	run.crown_offer = true
	assert_false(run.take_crown("relic"), "relic places capped")
	assert_true(run.take_crown("slot"))
	assert_eq(run.slot_count(), RunState.CROWN_MAX_SLOTS)
	var loaded := RunState.from_dict(_db, run.to_dict())
	assert_eq(loaded.relic_slots, RunState.CROWN_MAX_RELICS)


func test_glut_cap_grows_with_the_ante() -> void:
	assert_eq(MetaState.glut_cap(3), 12)
	assert_eq(MetaState.glut_cap(8), 22)
	assert_eq(MetaState.glut_cap(20), 30)
