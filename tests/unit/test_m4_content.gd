extends GutTest
## M4: themed enemy teams, rule bosses, region blessing.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _run_to_boss(seed_value: int, act: int) -> RunState:
	var run := RunState.new_run(_db, seed_value)
	while not (run.act == act and run.fight == 2):
		run.choose_enemy(0)
		run.apply_battle_result({"victory": true})
		if run.stage == RunState.Stage.REWARD:
			run.skip_reward()
	return run


func test_every_enemy_has_themes_and_a_role() -> void:
	for enemy in _db.enemies.values():
		assert_gt(enemy.get("themes", []).size(), 0, enemy["id"])
		assert_has(["front", "any", "back"], enemy.get("role", ""), enemy["id"])


func test_boss_of_act_one_is_the_tax_collector() -> void:
	var run := _run_to_boss(5, 1)
	assert_eq(run.enemy_options.size(), 1)
	assert_eq(run.enemy_options[0]["boss_id"], "tax_collector")
	run.choose_enemy(0)
	assert_eq(run.battle_gold(), 0, "gold counts as 0 in battle")
	assert_true(run.battle_options().get("gold_zero", false))


func test_tax_collector_does_not_change_real_gold() -> void:
	var run := _run_to_boss(5, 1)
	run.choose_enemy(0)
	run.gold = 20
	run.apply_battle_result({"victory": true, "gold_after": 0})
	# 20 kept + 5 income + 4 boss bonus + 4 interest
	assert_eq(run.gold, 33)


func test_golden_wall_allows_seven_enemies() -> void:
	var run := _run_to_boss(9, 2)
	assert_eq(run.enemy_options[0]["boss_id"], "golden_wall")
	var team := EnemyGenerator.generate(_db, 40, RngStreams.new(1).stream("t"), "vault", 7)
	assert_eq(team.size(), 7)


func test_themed_teams_prefer_their_theme() -> void:
	var rng := RngStreams.new(2).stream("t")
	var themed := 0
	var total := 0
	for i in 200:
		for unit in EnemyGenerator.generate(_db, 6, rng, "vault"):
			total += 1
			if "vault" in _db.enemies[unit["def_id"]]["themes"]:
				themed += 1
	# 3 of 8 enemies are "vault"; with weight 3 they should be well above 3/8.
	assert_gt(float(themed) / total, 0.5)


func test_teams_are_ordered_front_to_back() -> void:
	var rng := RngStreams.new(4).stream("t")
	var order := {"front": 0, "any": 1, "back": 2}
	for i in 50:
		var team := EnemyGenerator.generate(_db, 8, rng, "greed")
		var last := 0
		for unit in team:
			var role: int = order[_db.enemies[unit["def_id"]]["role"]]
			assert_gte(role, last)
			last = role


func test_region_blessing_shields_coin_figures_only() -> void:
	var blessing: Dictionary = _db.regions["coins"]["blessing"]
	var player := [{"def": _db.figures["gold_armored"], "level": 1}, {"def": _db.figures["the_judge"], "level": 1}]
	var result := BattleSimulator.simulate(player, [{"def": _db.enemies["beggar_ghost"], "level": 1}], 0, {"blessing": blessing})
	var blessed: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "blessing")
	assert_eq(blessed.size(), 1)
	assert_eq(blessed[0]["uid"], 1, "only the coin figure")
