extends GutTest
## M6: fusion stages, stats, ability choice, master abilities, secret recipes
## and the fusion occasions (altar, boss, candle, blood moon).

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


func _run_with(row: Array, source := "boss") -> RunState:
	var run := RunState.new_run(_db, 7)
	run.choose_enemy(0)
	run.row = row
	run.fusion_offer = {"source": source, "left": 1, "total": 1}
	return run


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


# --- Rules ---------------------------------------------------------------------------

func test_fusion_takes_higher_stats_plus_one_and_restarts_at_level_one() -> void:
	var run := _run_with([_fig("spark_bearer", 18), _fig("executioner"), null])
	var preview := Fusion.preview(run, 0, 1)
	assert_eq(preview["attack"], 5, "max(2, 4) + 1")
	assert_eq(preview["health"], 4, "max(2, 3) + 1")
	assert_eq(preview["stage"], 1)
	assert_true(run.fuse(0, 1))
	var fused: Dictionary = run.row[0]
	assert_null(run.row[1])
	assert_eq(run.figure_level(fused), 1)
	assert_eq(fused["fusion"]["abilities"], ["spark_bearer", "executioner"])
	assert_true(run.fusion_offer.is_empty(), "offer used up")
	var entry: Dictionary = run.player_battle_team()[0]
	assert_eq(entry["def"]["attack"], 5)
	assert_eq(entry["abilities"].size(), 2)
	assert_eq(entry["suits"], ["wands", "swords"])
	assert_eq(entry["def"]["fusion_name"], tr("NAME_STEM_EXECUTIONER") + "-" + tr("NAME_CORE_SPARK_BEARER"))


func test_more_than_two_abilities_need_a_choice() -> void:
	var run := _run_with([_fig("spark_bearer"), _fig("executioner"), _fig("blood_drinker"), _fig("coin_squire")], "blood_moon")
	run.fusion_offer = {"source": "blood_moon", "left": 2, "total": 2}
	assert_true(run.fuse(0, 1))
	assert_true(run.fuse(2, 3))
	assert_true(run.fusion_offer.is_empty())
	var preview := Fusion.preview(run, 0, 2)
	assert_eq(preview["candidates"].size(), 4)
	assert_eq(preview["keep"], 2)
	assert_eq(preview["stage"], 3, "two F1 make F3")
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_false(run.fuse(0, 2), "a choice of 2 is needed")
	assert_false(run.fuse(0, 2, ["spark_bearer"]), "too few")
	assert_true(run.fuse(0, 2, ["spark_bearer", "blood_drinker"]))
	assert_eq(run.row[0]["fusion"]["abilities"], ["spark_bearer", "blood_drinker"])
	assert_eq(Fusion.stage_of(run.row[0]), 3)


func test_no_more_than_four_figures_and_no_duplicate_merge() -> void:
	var run := _run_with([_fig("spark_bearer"), _fig("executioner"), _fig("coin_squire"), _fig("altar_server"), _fig("blade_apprentice")])
	run.fusion_offer = {"source": "blood_moon", "left": 2, "total": 2}
	assert_true(run.fuse(0, 1))
	assert_true(run.fuse(0, 2, ["spark_bearer", "coin_squire"]))
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_true(run.fuse(0, 3, ["spark_bearer", "altar_server"]))
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_eq(run.fusion_block(0, 4), "too_many")
	assert_false(run.can_place("spark_bearer", 0), "duplicates do not merge into fusions")


func test_altar_costs_souls_by_stage() -> void:
	var run := _run_with([_fig("spark_bearer"), _fig("executioner"), null], "altar")
	run.souls = 1
	assert_eq(run.fusion_block(0, 1), "souls")
	run.souls = 5
	assert_true(run.fuse(0, 1))
	assert_eq(run.souls, 3, "F1 costs 2")


func test_main_keeps_objects_partner_loses_them() -> void:
	var main := _fig("spark_bearer")
	main["blessing"] = "sun"
	var partner := _fig("executioner")
	partner["equipment"] = {"base": "blade", "rarity": 0, "affixes": [], "drawback": {}}
	var run := _run_with([main, partner, null])
	assert_true(run.fuse(0, 1))
	assert_eq(run.row[0]["blessing"], "sun")
	assert_false(run.row[0].has("equipment"))


func test_sell_value_is_the_sum_of_parts() -> void:
	var run := _run_with([_fig("king_midas"), _fig("executioner"), null])
	assert_true(run.fuse(0, 1))
	assert_eq(run.sell_value(run.row[0]), 4 + 2)


func test_secret_recipe_makes_a_final_figure() -> void:
	var run := _run_with([_fig("golden_scales"), _fig("king_midas"), _fig("coin_squire")])
	var preview := Fusion.preview(run, 0, 1)
	assert_eq(preview["recipe"], "midas_scales")
	assert_true(run.fuse(0, 1))
	assert_eq(run.row[0]["def_id"], "midas_scales")
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_eq(run.fusion_block(0, 2), "final")
	assert_false("midas_scales" in _db.legendary_figures().map(func(f: Dictionary) -> String: return f["id"]))


func test_master_ability_by_suit_combination() -> void:
	assert_eq(Fusion.master_for(_db, ["coins", "coins", "coins", "wands"])["id"], "golden_wall", "3 of a suit = pure")
	assert_eq(Fusion.master_for(_db, ["coins", "coins", "wands", "wands"])["id"], "gold_ember")
	assert_eq(Fusion.master_for(_db, ["swords", "cups", "wands", "cups"])["id"], "bloodletting", "cups most, then swords first")
	assert_eq(Fusion.master_for(_db, ["wands", "swords", "swords", "wands"])["id"], "glow_strike")


# --- Master abilities in battle ----------------------------------------------------

func _fused(def_id: String, suits: Array) -> Dictionary:
	return {"uid": 1, "def_id": def_id, "xp": 0, "fusion": {"parts": [def_id, def_id, def_id, def_id],
		"suits": suits, "abilities": [], "attack": 4, "health": 10}}


func _entry(figure: Dictionary) -> Dictionary:
	return {"def": Fusion.definition(_db, figure), "level": 1, "abilities": Fusion.abilities(_db, figure),
		"pierce": Fusion.pierces(_db, figure), "suits": figure["fusion"]["suits"]}


func test_golden_wall_shields_all_allies() -> void:
	var entry := _entry(_fused("coin_squire", ["coins", "coins", "coins", "coins"]))
	var result := BattleSimulator.simulate([entry, {"def": _db.figures["executioner"], "level": 1}],
		[{"def": _db.enemies["beggar_ghost"], "level": 1}], 25)
	var shielded := _events(result, "update").filter(func(e: Dictionary) -> bool:
		return e["unit"]["uid"] == 2 and e["unit"]["statuses"].get("shield", 0) == 5)
	assert_false(shielded.is_empty(), "25 gold -> shield 5 for the ally too")


func test_piercing_ignores_shield_and_bleeds() -> void:
	var entry := _entry(_fused("executioner", ["swords", "swords", "swords", "swords"]))
	var result := BattleSimulator.simulate([entry], [{"def": _db.enemies["vault_warden"], "level": 1}])
	var pierced := _events(result, "damage").filter(func(e: Dictionary) -> bool: return e["source"] == "pierce")
	assert_false(pierced.is_empty())


func test_glow_strike_hits_burning_targets_harder() -> void:
	var figure := _fused("spark_bearer", ["wands", "wands", "swords", "swords"])
	figure["fusion"]["abilities"] = ["spark_bearer"]
	var entry := _entry(figure)
	# Burn 2 per hit (Eternal Ember), so the target still burns at the next clash.
	var result := BattleSimulator.simulate([entry], [{"def": _db.enemies["greedy_dragon"], "level": 3}], 0,
		{"status_bonus": {"burn": {"all": 1}}})
	var hits := _events(result, "damage").filter(func(e: Dictionary) -> bool: return e["source"] == "attack" and e["uid"] == 2)
	assert_true(hits.size() >= 2)
	assert_eq(hits[1]["amount"], 6, "4 attack × 1.5 once the target burns")


func test_sea_of_tears_revives_first_fallen_ally_fully() -> void:
	var entry := _entry(_fused("altar_server", ["cups", "cups", "cups", "cups"]))
	var weak := {"def": _db.figures["blade_apprentice"], "level": 1}
	var result := BattleSimulator.simulate([weak, entry], [{"def": _db.enemies["vault_warden"], "level": 3}])
	var revives := _events(result, "revive")
	assert_eq(revives.size(), 1)
	assert_eq(revives[0]["health"], 2, "full health")


func test_steam_cloud_and_gold_ember() -> void:
	var steam := _entry(_fused("altar_server", ["wands", "cups", "wands", "cups"]))
	var result := BattleSimulator.simulate([steam], [{"def": _db.enemies["beggar_ghost"], "level": 3}])
	var cursed := _events(result, "update").filter(func(e: Dictionary) -> bool:
		return e["unit"]["side"] == BattleSimulator.ENEMY and e["unit"]["statuses"].get("curse", 0) > 0)
	assert_false(cursed.is_empty())
	var ember := _entry(_fused("coin_squire", ["coins", "wands", "coins", "wands"]))
	var burning := BattleSimulator.simulate([ember], [{"def": _db.enemies["beggar_ghost"], "level": 3}], 45)
	var burned := _events(burning, "update").filter(func(e: Dictionary) -> bool:
		return e["unit"]["side"] == BattleSimulator.ENEMY and e["unit"]["statuses"].get("burn", 0) == 3)
	assert_false(burned.is_empty(), "45 gold -> burn 3 (max)")


func test_overflow_turns_excess_healing_into_shield() -> void:
	# The altar server behind heals the full-health front fusion: excess -> shield.
	var figure := _fused("coin_squire", ["coins", "cups", "cups", "coins"])
	var healer := {"def": _db.figures["altar_server"], "level": 1}
	var result := BattleSimulator.simulate([_entry(figure), healer], [{"def": _db.enemies["beggar_ghost"], "level": 1}])
	var shielded := _events(result, "update").filter(func(e: Dictionary) -> bool:
		return e["unit"]["uid"] == 1 and e["unit"]["statuses"].get("shield", 0) > 0)
	assert_false(shielded.is_empty())


func test_recipe_figures_fight() -> void:
	var result := BattleSimulator.simulate([{"def": _db.figures["midas_scales"], "level": 1}],
		[{"def": _db.enemies["beggar_ghost"], "level": 1}], 20)
	var start: Array = _events(result, "update").filter(func(e: Dictionary) -> bool: return e["unit"]["uid"] == 1)
	assert_almost_eq(float(start[0]["unit"]["multiplier"]), 1.4, 0.001, "1.2 + 0.1 × 2")


# --- Occasions ---------------------------------------------------------------------

func test_boss_victory_offers_a_free_fusion() -> void:
	var run := RunState.new_run(_db, 5)
	run.row = [_fig("spark_bearer"), _fig("executioner"), null]
	while not run.is_boss_fight():
		if run.stage == RunState.Stage.ENEMY_CHOICE:
			run.choose_enemy(0)
		run.apply_battle_result({"victory": true})
		run.skip_reward()
		if run.stage == RunState.Stage.EVENT:
			run.resolve_event("leave")
	run.apply_battle_result({"victory": true})
	assert_eq(run.fusion_offer.get("source", ""), "boss")
	run.decline_fusion()
	assert_true(run.fusion_offer.is_empty())


func test_altar_event_and_candle() -> void:
	var run := RunState.new_run(_db, 4)
	run.row = [_fig("spark_bearer"), _fig("executioner"), null]
	run.souls = 4
	run.start_event("fusion_altar")
	assert_true(run.resolve_event("fuse"))
	assert_eq(run.fusion_offer["source"], "altar")
	assert_true(run.fuse(0, 1))
	assert_true(run.event["resolved"])
	var candle_run := _run_with([_fig("spark_bearer"), _fig("executioner"), null], "")
	candle_run.fusion_offer = {}
	candle_run.tarots = ["ritual_candle"]
	assert_true(candle_run.start_candle_fusion())
	candle_run.decline_fusion()
	assert_eq(candle_run.tarots, ["ritual_candle"], "declining keeps the candle")
	assert_true(candle_run.start_candle_fusion())
	assert_true(candle_run.fuse(0, 1))
	assert_true(candle_run.tarots.is_empty())


func test_fusion_survives_serialization() -> void:
	var run := _run_with([_fig("spark_bearer"), _fig("executioner"), null])
	run.fuse(0, 1)
	var copy := RunState.from_dict(_db, run.to_dict())
	assert_eq(copy.row[0]["fusion"]["parts"], ["spark_bearer", "executioner"])
