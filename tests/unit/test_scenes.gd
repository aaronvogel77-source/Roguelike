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
	view._new_run()
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
	assert_true(view._run.stage in [RunState.Stage.ENEMY_CHOICE, RunState.Stage.EVENT])


func test_merge_screen_and_sell_zone() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	view._new_run()
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
	view._new_run()
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


func test_event_screens_skip_and_soul_pack() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	view._new_run()
	await wait_frames(3)
	for id in view._db.items["events"]["ids"]:
		view._run.start_event(id)
		view._show_stage()
		await wait_frames(1)
	view._run.start_event("altar")
	view._run.row[1] = {"uid": 77, "def_id": "coin_squire", "xp": 0}
	view._show_stage()
	view._on_event_option("sacrifice_one", 1)
	view._on_event_row_tapped(view._slot_for("row", 1))
	await wait_frames(2)
	assert_gt(view._run.souls, 0, "sacrificed for souls")
	view._on_event_option("leave", 0)
	await wait_frames(2)
	assert_ne(view._run.stage, RunState.Stage.EVENT)
	if view._run.stage == RunState.Stage.ENEMY_CHOICE and not view._run.is_boss_fight():
		view._on_skip_fight()
		await wait_frames(2)
	view._run.stage = RunState.Stage.PLANNING
	view._run.chosen_enemy = view._run.enemy_options[0]
	view._run.souls = 8
	view._show_stage()
	await wait_frames(2)
	assert_true(view._run.buy_soul_pack())
	view._show_stage()
	await wait_frames(2)
	view._on_pack_take(0)
	await wait_frames(2)
	assert_eq(view._run.pacts.size(), 1)


func test_market_mirror_and_equipment_compare() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	view._new_run()
	await wait_frames(3)
	view._run.gold = 30
	view._run.souls = 3
	view._run.row = [{"uid": 1, "def_id": "coin_squire", "xp": 0}, null, null]
	view._run.start_event("black_market")
	view._show_stage()
	await wait_frames(2)
	view._on_slot_dropped({"kind": "market_figure"}, view._slot_for("row", 1))
	await wait_frames(2)
	assert_not_null(view._run.row[1], "figure bought by dragging")
	view._run.start_event("mirror")
	view._show_stage()
	view._on_event_option("duplicate", 1)
	view._on_event_row_tapped(view._slot_for("row", 0))
	await wait_frames(2)
	assert_eq(view._run.row.filter(func(f): return f != null and f["def_id"] == "coin_squire").size(), 2, "duplicated")
	# Equipment compare when the figure already wears something.
	view._run.event = {}
	view._run.stage = RunState.Stage.PLANNING
	view._run.chosen_enemy = view._run.enemy_options[0]
	view._run.row[0]["equipment"] = {"base": "amulet", "rarity": 0, "affixes": [], "drawback": {}}
	view._run.open_pack = {"pack": {"type": "equipment", "size": "normal"}, "picks_left": 1,
		"items": [{"kind": "equipment", "item": {"base": "blade", "rarity": 0, "affixes": [], "drawback": {}}}]}
	view._show_stage()
	await wait_frames(2)
	view._on_slot_dropped({"kind": "pack", "index": 0}, view._slot_for("row", 0))
	await wait_frames(2)
	assert_eq(view._run.row[0]["equipment"]["base"], "amulet", "nothing swapped before confirming")


func test_main_menu_vault_and_grimoire_pages_build() -> void:
	var view: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(view)
	await wait_frames(2)
	var menu: MetaView = view._screen.get_child(view._screen.get_child_count() - 1)
	for page in ["occultists", "vault", "chests", "altar", "portraits", "mirror", "grimoire", "menu"]:
		menu._show(page)
		await wait_frames(1)
	assert_true(is_instance_valid(menu))


func test_legendary_skin_in_a_chest_gets_its_reveal() -> void:
	var face := Label.new()
	var opening := PackOpening.create([{"face": face, "rarity": 5, "skin": "skin_frost_king"}], "Test")
	add_child_autofree(opening)
	# Shake (~0.7 s) + dealing (~0.5 s); wait generously, CI machines are slower.
	await wait_seconds(2.5)
	assert_eq(opening._slots.size(), 1)
	opening._ready_to_flip = true
	opening._flip(opening._slots[0])
	await wait_frames(2)
	var reveals := opening.get_children().filter(func(c: Node) -> bool: return c is LegendaryReveal)
	assert_eq(reveals.size(), 1, "the legendary reveal opens")


func test_weapons_never_cover_a_face() -> void:
	# Rule from the pixel-art skill: the head is drawn over every weapon.
	var db := ContentDb.load_default()
	for id in db.figures:
		var actor := FigureActor.new()
		actor.setup(db.figures[id], {"uid": 1, "health": 1, "max_health": 1}, false)
		var head: Node = actor._sprites["head"]
		var weapon: Node = actor._sprites["weapon"]
		assert_gt(head.get_index(), weapon.get_index(), "%s: head above weapon" % id)
		actor.free()

