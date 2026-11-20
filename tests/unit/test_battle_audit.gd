extends GutTest
## Regressions from the battle logic audit (v0.39.0 report: burn effects
## around deaths, event flow for the battle view).

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _unit(attack: int, health: int, ability: Variant = null, id: String = "u") -> Dictionary:
	var definition := {"id": id, "attack": attack, "health": health}
	if ability != null:
		definition["ability"] = ability
	return definition


func _ab(trigger: String, target: String, effect: String, value: Variant) -> Dictionary:
	return {"trigger": trigger, "target": target, "effect": effect, "values": [value, value, value]}


func _fig(id: String, level := 1) -> Dictionary:
	return {"def": _db.figures[id], "level": level}


func _enemy(id: String, level := 1) -> Dictionary:
	return {"def": _db.enemies[id], "level": level}


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


## Highest burn a unit ever showed in an update.
func _max_burn(result: Dictionary, uid: int) -> int:
	var most := 0
	for e in _events(result, "update"):
		if e["unit"]["uid"] == uid:
			most = maxi(most, int(e["unit"]["statuses"].get("burn", 0)))
	return most


func _index_of(result: Dictionary, check: Callable) -> int:
	var events: Array = result["events"]
	for i in events.size():
		if check.call(events[i]):
			return i
	return -1


# --- Burn around deaths ------------------------------------------------------------

func test_unit_killed_by_its_burn_tick_passes_the_whole_stack_on() -> void:
	# Burn 1 kills the 1-health enemy at the turn start. It dies burning, so the
	# Ash King passes burn 1 on (before: the tick removed the last stack first
	# and nothing jumped).
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", 1), "burning")
	var king := _unit(0, 50, _ab("on_enemy_death", "self", "spread_burn_and_mult", 1.1), "king")
	var result := BattleSimulator.simulate([king], [burning, _unit(0, 50, null, "next")])
	assert_eq(_max_burn(result, 3), 1, "burn 1 jumped to the next enemy")
	var ticks := _events(result, "burn_tick").filter(func(e: Dictionary) -> bool: return e["uid"] == 2)
	assert_eq(ticks, [], "no burn countdown on a unit the fire has killed")


func test_burn_moves_on_once_with_ash_king_and_ash_pact() -> void:
	# Both the Ash King and the ash pact pass the burn on; it must jump once
	# (3), not be copied by each of them (6).
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", 3), "burning")
	var result := BattleSimulator.simulate([_unit(0, 50, _ab("on_enemy_death", "self", "spread_burn_and_mult", 1.1), "king")],
		[burning, _unit(0, 50, null, "next")], 0, {"burn_spread": true})
	assert_eq(_max_burn(result, 3), 3, "the burn moved on exactly once")


func test_ash_pact_alone_still_spreads_the_burn() -> void:
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", 2), "burning")
	var result := BattleSimulator.simulate([_unit(0, 50)], [burning, _unit(0, 50, null, "next")], 0, {"burn_spread": true})
	assert_eq(_max_burn(result, 3), 2)


func test_burn_jump_is_a_visible_trigger_from_the_dying_unit() -> void:
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", 2), "burning")
	var result := BattleSimulator.simulate([_fig("ash_king")], [burning, _unit(0, 50, null, "next")])
	var jump := _index_of(result, func(e: Dictionary) -> bool:
		return e["type"] == "trigger" and e["uid"] == 2 and e["targets"] == [3])
	assert_gt(jump, -1, "the jump is shown from the dying enemy to the next one")
	assert_true(result["events"][jump].get("passive", false), "a burn jump is no special attack of the dying unit")
	var dying := _index_of(result, func(e: Dictionary) -> bool: return e["type"] == "dying" and e["uid"] == 2)
	var removed := _index_of(result, func(e: Dictionary) -> bool: return e["type"] == "removed" and e["uid"] == 2)
	var burn_shown := _index_of(result, func(e: Dictionary) -> bool:
		return e["type"] == "update" and e["unit"]["uid"] == 3 and e["unit"]["statuses"].get("burn", 0) > 0)
	assert_true(dying < jump and jump < burn_shown and burn_shown < removed, "dying → jump → new burn → removed")
	var cleared := _index_of(result, func(e: Dictionary) -> bool:
		return e["type"] == "update" and e["unit"]["uid"] == 2 and e["unit"]["health"] <= 0 and not e["unit"]["statuses"].has("burn"))
	assert_true(cleared > jump and cleared < removed, "the dying unit's burn icon goes away with the jump")


func test_burn_does_not_jump_onto_a_burn_immune_unit() -> void:
	var burning := _unit(0, 1, _ab("battle_start", "self", "apply_burn", 2), "burning")
	var result := BattleSimulator.simulate([_fig("ash_king")], [burning, _enemy("fire_eater")])
	assert_eq(_max_burn(result, 3), 0)
	assert_false(_events(result, "trigger").any(func(e: Dictionary) -> bool: return e["uid"] == 2 and e["targets"] == [3]),
		"no jump shown that had no effect")


func test_ash_husk_burns_the_next_figure_when_the_front_falls_with_it() -> void:
	var result := BattleSimulator.simulate([_unit(3, 2, null, "front"), _unit(1, 10, null, "back")], [_enemy("ash_husk")])
	assert_eq(_max_burn(result, 2), 2, "the husk's death burn goes to the figure that moves up")
	assert_eq(_max_burn(result, 1), 0, "not onto the fallen front figure")


func test_ash_husk_killed_by_burn_still_burns_on_death() -> void:
	var burner := _unit(0, 10, _ab("battle_start", "front_enemy", "apply_burn", 5), "burner")
	var result := BattleSimulator.simulate([burner], [_enemy("ash_husk"), _unit(0, 5, null, "e2")])
	var death_burn := _index_of(result, func(e: Dictionary) -> bool:
		return e["type"] == "trigger" and e["uid"] == 2 and e["effect"] == "apply_burn")
	var dying := _index_of(result, func(e: Dictionary) -> bool: return e["type"] == "dying" and e["uid"] == 2)
	assert_gt(dying, -1)
	assert_gt(death_burn, dying, "the death trigger fires after the burn kill")
	assert_eq(_max_burn(result, 1), 2)


# --- Boss rule and auras ------------------------------------------------------------

func test_burning_floor_is_passive_and_skips_burn_immune_units() -> void:
	var result := BattleSimulator.simulate([_unit(1, 30)], [_enemy("fire_eater")], 0, {"burning_floor": true})
	var floor_triggers := _events(result, "trigger")
	assert_false(floor_triggers.any(func(e: Dictionary) -> bool: return e["uid"] == 2), "nothing shown on the immune enemy")
	assert_false(floor_triggers.is_empty(), "the player's front figure still burns")
	assert_true(floor_triggers.all(func(e: Dictionary) -> bool: return e.get("passive", false)),
		"the floor is not the burning figure's special attack")


func test_heal_at_full_health_shows_no_trigger() -> void:
	# Nobody gets hurt before the decay (turn 15) starts.
	var result := BattleSimulator.simulate([_unit(0, 10, null, "front"), _fig("altar_server")], [_unit(0, 10)])
	var before_decay: Array = []
	for e in result["events"]:
		if e["type"] == "turn" and e["turn"] >= BattleSimulator.DECAY_START_TURN:
			break
		before_decay.append(e)
	assert_eq(before_decay.filter(func(e: Dictionary) -> bool: return e["type"] == "trigger" and e["effect"] == "heal"), [],
		"a heal that heals nothing is not shown")


func test_heal_on_a_hurt_ally_still_triggers() -> void:
	var result := BattleSimulator.simulate([_unit(0, 10, null, "front"), _fig("altar_server")], [_unit(2, 30)])
	var heal := _index_of(result, func(e: Dictionary) -> bool: return e["type"] == "trigger" and e["effect"] == "heal")
	assert_gt(heal, -1)
	assert_eq(result["events"][heal + 1]["type"], "heal", "trigger first, then the heal")


func test_ember_heal_shows_its_source_only_when_it_heals() -> void:
	# The burning enemy hits for 2 every turn; each of its burn ticks heals the
	# ember figure by 1 - shown as an ember_heal trigger right before the heal.
	var ember := _unit(0, 20, _ab("aura", "self", "ember_heal", 1), "ember")
	var enemy := _unit(2, 50, _ab("battle_start", "self", "apply_burn", 5), "burning")
	var result := BattleSimulator.simulate([ember], [enemy])
	var triggers := _events(result, "trigger").filter(func(e: Dictionary) -> bool: return e["effect"] == "ember_heal")
	var heals := _events(result, "heal").filter(func(e: Dictionary) -> bool: return e["uid"] == 1)
	assert_gt(heals.size(), 0)
	assert_eq(triggers.size(), heals.size(), "one trigger per heal, none at full health (turn 1)")


# --- Gold and kills -------------------------------------------------------------------

func test_gold_factor_applies_once_after_a_gold_change() -> void:
	var battle := BattleSimulator.new()
	battle._run([_unit(0, 10)], [_unit(0, 10)], 10, {"gold_factor": 2})
	assert_eq(battle.gold, 20)
	battle.change_gold(1)
	assert_eq(battle.gold, 22, "11 real gold × 2, not × 4")


func test_revived_enemy_forgets_its_old_killer() -> void:
	# Turn 1: the reaper kills the front enemy (harvest), the priestess revives it.
	# Turn 2: the thrower's damage kills it - not the reaper's kill, no second harvest.
	var reaper := _unit(4, 50, _ab("on_enemy_death", "self", "harvest_soul", 0.15), "reaper")
	var thrower := _unit(0, 50, _ab("turn_start", "front_enemy", "damage", 1), "thrower")
	var result := BattleSimulator.simulate([reaper, thrower], [_unit(0, 5, null, "victim"), _enemy("ash_priestess")])
	assert_eq(_events(result, "revive").size(), 1, "the victim came back once")
	var deaths: Array = []
	for i in result["events"].size():
		if result["events"][i]["type"] == "dying" and result["events"][i]["uid"] == 3:
			deaths.append(i)
	assert_eq(deaths.size(), 2, "the victim died twice")
	var harvested_second := false
	for i in range(deaths[1], result["events"].size()):
		var e: Dictionary = result["events"][i]
		if e["type"] == "removed" and e["uid"] == 3:
			break
		harvested_second = harvested_second or e["type"] == "harvest"
	assert_false(harvested_second, "the thrower's kill is not the reaper's")


# --- Event flow for the battle view ----------------------------------------------------

func test_events_match_the_real_state_in_random_battles() -> void:
	# The view only knows the events: every clash is between the current front
	# units, nothing refers to a removed unit and the last update of every
	# survivor equals its real final state.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var problems: Array = []
	var figure_ids: Array = _db.figures.keys()
	figure_ids.sort()
	var enemy_ids: Array = _db.enemies.keys()
	enemy_ids.sort()
	for n in 300:
		var team: Array = []
		for i in rng.randi_range(1, 6):
			team.append({"def": _db.figures[figure_ids[rng.randi_range(0, figure_ids.size() - 1)]], "level": rng.randi_range(1, 3)})
		var enemies: Array = []
		for i in rng.randi_range(1, 6):
			enemies.append({"def": _db.enemies[enemy_ids[rng.randi_range(0, enemy_ids.size() - 1)]], "level": rng.randi_range(1, 3)})
		var options := {"burning_floor": rng.randf() < 0.3, "burn_spread": rng.randf() < 0.3, "team_revives": rng.randi_range(0, 1)}
		var battle := BattleSimulator.new()
		var result := battle._run(team, enemies, rng.randi_range(0, 40), options)
		var order := [[], []]
		var last := {}
		var removed := {}
		for e in result["events"]:
			match e["type"]:
				"start":
					order = [e["player"].map(func(u: Dictionary) -> int: return u["uid"]),
						e["enemy"].map(func(u: Dictionary) -> int: return u["uid"])]
				"clash":
					if order[0][0] != e["player_uid"] or order[1][0] != e["enemy_uid"]:
						problems.append("battle %d: clash not between the front units" % n)
				"update":
					last[e["unit"]["uid"]] = e["unit"]
					if removed.has(e["unit"]["uid"]):
						problems.append("battle %d: update for a removed unit" % n)
				"trigger":
					if removed.has(e["uid"]) or e["targets"].any(func(t: int) -> bool: return removed.has(t)):
						problems.append("battle %d: %s involves a removed unit" % [n, e["effect"]])
				"damage", "heal", "burn_tick", "shielded", "dying":
					if removed.has(e["uid"]):
						problems.append("battle %d: %s on a removed unit" % [n, e["type"]])
				"removed":
					removed[e["uid"]] = true
					order[e["side"]].erase(e["uid"])
		for side in [BattleSimulator.PLAYER, BattleSimulator.ENEMY]:
			for unit: BattleUnit in battle.rows[side]:
				if not last.has(unit.uid):
					continue
				var real := unit.snapshot()
				for key in ["health", "max_health", "effective_attack", "statuses"]:
					if str(last[unit.uid][key]) != str(real[key]):
						problems.append("battle %d: %s shows stale %s" % [n, unit.def_id, key])
		if problems.size() > 10:
			break
	assert_eq(problems, [], "\n".join(problems.slice(0, 10)))
