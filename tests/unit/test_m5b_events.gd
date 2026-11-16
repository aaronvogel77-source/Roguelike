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


func test_events_appear_and_pity_guarantees_one() -> void:
	var run := RunState.new_run(_db, 4)
	var seen := false
	for i in 3:
		if run.stage == RunState.Stage.ENEMY_CHOICE:
			run.choose_enemy(0)
		if run.stage == RunState.Stage.PLANNING:
			run.apply_battle_result({"victory": true})
		if run.stage == RunState.Stage.REWARD:
			run.skip_reward()
		if run.stage == RunState.Stage.EVENT:
			seen = true
			break
	assert_true(seen, "at the latest after 3 battles")


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
	assert_eq(run.open_pack["items"][0]["item"]["affixes"].size(), 3)
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
