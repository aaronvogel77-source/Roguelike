extends GutTest
## Rules of the M1 battle core: simultaneous front clash, decay, outcomes.


func _unit(id: String, attack: int, health: int) -> Dictionary:
	return {"id": id, "attack": attack, "health": health}


func test_front_units_hit_each_other_simultaneously() -> void:
	# 3/3 vs 3/3: both die in the same clash -> draw.
	var result := BattleSimulator.simulate([_unit("a", 3, 3)], [_unit("b", 3, 3)])
	assert_eq(result["outcome"], BattleSimulator.Outcome.DRAW)
	assert_eq(result["turns"], 1)


func test_draw_counts_as_victory() -> void:
	var result := BattleSimulator.simulate([_unit("a", 3, 3)], [_unit("b", 3, 3)])
	assert_true(result["victory"])


func test_stronger_front_wins_and_next_unit_moves_up() -> void:
	# Player 5/10 beats two 2/2 enemies one after another.
	var result := BattleSimulator.simulate([_unit("a", 5, 10)], [_unit("b", 2, 2), _unit("c", 2, 2)])
	assert_eq(result["outcome"], BattleSimulator.Outcome.WIN)
	assert_eq(result["turns"], 2)
	var deaths: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "death")
	assert_eq(deaths.size(), 2)


func test_loss_when_player_team_dies() -> void:
	var result := BattleSimulator.simulate([_unit("a", 1, 1)], [_unit("b", 5, 5)])
	assert_eq(result["outcome"], BattleSimulator.Outcome.LOSS)
	assert_false(result["victory"])


func test_back_units_do_not_attack() -> void:
	# Only the front unit deals damage: 1/50 front + 100/1 back vs 1/3.
	# The 100-attack unit never reaches the front because the enemy dies first.
	var result := BattleSimulator.simulate([_unit("a", 1, 50), _unit("big", 100, 1)], [_unit("b", 1, 3)])
	assert_eq(result["turns"], 3)
	assert_eq(result["outcome"], BattleSimulator.Outcome.WIN)


func test_decay_damage_doubles_from_turn_15() -> void:
	assert_eq(BattleSimulator.decay_damage(14), 0)
	assert_eq(BattleSimulator.decay_damage(15), 1)
	assert_eq(BattleSimulator.decay_damage(16), 2)
	assert_eq(BattleSimulator.decay_damage(18), 8)


func test_decay_ends_stalemates() -> void:
	# Two 0-attack units would fight forever without decay.
	var result := BattleSimulator.simulate([_unit("a", 0, 100)], [_unit("b", 0, 100)])
	assert_lt(result["turns"], BattleSimulator.MAX_TURNS)
	assert_gte(result["turns"], BattleSimulator.DECAY_START_TURN)
	assert_eq(result["outcome"], BattleSimulator.Outcome.DRAW)


func test_empty_enemy_team_is_instant_win() -> void:
	var result := BattleSimulator.simulate([_unit("a", 1, 1)], [])
	assert_eq(result["outcome"], BattleSimulator.Outcome.WIN)
	assert_eq(result["turns"], 0)


func test_simulation_is_deterministic() -> void:
	var player := [_unit("a", 3, 7), _unit("b", 2, 4)]
	var enemy := [_unit("c", 4, 5), _unit("d", 1, 9)]
	var first := BattleSimulator.simulate(player, enemy)
	var second := BattleSimulator.simulate(player, enemy)
	assert_eq(JSON.stringify(first["events"]), JSON.stringify(second["events"]))


func test_input_definitions_are_not_modified() -> void:
	var player := [_unit("a", 3, 3)]
	BattleSimulator.simulate(player, [_unit("b", 2, 2)])
	assert_eq(player[0]["health"], 3)
