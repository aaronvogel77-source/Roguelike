extends GutTest
## Player reports v0.36.0: "Henkerfähigkeit hat nicht funktioniert" and
## "Klingenlehrling macht noch immer 1 Blutung auf alle Gegner".

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _unit(attack: int, health: int, ability: Variant = null) -> Dictionary:
	var definition := {"id": "u", "attack": attack, "health": health}
	if ability != null:
		definition["ability"] = ability
	return definition


func _fig(id: String, level := 1) -> Dictionary:
	return {"def": _db.figures[id], "level": level}


func _run_fig(def_id: String, uid: int) -> Dictionary:
	return {"uid": uid, "def_id": def_id, "xp": 0}


func _events(result: Dictionary, type: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == type)


func _executes(result: Dictionary) -> Array:
	return _events(result, "damage").filter(func(e: Dictionary) -> bool: return e["source"] == "execute")


## Highest bleed of a unit while the front enemy (the only attacked one) lives.
func _max_bleed(result: Dictionary, uid: int, front_uid := 2) -> int:
	var most := 0
	for e in result["events"]:
		if e["type"] == "removed" and e["uid"] == front_uid:
			break
		if e["type"] == "update" and e["unit"]["uid"] == uid:
			most = maxi(most, int(e["unit"]["statuses"].get("bleed", 0)))
	return most


# --- Henker: the threshold is checked AFTER the hit ----------------------------------

func test_executioner_executes_when_the_hit_leaves_at_most_v_health() -> void:
	# 4 attack into 0/8: 4 health left > 3 -> lives; 0/7: 3 left -> executed.
	var survives := BattleSimulator.simulate([_fig("executioner")], [_unit(0, 8)])
	assert_true(_executes(survives).is_empty() or survives["turns"] > 1)
	var executed := BattleSimulator.simulate([_fig("executioner")], [_unit(0, 7)])
	assert_eq(_executes(executed).size(), 1)
	assert_eq(executed["turns"], 1)


func test_executioner_threshold_grows_with_level() -> void:
	# Level 3: 6 attack, threshold 5 -> a 0/11 target (5 left) dies in turn 1.
	var result := BattleSimulator.simulate([_fig("executioner", 3)], [_unit(0, 11)])
	assert_eq(_executes(result).size(), 1)
	assert_eq(result["turns"], 1)


func test_executioner_executes_through_shields() -> void:
	# Hit fully absorbed by 10 shield; 2 health <= 3 -> executed anyway, shield included.
	var shielded := _unit(0, 2, {"trigger": "battle_start", "target": "self", "effect": "gain_shield", "values": [10, 10, 10]})
	var result := BattleSimulator.simulate([_fig("executioner")], [shielded])
	assert_eq(_executes(result).size(), 1)
	assert_eq(result["outcome"], BattleSimulator.Outcome.WIN)
	assert_eq(result["turns"], 1)


func test_executioner_still_executes_when_it_falls_in_the_same_exchange() -> void:
	# Executioner 4/3 meets a 9/7: both strike, the executioner dies, but its hit
	# left 3 health -> the target is executed too (draw = victory).
	var result := BattleSimulator.simulate([_fig("executioner")], [_unit(9, 7)])
	assert_eq(_executes(result).size(), 1)
	assert_eq(result["turns"], 1)
	assert_true(result["victory"])


func test_fused_executioner_keeps_executing() -> void:
	var run := RunState.new_run(_db, 7)
	run.choose_enemy(0)
	run.row = [_run_fig("blade_apprentice", 1), _run_fig("executioner", 2), null]
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_true(run.fuse(0, 1))
	# Fused 5/4: a 0/8 target is left at 3 -> executed.
	var result := BattleSimulator.simulate(run.player_battle_team(), [_unit(0, 8)])
	assert_eq(_executes(result).size(), 1)


# --- Klingenlehrling: bleed only on the attacked enemy -----------------------------

func test_blade_apprentice_bleeds_only_its_attack_target() -> void:
	var result := BattleSimulator.simulate([_fig("blade_apprentice")], [_unit(0, 30), _unit(0, 30), _unit(0, 30)])
	assert_gt(_max_bleed(result, 2), 0, "the front enemy bleeds")
	assert_eq(_max_bleed(result, 3), 0, "the second enemy does not")
	assert_eq(_max_bleed(result, 4), 0, "the third enemy does not")


func test_a_fused_sword_figure_counts_as_one_sword_figure() -> void:
	# Klingenlehrling + Henker is ONE figure: no swords suit bonus (needs 2 figures).
	var run := RunState.new_run(_db, 7)
	run.choose_enemy(0)
	run.row = [_run_fig("blade_apprentice", 1), _run_fig("executioner", 2), null]
	run.fusion_offer = {"source": "boss", "left": 1, "total": 1}
	assert_true(run.fuse(0, 1))
	assert_eq(run.suit_count("swords"), 1)
	var team := run.player_battle_team()
	assert_eq(TeamBuilder.suit_counts(team)["swords"], 1, "same count as the planning screen")
	var bonus: Array = team[0]["abilities"].filter(func(a: Dictionary) -> bool: return a.get("suit_bonus", false))
	assert_eq(bonus.size(), 0)
	var result := BattleSimulator.simulate(team, [_unit(0, 30), _unit(0, 30), _unit(0, 30)])
	assert_eq(_max_bleed(result, 3), 0, "no bleed on enemies that were never attacked")
	assert_eq(_max_bleed(result, 4), 0)


func test_two_separate_sword_figures_still_get_the_suit_bonus() -> void:
	var run := RunState.new_run(_db, 7)
	run.choose_enemy(0)
	run.row = [_run_fig("blade_apprentice", 1), _run_fig("executioner", 2), null]
	var team := run.player_battle_team()
	assert_eq(TeamBuilder.suit_counts(team)["swords"], 2)
	var result := BattleSimulator.simulate(team, [_unit(0, 30), _unit(0, 30), _unit(0, 30)])
	assert_eq(_max_bleed(result, 5, 3), 1, "rule SUITBONUS_SWORDS: 1 bleed on every enemy per 2 sword figures")
