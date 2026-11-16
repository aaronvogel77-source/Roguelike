extends GutTest
## Smoke test: UI scenes load, compile and survive a few frames.


func test_battle_scene_runs() -> void:
	var scene: PackedScene = load("res://scenes/battle.tscn")
	assert_not_null(scene)
	var view: Node = scene.instantiate()
	add_child_autofree(view)
	await wait_frames(3)
	assert_true(is_instance_valid(view))


func test_run_scene_runs_through_its_screens() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	await wait_frames(3)
	view._on_choose_enemy(0)
	await wait_frames(2)
	assert_eq(view._run.stage, RunState.Stage.PLANNING)
	view._run.gold = 20
	view._select("shop", 0)
	view._on_slot_tapped(view._slot_for("row", 1))
	await wait_frames(2)
	assert_not_null(view._run.row[1], "bought into slot 1")
	view._on_undo()
	await wait_frames(2)
	assert_null(view._run.row[1], "undo restored the empty slot")
	view._run.apply_battle_result({"victory": true})
	view._show_stage()
	await wait_frames(2)
	assert_eq(view._run.stage, RunState.Stage.REWARD)
	view._on_skip_reward()
	await wait_frames(2)
	assert_eq(view._run.stage, RunState.Stage.ENEMY_CHOICE)


func test_merge_screen_and_sell_zone() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	await wait_frames(3)
	view._on_choose_enemy(0)
	await wait_frames(2)
	view._run.gold = 30
	view._run.shop[0] = view._run.row[0]["def_id"]
	view._buy(0, 0)
	await wait_frames(2)
	assert_eq(view._run.row[0]["xp"], 3, "merged")
	view._request_sell(0)
	await wait_frames(2)
	assert_null(view._run.row[0], "level-1 figure sold without confirmation")


func test_pack_overlay_tarot_and_insert() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	await wait_frames(3)
	view._on_choose_enemy(0)
	await wait_frames(2)
	view._run.debug_legend_pack()
	view._show_stage()
	await wait_frames(2)
	view._on_pack_take(0)
	await wait_frames(2)
	assert_eq(view._pack_pick, 0, "figure pick waits for a slot")
	view._on_pack_target(view._slot_for("row", 1))
	await wait_frames(2)
	assert_eq(view._db.figures[view._run.row[1]["def_id"]]["rank"], "legend")
	view._on_close_pack()
	view._run.tarots = ["strength"]
	view._show_stage()
	await wait_frames(2)
	view._selected = {"kind": "tarot", "index": 0}
	view._on_slot_tapped(view._slot_for("row", 1))
	await wait_frames(2)
	assert_eq(view._run.row[1]["bonus_attack"], 2)
	view._on_slot_inserted({"kind": "row", "index": 1}, view._slot_for("row", 0), "right")
	await wait_frames(2)
	assert_eq(view._db.figures[view._run.row[0]["def_id"]]["rank"], "legend", "inserted at the front")
