extends GutTest
## Every ability building block and the status rules of M2.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _unit(attack: int, health: int, ability: Variant = null, id: String = "u") -> Dictionary:
	var definition := {"id": id, "attack": attack, "health": health}
	if ability != null:
		definition["ability"] = ability
	return definition


func _ab(trigger: String, target: String, effect: String, values: Array, late := false) -> Dictionary:
	return {"trigger": trigger, "target": target, "effect": effect, "values": values, "late": late}


func _fig(id: String, level := 1) -> Dictionary:
	return {"def": _db.figures[id], "level": level}


func _enemy(id: String, level := 1) -> Dictionary:
	return {"def": _db.enemies[id], "level": level}


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _ever(result: Dictionary, uid: int, check: Callable) -> bool:
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == uid and check.call(e["unit"]):
			return true
	return false


func _final(result: Dictionary, uid: int) -> Dictionary:
	var last := {}
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == uid:
			last = e["unit"]
	return last


# --- Formula and statuses ---------------------------------------------------------

func test_damage_formula_is_attack_minus_curse_times_multipliers() -> void:
	var unit := BattleUnit.from_definition(_unit(5, 10), 0, 1)
	unit.multipliers.append(1.5)
	unit.multipliers.append(2.0)
	unit.add_status(BattleUnit.STATUS_CURSE, 1)
	assert_eq(unit.effective_attack(), 12, "(5 - 1) × 1.5 × 2 = 12")


func test_levels_add_plus_one_plus_one() -> void:
	var unit := BattleUnit.from_definition(_unit(2, 3), 0, 1, 3)
	assert_eq(unit.attack, 4)
	assert_eq(unit.health, 5)


func test_shield_absorbs_attack_damage_first() -> void:
	# Coin Squire L1: 1/4 with shield 2. Takes 3 → shield 2 absorbed, 1 to health.
	var result := BattleSimulator.simulate([_fig("coin_squire")], [_unit(3, 1)])
	var shielded := _events(result, "shielded")
	assert_eq(shielded[0]["amount"], 2)
	assert_eq(_events(result, "damage")[1]["amount"], 1)


func test_burn_ticks_at_turn_start_and_decreases() -> void:
	# Spark Bearer applies burn 1 on its attack; the enemy (0/10) burns next turn.
	var result := BattleSimulator.simulate([_fig("spark_bearer")], [_unit(0, 10)])
	var burns := _events(result, "damage").filter(func(e): return e["source"] == "burn")
	assert_gt(burns.size(), 0)
	assert_eq(burns[0]["amount"], 1)


func test_mistress_of_embers_multiplies_burn() -> void:
	# Spark bearer L2 front (burn 2), Mistress L3 behind: floor(2 × 2.5) = 5.
	var result := BattleSimulator.simulate([_fig("spark_bearer", 2), _fig("mistress_of_embers", 3)], [_unit(0, 30)])
	var burns := _events(result, "damage").filter(func(e): return e["source"] == "burn")
	assert_eq(burns[0]["amount"], 5)


func test_attacker_that_falls_still_lands_its_burn() -> void:
	# Spark Bearer (2/2) dies to the 5/9 enemy in the same exchange, its burn still sticks.
	var result := BattleSimulator.simulate([_fig("spark_bearer")], [_unit(5, 9)])
	assert_true(_ever(result, 2, func(u): return u["statuses"].get("burn", 0) == 1))


func test_bleed_ticks_every_turn_and_keeps_its_stacks() -> void:
	# Blade apprentice 2/2 applies bleed 1 per attack: bleed ticks 1, then 2, then 3.
	var result := BattleSimulator.simulate([_fig("blade_apprentice")], [_unit(0, 30)])
	var bleeds := _events(result, "damage").filter(func(e): return e["source"] == "bleed")
	assert_eq(bleeds[0]["amount"], 1)
	assert_eq(bleeds[1]["amount"], 2)
	assert_eq(bleeds[2]["amount"], 3)
	# Attack hits are not increased by bleed.
	var hits := _events(result, "damage").filter(func(e): return e["source"] == "attack")
	assert_eq(hits[1]["amount"], 2)


func test_bleed_hits_units_in_the_back_row_too() -> void:
	var bleeder := _unit(0, 50, _ab("battle_start", "back_enemy", "apply_bleed", [2, 2, 2]))
	var result := BattleSimulator.simulate([_unit(0, 50, null, "front"), _unit(0, 50, null, "back")], [bleeder])
	var bleeds := _events(result, "damage").filter(func(e): return e["source"] == "bleed")
	assert_eq(bleeds[0]["uid"], 2, "the rear unit bleeds")
	assert_eq(bleeds[0]["amount"], 2)


func test_curse_lowers_attack_and_wears_off() -> void:
	var curser := _unit(0, 50, _ab("battle_start", "front_enemy", "apply_curse", [2, 2, 2]))
	var result := BattleSimulator.simulate([_unit(3, 50)], [curser])
	var hits := _events(result, "damage").filter(func(e): return e["source"] == "attack")
	assert_eq(hits[0]["amount"], 1, "3 - 2 curse")
	assert_eq(hits[3]["amount"], 3, "curse gone after 3 turns")


# --- Coins ------------------------------------------------------------------------

func test_gold_armored_gains_shield_per_gold() -> void:
	var result := BattleSimulator.simulate([_fig("gold_armored")], [_unit(0, 1)], 12)
	var shields := _events(result, "update").filter(func(e): return e["unit"]["uid"] == 1)
	assert_eq(shields[0]["unit"]["statuses"].get("shield", 0), 3, "12 gold / 4 = shield 3")
	assert_eq(_final(result, 1)["max_health"], 4, "health unchanged")


func test_king_midas_multiplier_from_gold() -> void:
	var result := BattleSimulator.simulate([_fig("king_midas", 3)], [_unit(0, 100)], 30)
	# L3: 6 attack × (1 + 30/5) = 42.
	var hits := _events(result, "damage").filter(func(e): return e["source"] == "attack")
	assert_eq(hits[0]["amount"], 42)


func test_golden_scales_multiplies_rearmost_ally_when_ally_dies() -> void:
	# Front 0/1 dies; the rearmost figure (a 5/50 behind the scales) gets ×1.5 (scales level 3).
	var result := BattleSimulator.simulate([_unit(0, 1), _fig("golden_scales", 3), _unit(5, 50, null, "back")], [_unit(1, 50)])
	assert_true(_ever(result, 3, func(u): return absf(u["multiplier"] - 1.5) < 0.001), "rearmost figure multiplied")


# --- Wands --------------------------------------------------------------------------

func test_enraged_one_burns_its_attacker() -> void:
	var result := BattleSimulator.simulate([_fig("enraged_one", 2)], [_unit(1, 50)])
	assert_true(_ever(result, 2, func(u): return u["statuses"].get("burn", 0) == 2), "level 2: burn 2 on the attacker")


func test_ash_king_spreads_burn_and_gains_multiplier() -> void:
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", [3, 3, 3]), "burning")
	var result := BattleSimulator.simulate([_fig("ash_king")], [burning, _unit(0, 50, null, "next")])
	assert_true(_ever(result, 3, func(u): return u["statuses"].get("burn", 0) >= 2), "burn jumped to the next enemy")
	assert_true(_ever(result, 1, func(u): return absf(u["multiplier"] - 1.1) < 0.001), "first kill gives ×1.1")


# --- Cups ---------------------------------------------------------------------------

func test_altar_server_heals_ally_in_front() -> void:
	var result := BattleSimulator.simulate([_unit(1, 10), _fig("altar_server")], [_unit(2, 50)])
	var heals := _events(result, "heal")
	assert_gt(heals.size(), 0)
	assert_eq(heals[0]["uid"], 1)


func test_blood_drinker_heals_from_damage_dealt() -> void:
	var result := BattleSimulator.simulate([_fig("blood_drinker", 3)], [_unit(2, 50)])
	var heals := _events(result, "heal")
	assert_gt(heals.size(), 0)
	assert_eq(heals[0]["amount"], 2, "full lifesteal capped at missing health")


func test_chalice_revives_once_and_drowned_king_absorbs_twice() -> void:
	var result := BattleSimulator.simulate(
		[_unit(1, 1, null, "fodder"), _fig("chalice_of_return"), _fig("drowned_king")],
		[_unit(1, 100)])
	assert_eq(_events(result, "revive").size(), 1, "chalice revives only once")
	# The drowned king absorbs both deaths of the fodder (30 % at level 1).
	var absorbs := _events(result, "trigger").filter(func(e): return e["uid"] == 3 and e["effect"] == "absorb")
	assert_gte(absorbs.size(), 2, "the fodder feeds the king twice")


func test_drowned_king_absorbs_a_share_of_attack_and_health() -> void:
	var fodder := _unit(10, 10, null, "fodder")
	var result := BattleSimulator.simulate([fodder, _fig("drowned_king", 2)], [_unit(50, 100)])
	# Level 2 king (5/9) takes 50 %: +5 attack, +5 health.
	assert_true(_ever(result, 2, func(u): return u["attack"] == 10 and u["max_health"] == 14))


# --- Swords -------------------------------------------------------------------------

func test_executioner_kills_low_health_targets() -> void:
	# 4 attack into a 0/7 enemy leaves 3 health -> executed (threshold 3).
	var result := BattleSimulator.simulate([_fig("executioner")], [_unit(0, 7)])
	assert_eq(result["turns"], 1)
	assert_eq(result["outcome"], BattleSimulator.Outcome.WIN)


func test_clear_blade_turns_late_shields_into_bleed() -> void:
	# The vault warden shields itself at battle start; the late clear blade strips it.
	var result := BattleSimulator.simulate([_fig("clear_blade")], [_enemy("vault_warden")])
	var warden := _final(result, 2)
	assert_eq(warden["statuses"].get("shield", 0) <= 1, true)
	var bleed_seen := false
	for e in _events(result, "update"):
		if e["unit"]["uid"] == 2 and e["unit"]["statuses"].get("bleed", 0) == 3:
			bleed_seen = true
	assert_true(bleed_seen, "3 shield × 1 bleed")


func test_judge_detonates_bleed() -> void:
	var bleeder := _unit(0, 100, _ab("battle_start", "self", "apply_bleed", [4, 4, 4]))
	var result := BattleSimulator.simulate([_fig("the_judge")], [bleeder])
	var ability_hits := _events(result, "damage").filter(func(e): return e["source"] == "ability")
	assert_eq(ability_hits[0]["amount"], 8, "bleed 4 × 2")


# --- Enemies ------------------------------------------------------------------------

func test_beggar_ghost_steals_at_most_three_gold() -> void:
	var result := BattleSimulator.simulate([_unit(0, 100)], [_enemy("beggar_ghost")], 10)
	# Our 0-attack unit never hits, so nothing is stolen.
	assert_eq(result["gold_after"], 10)
	var result2 := BattleSimulator.simulate([_unit(1, 100)], [_unit(0, 100, _ab("on_hit", "self", "steal_gold", [1, 1, 1]))], 10)
	assert_eq(result2["gold_after"], 7)


func test_debt_collector_gains_attack_per_ten_gold() -> void:
	var result := BattleSimulator.simulate([_unit(0, 100)], [_enemy("debt_collector", 2)], 35)
	# Level 2: 3 attack + 3 × 2 (35 gold = 3 full tens) = 9.
	assert_eq(_final(result, 2)["attack"], 9)


func test_changer_swaps_front_enemy_stats() -> void:
	var result := BattleSimulator.simulate([_unit(1, 9)], [_enemy("the_changer")])
	assert_eq(_final(result, 1)["attack"], 9)


func test_greedmaw_eats_shield() -> void:
	var result := BattleSimulator.simulate([_fig("coin_squire", 3)], [_enemy("greedmaw")])
	assert_gt(_events(result, "heal").size(), 0)


func test_greedy_dragon_grows_when_player_units_die() -> void:
	var result := BattleSimulator.simulate([_unit(0, 1), _unit(0, 1)], [_enemy("greedy_dragon")])
	assert_eq(_final(result, 3)["attack"], 8)


func test_mirror_coin_copies_and_fires_battle_start_ability() -> void:
	var result := BattleSimulator.simulate([_fig("coin_squire")], [_enemy("mirror_coin")])
	assert_true(_ever(result, 2, func(u): return u["statuses"].get("shield", 0) == 2), "copied shield 2")


func test_all_content_abilities_run_without_errors() -> void:
	var rng := RngStreams.new(5).stream("test")
	for i in 200:
		var player := DebugTeams.random_player_team(_db, rng, rng.randi_range(1, 6))
		var enemy := DebugTeams.random_enemy_team(_db, rng, rng.randi_range(1, 6), 3)
		var result := BattleSimulator.simulate(player, enemy, rng.randi_range(0, 40))
		assert_lt(result["turns"], BattleSimulator.MAX_TURNS)


func test_ash_king_burns_his_target() -> void:
	var result := BattleSimulator.simulate([_fig("ash_king")], [_unit(0, 30)])
	var burns := _events(result, "damage").filter(func(e): return e["source"] == "burn")
	assert_gt(burns.size(), 0, "the ash king sets his target on fire")
	assert_eq(burns[0]["amount"], 3)


func test_ash_king_stops_spreading_burn_once_he_is_dead() -> void:
	# The king burns the front enemy and falls in the same clash; when that
	# enemy later dies, its burn must NOT jump on (his ability ends with him).
	var king: Dictionary = _db.figures["ash_king"].duplicate(true)
	king["health"] = 1
	var filler := _unit(3, 60, null, "filler")
	var front := _unit(10, 20, null, "front")
	var back := _unit(0, 30, null, "back")
	var result := BattleSimulator.simulate([{"def": king, "level": 1}, filler], [front, back])
	var back_uid := -1
	for unit in _events(result, "start")[0]["enemy"]:
		if unit.get("def_id", "") == "back":
			back_uid = unit["uid"]
	assert_ne(back_uid, -1, "the back enemy is in the battle")
	var back_burned := _events(result, "update").any(func(e: Dictionary) -> bool:
		return e["unit"]["uid"] == back_uid and e["unit"]["statuses"].get("burn", 0) > 0)
	assert_false(back_burned, "no burn jumps over after the ash king has died")
