extends GutTest
## M7: Seelenglut, vault chests, upgrades, occultists, locked content, saving.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func test_soul_conversion_shrinks_and_is_capped() -> void:
	assert_eq(MetaState.glut_for_souls(_db, 0), 0)
	assert_eq(MetaState.glut_for_souls(_db, 5), 5)
	assert_eq(MetaState.glut_for_souls(_db, 10), 7, "5 + 5 × 0.5")
	assert_eq(MetaState.glut_for_souls(_db, 14), 8, "+ 4 × 0.25")
	assert_eq(MetaState.glut_for_souls(_db, 100), 12, "cap")


func test_locked_content_stays_out_of_a_new_run() -> void:
	var meta := MetaState.new()
	var run := RunState.new_run(_db, 3, meta.run_options(_db, "novice"))
	assert_true(run.db.legendary_figures().is_empty(), "aces are locked")
	var relic_ids: Array = run.db.items["relics"].map(func(r: Dictionary) -> String: return r["id"])
	assert_false("death_bell" in relic_ids)
	assert_true("war_chest" in relic_ids)
	assert_false("duel" in run.db.items["events"]["ids"])
	assert_false("hanged_man" in run.db.items["tarot"])
	assert_eq(_db.legendary_figures().size(), 4, "the shared content stays complete")


func test_chest_unlocks_and_refunds_duplicates() -> void:
	var meta := MetaState.new()
	meta.glut = 100
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var opened := 0
	var refunds := 0
	for i in 6:
		var before := meta.glut
		var found := meta.open_chest(_db, "events", rng)
		assert_eq(found.size(), 3)
		opened += found.filter(func(f: Dictionary) -> bool: return f["new"]).size()
		refunds += found.filter(func(f: Dictionary) -> bool: return not f["new"]).size()
		assert_eq(meta.glut, before - 8 + 2 * found.filter(func(f: Dictionary) -> bool: return not f["new"]).size())
	assert_eq(opened, 3, "three locked events, each unlocked once")
	assert_gt(refunds, 0)
	assert_true(meta.locked_content(_db)["events"].is_empty())
	var poor := MetaState.new()
	assert_eq(poor.open_chest(_db, "events", rng), [], "not enough glut")


func test_upgrades_cost_more_per_level_and_apply() -> void:
	var meta := MetaState.new()
	meta.glut = 200
	assert_eq(meta.upgrade_price(_db, "start_gold"), 25)
	assert_true(meta.buy_upgrade(_db, "start_gold"))
	assert_eq(meta.upgrade_price(_db, "start_gold"), 50)
	assert_true(meta.buy_upgrade(_db, "start_soul"))
	assert_true(meta.buy_upgrade(_db, "cheap_reroll"))
	var run := RunState.new_run(_db, 3, meta.run_options(_db, "novice"))
	assert_eq(run.gold, 7)
	assert_eq(run.souls, 1)
	run.choose_enemy(0)
	assert_eq(run.reroll_price(), 4, "first reroll 5 - 1")
	run.gold = 20
	run.reroll()
	assert_eq(run.reroll_price(), 6)


func test_occultists_by_purchase_or_challenge() -> void:
	var meta := MetaState.new()
	assert_false(meta.buy_occultist(_db, "usurer"), "no glut yet")
	meta.glut = 40
	assert_true(meta.buy_occultist(_db, "usurer"))
	var usurer := RunState.new_run(_db, 3, meta.run_options(_db, "usurer"))
	assert_eq(usurer.gold, 4)
	assert_eq(usurer.row[0]["def_id"], "coin_squire")
	usurer.gold = 50
	assert_eq(usurer.interest(), 8, "usurer cap 7 + 1 coin figure")
	# The fencer through a won run.
	var won := RunState.new_run(_db, 3)
	won.stage = RunState.Stage.WON
	won.souls = 6
	var summary := meta.finish_run(won)
	assert_eq(summary["glut"], 5, "5 + 1 × 0.5 = 5")
	assert_true("fencer" in summary["occultists"])
	var fencer := RunState.new_run(_db, 3, meta.run_options(_db, "fencer"))
	assert_eq(fencer.slot_count(), 4)
	fencer.gold = 50
	assert_eq(fencer.interest(), 0)


func test_save_round_trip_and_run_meta_survives_serialization() -> void:
	var meta := MetaState.new()
	meta.glut = 33
	meta.unlocked.append("relics:death_bell")
	meta.discover("figures", "executioner")
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())))
	assert_eq(copy.glut, 33)
	assert_true(copy.is_unlocked("relics", "death_bell"))
	assert_true(copy.is_discovered("figures", "executioner"))
	var run := RunState.new_run(_db, 9, meta.run_options(_db, "novice"))
	var loaded := RunState.from_dict(_db, str_to_var(var_to_str(run.to_dict())))  # the autosave format
	assert_true(loaded.db.legendary_figures().is_empty(), "locks come back with the save")
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(run.to_dict()))


func test_cosmetics_buy_and_equip() -> void:
	var meta := MetaState.new()
	meta.glut = 300
	assert_true(meta.buy_cosmetic(_db, "back_blood"))
	assert_true(meta.equip(_db, "back_blood"))
	assert_eq(meta.equipped["back"], "back_blood")
	assert_true(meta.buy_cosmetic(_db, "skin_hell_executioner"))
	meta.equip(_db, "skin_hell_executioner")
	assert_eq(meta.equipped["skins"]["executioner"], "skin_hell_executioner")
	meta.equip(_db, "skin_hell_executioner")
	assert_false(meta.equipped["skins"].has("executioner"), "equipping again takes the skin off")
