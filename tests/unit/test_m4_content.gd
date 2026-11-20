extends GutTest
## M4: themed enemy teams, rule bosses, region blessing.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


## Plays (auto-winning) until the boss shop of the given act.
## Coins tests: the run starts in the coins (the guided order).
func _run_to_boss(seed_value: int, act: int) -> RunState:
	var run := RunState.new_run(_db, seed_value, {"coins_first": true})
	run.region_order = ["coins", "coins"]  # these tests check the coin bosses
	while not (run.act == act and run.fight == 2):
		if run.stage == RunState.Stage.ENEMY_CHOICE:
			run.choose_enemy(0)
		run.apply_battle_result({"victory": true})
		if run.stage == RunState.Stage.REWARD:
			run.skip_reward()
		if run.stage == RunState.Stage.EVENT:
			run.resolve_event("leave")
	return run


func test_every_enemy_has_themes_and_a_role() -> void:
	for enemy in _db.regular_enemies():
		assert_gt(enemy.get("themes", []).size(), 0, enemy["id"])
		assert_has(["front", "any", "back"], enemy.get("role", ""), enemy["id"])


func test_boss_of_act_one_is_the_tax_collector() -> void:
	var run := _run_to_boss(5, 1)
	assert_eq(run.stage, RunState.Stage.PLANNING, "boss goes straight to the shop")
	assert_eq(run.chosen_enemy["boss_id"], "tax_collector")
	assert_eq(run.chosen_enemy["team"][0]["def_id"], "boss_tax_collector", "boss figure in front")
	assert_true(run.battle_options().get("gold_zero", false))


func test_tax_collector_hides_gold_but_steals_real_gold() -> void:
	var boss := {"def": _db.enemies["boss_tax_collector"], "level": 1}
	var midas := {"def": _db.figures["king_midas"], "level": 1}
	var result := BattleSimulator.simulate([midas, {"def": _db.figures["coin_squire"], "level": 1}], [boss], 20, {"gold_zero": true})
	var mults: Array = result["events"].filter(func(e: Dictionary) -> bool:
		return e["type"] == "update" and e["unit"]["uid"] == 1 and e["unit"]["multiplier"] > 1.0)
	assert_eq(mults.size(), 0, "Midas sees 0 gold")
	assert_lt(result["gold_after"], 20, "the boss stole real gold")
	assert_gte(result["gold_after"], 17, "at most 3 per battle")


func test_golden_wall_allows_seven_enemies() -> void:
	var run := _run_to_boss(9, 2)
	assert_eq(run.chosen_enemy["boss_id"], "golden_wall")
	var width := 0
	for unit in run.chosen_enemy["team"]:
		width += int(_db.enemies[unit["def_id"]].get("width", 1))
	assert_lte(width, 7, "boss (3 wide) + retinue fit in 7 slots")
	var team := EnemyGenerator.generate(_db, 40, RngStreams.new(1).stream("t"), "vault", 7)
	assert_eq(team.size(), 7)


func test_themed_teams_prefer_their_theme() -> void:
	var rng := RngStreams.new(2).stream("t")
	var themed := 0
	var total := 0
	for i in 200:
		for unit in EnemyGenerator.generate(_db, 6, rng, "vault", EnemyGenerator.MAX_TEAM, [], false, 1, "coins"):
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
