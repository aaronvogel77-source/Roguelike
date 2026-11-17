extends GutTest
## Balancing round 2: coin figures, suit bonuses, rewards, boss treasury.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _planning_run(seed_value := 3) -> RunState:
	var run := RunState.new_run(_db, seed_value)
	run.choose_enemy(0)
	return run


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


func test_start_gold_is_six() -> void:
	assert_eq(RunState.new_run(_db, 1).gold, 6)


func test_coin_squire_pays_gold_after_a_win() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("coin_squire", RunState.XP_FOR_LEVEL[2]), null]
	run.apply_battle_result({"victory": true, "gold_after": 0})
	assert_eq(run.last_income["extra"], 1 + 2, "level 1: +1, level 3: +2")


func test_coin_figures_raise_the_interest_cap() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("gold_armored"), _fig("the_judge")]
	run.gold = 100
	assert_eq(run.interest(), RunState.MAX_INTEREST + 2)


func test_cups_gain_health_per_cup_figure() -> void:
	var run := _planning_run()
	run.row = [_fig("altar_server"), _fig("blood_drinker"), _fig("the_judge")]
	var team := run.player_battle_team()
	assert_eq(team[0]["bonus_health"], 4)
	assert_eq(team[1]["bonus_health"], 4)
	assert_eq(team[2]["bonus_health"], 0)
	assert_has(team[0]["sources"], "suit_cups")


func test_swords_bleed_every_enemy_per_two_sword_figures() -> void:
	var run := _planning_run()
	run.row = [_fig("blade_apprentice"), _fig("executioner"), _fig("coin_squire")]
	var team := run.player_battle_team()
	var bonus: Array = team[0]["abilities"].filter(func(a: Dictionary) -> bool: return a.get("suit_bonus", false))
	assert_eq(bonus.size(), 1)
	assert_eq(bonus[0]["effect"], "apply_bleed")
	assert_eq(int(bonus[0]["values"][0]), 1)
	# A single sword figure gives nothing yet.
	run.row = [_fig("blade_apprentice"), null, null]
	var single: Array = run.player_battle_team()[0]["abilities"].filter(func(a: Dictionary) -> bool: return a.get("suit_bonus", false))
	assert_eq(single.size(), 0)


func test_wands_burn_the_front_enemy_per_wand_figure() -> void:
	var run := _planning_run()
	run.row = [_fig("spark_bearer"), _fig("enraged_one"), null]
	var team := run.player_battle_team()
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["vault_warden"], "level": 1}])
	var burned := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["side"] == 1 and e["unit"]["statuses"].get("burn", 0) >= 2:
			burned = true
			break
	assert_true(burned, "2 wand figures -> 2 burn at battle start")


func test_golden_scales_multiplies_rearmost_by_gold() -> void:
	var team := [{"def": _db.figures["golden_scales"], "level": 1}, {"def": _db.figures["the_judge"], "level": 1}]
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["vault_warden"], "level": 1}], 20)
	var seen := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 2 and absf(e["unit"]["multiplier"] - 1.2) < 0.001:
			seen = true
	assert_true(seen, "20 gold -> ×(1 + 4 × 0.05)")


func test_boss_win_opens_the_treasury() -> void:
	var run := RunState.new_run(_db, 5)
	run.fight = 2
	run.stage = RunState.Stage.ENEMY_CHOICE
	run._roll_enemy_options()
	run.choose_enemy(0)
	run.apply_battle_result({"victory": true, "gold_after": run.gold})
	assert_eq(run.treasure.size(), 3)
	var kinds: Array = run.treasure.map(func(t: Dictionary) -> String: return t["kind"])
	assert_has(kinds, "relic")
	assert_has(kinds, "legend_pack")
	assert_has(kinds, "gold")
	var before := run.gold
	assert_true(run.take_treasure(kinds.find("gold")))
	assert_eq(run.gold, before + RunState.TREASURE_GOLD)
	assert_true(run.treasure.is_empty())


func test_legend_pack_holds_three_legends() -> void:
	var run := _planning_run()
	run.treasure = [{"kind": "legend_pack"}]
	assert_true(run.take_treasure(0))
	assert_eq(run.open_pack["items"].size(), 3)
	for item in run.open_pack["items"]:
		assert_eq(_db.figures[item["def_id"]]["rank"], "legend")
	assert_eq(run.open_pack["picks_left"], 1)


func test_full_relic_bar_turns_the_relic_into_souls() -> void:
	var run := _planning_run()
	run.relics = ["war_chest", "whetstone", "death_bell"]
	run._roll_treasure()
	assert_eq(run.treasure[0]["kind"], "souls")


func test_hard_win_opens_a_free_loot_pack_right_away() -> void:
	var run := RunState.new_run(_db, 4)
	run.choose_enemy(2)
	run.apply_battle_result({"victory": true, "gold_after": run.gold})
	assert_eq(run.stage, RunState.Stage.REWARD)
	assert_false(run.open_pack.is_empty(), "the loot pack is open on the reward screen")
	assert_true(run.open_pack["pack"].get("loot", false))
	assert_has(RunState.LOOT_PACK_TYPES, run.open_pack["pack"]["type"])
	assert_false(run.next_shop.has("loot_pack"))


func test_shop_never_rolls_relic_packs() -> void:
	var stream := RandomNumberGenerator.new()
	stream.seed = 9
	for i in 300:
		assert_ne(Items.roll_pack(_db, stream)["type"], "relic")


func test_treasure_survives_saving() -> void:
	var run := _planning_run()
	run.treasure = [{"kind": "gold", "amount": 12}]
	var loaded := RunState.from_dict(_db, str_to_var(var_to_str(run.to_dict())))
	assert_eq(loaded.treasure, run.treasure)


# --- New enemies -----------------------------------------------------------------

func _enemy(id: String, level := 1) -> Dictionary:
	return {"def": _db.enemies[id], "level": level}


func _events_of(result: Dictionary, kind: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == kind)


func test_elites_only_from_act_two() -> void:
	var act1: Array = _db.regular_enemies(1).map(func(e: Dictionary) -> String: return e["id"])
	assert_does_not_have(act1, "salt_golem")
	assert_has(act1, "curse_weaver")
	assert_has(_db.regular_enemies(2).map(func(e: Dictionary) -> String: return e["id"]), "clockwork_warden")
	for seed_value in 20:
		var rng := RngStreams.new(seed_value).stream("enemy_gen")
		for option in EnemyGenerator.options(_db, "coins", 1, 1, rng):
			for unit in option["team"]:
				assert_lt(int(_db.enemies[unit["def_id"]].get("min_act", 1)), 2, "no elite in act 1")


func test_salt_golem_ignores_burn() -> void:
	var spark := {"def": _db.figures["spark_bearer"], "level": 3, "bonus_health": 30}
	var result := BattleSimulator.simulate([spark], [_enemy("salt_golem")])
	var burns := _events_of(result, "damage").filter(func(e: Dictionary) -> bool: return e["source"] == "burn")
	assert_eq(burns.size(), 0)


func test_ban_prior_blocks_player_healing() -> void:
	var front := {"def": _db.figures["coin_squire"], "level": 1, "bonus_health": 20}
	var server := {"def": _db.figures["altar_server"], "level": 3}
	var blocked := BattleSimulator.simulate([front, server], [_enemy("vault_warden"), _enemy("ban_prior")])
	assert_eq(_events_of(blocked, "heal").filter(func(e: Dictionary) -> bool: return e["uid"] <= 2).size(), 0)


func test_shield_breaker_shatters_shields() -> void:
	var squire := {"def": _db.figures["coin_squire"], "level": 3}
	var result := BattleSimulator.simulate([squire], [_enemy("shield_breaker")])
	var first_clash: int = result["events"].find(result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "clash")[0])
	var shielded := false
	for i in first_clash:
		var e: Dictionary = result["events"][i]
		if e["type"] == "update" and e["unit"]["uid"] == 1:
			shielded = int(e["unit"]["statuses"].get("shield", 0)) > 0
	assert_false(shielded, "no shield left before the first clash")


func test_wound_sealer_and_clockwork() -> void:
	var blade := {"def": _db.figures["blade_apprentice"], "level": 3, "bonus_health": 40}
	var result := BattleSimulator.simulate([blade], [_enemy("wound_sealer")])
	var cleaned := _events_of(result, "trigger").filter(func(e: Dictionary) -> bool: return e["effect"] == "cleanse_bleed")
	assert_gt(cleaned.size(), 0)
	var tank := {"def": HELPER_DEF, "level": 1}
	var clock := BattleSimulator.simulate([tank], [_enemy("clockwork_warden")])
	var top := 0
	for e in clock["events"]:
		if e["type"] == "update" and e["unit"]["side"] == 1:
			top = maxi(top, int(e["unit"]["attack"]))
	assert_eq(top, 10, "4 attack + 2 per turn, at most +6 at level 1")


const HELPER_DEF := {"id": "wall", "attack": 0, "health": 200}


# --- Negative events ---------------------------------------------------------------

func _event_run(id: String) -> RunState:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("the_judge"), _fig("blade_apprentice")]
	run.gold = 20
	run.start_event(id)
	return run


func test_negative_events_cannot_be_left_for_free() -> void:
	for id in RunState.NEGATIVE_EVENTS:
		var run := _event_run(id)
		assert_ne(run.event_option_block("leave"), "", "%s needs a choice" % id)


func test_tax_raid_takes_thirty_percent() -> void:
	var run := _event_run("tax_raid")
	assert_true(run.resolve_event("pay_tax"))
	assert_eq(run.gold, 14)
	assert_false(run.event["team"].is_empty())


func test_plague_makes_one_figure_sick_until_the_act_ends() -> void:
	var run := _event_run("plague")
	assert_true(run.resolve_event("plague_accept"))
	var sick: Array = run.row.filter(func(f: Variant) -> bool: return f != null and f.has("sick_act"))
	assert_eq(sick.size(), 1)
	var entry: Dictionary = run.player_battle_team().filter(func(e: Dictionary) -> bool: return e["figure"] == sick[0])[0]
	assert_eq(entry["bonus_health"], -RunState.PLAGUE_HEALTH + (2 if "cups" in entry["suits"] else 0))
	run.act += 1
	var later: Dictionary = run.player_battle_team().filter(func(e: Dictionary) -> bool: return e["figure"] == sick[0])[0]
	assert_false(later["sources"].has("plague"), "healthy again in the next act")


func test_curse_fog_curses_the_next_battle_only() -> void:
	var run := _event_run("curse_fog")
	assert_true(run.resolve_event("fog_accept"))
	assert_has(run.player_battle_team()[0]["sources"], "curse_fog")
	run.event = {}
	run.stage = RunState.Stage.PLANNING
	run.apply_battle_result({"victory": true, "gold_after": run.gold})
	assert_false(run.flags.has("curse_fog"))


func test_ambush_flee_loses_the_rearmost_figure_and_lost_fight_the_front() -> void:
	var run := _event_run("ambush")
	assert_true(run.resolve_event("flee"))
	assert_null(run.row[2])
	var fight := _event_run("ambush")
	fight.apply_duel_result({"victory": false, "gold_after": fight.gold})
	assert_null(fight.row[0])
	assert_eq(fight.event["result"], "ambush_lost")


func test_negative_events_are_rare_and_never_before_a_boss() -> void:
	var hits := 0
	for seed_value in 300:
		var run := RunState.new_run(_db, seed_value)
		run.fight = 1
		if run._roll_negative_event(_db.items["events"]):
			hits += 1
		var boss_run := RunState.new_run(_db, seed_value)
		boss_run.fight = 2
		assert_false(boss_run._roll_negative_event(_db.items["events"]))
	assert_between(hits, 20, 65, "about 13 % per chance")


func test_candle_bearer_never_heals_itself() -> void:
	# Alone in front it has nobody to heal; behind a wounded ally it heals that ally.
	var alone := BattleSimulator.simulate([{"def": _db.figures["blade_apprentice"], "level": 1}], [_enemy("candle_bearer")])
	assert_eq(_events_of(alone, "heal").size(), 0)
	var guarded := BattleSimulator.simulate([{"def": _db.figures["blade_apprentice"], "level": 1}],
		[_enemy("vault_warden"), _enemy("candle_bearer")])
	var heals := _events_of(guarded, "heal")
	for e in heals:
		assert_ne(e["uid"], 3, "the candle bearer (uid 3) is never healed by itself")
