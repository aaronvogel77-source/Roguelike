extends SceneTree
## Headless balancing tool. Runs many random placeholder battles and prints
## the win rate per figure.
## Usage: godot --headless -s tools/simulate.gd -- [battles] [seed]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var battles := int(args[0]) if args.size() > 0 else 2000
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var db := ContentDb.load_default()
	var rng := RngStreams.new(seed_value).stream("simulation")

	var picks: Dictionary = {}
	var wins: Dictionary = {}
	var total_wins := 0
	var total_turns := 0
	for i in battles:
		var size := rng.randi_range(3, 6)
		var player := DebugTeams.random_player_team(db, rng, size)
		var enemy := DebugTeams.random_enemy_team(db, rng, size)
		var result := BattleSimulator.simulate(player, enemy)
		total_turns += result["turns"]
		if result["victory"]:
			total_wins += 1
		for figure in player:
			picks[figure["id"]] = picks.get(figure["id"], 0) + 1
			if result["victory"]:
				wins[figure["id"]] = wins.get(figure["id"], 0) + 1

	print("Battles: %d  seed: %d" % [battles, seed_value])
	print("Player win rate: %.1f %%   avg turns: %.1f" % [100.0 * total_wins / battles, float(total_turns) / battles])
	var ids := picks.keys()
	ids.sort_custom(func(a, b): return float(wins.get(a, 0)) / picks[a] > float(wins.get(b, 0)) / picks[b])
	for id in ids:
		print("  %-20s %5.1f %%  (%d teams)" % [id, 100.0 * wins.get(id, 0) / picks[id], picks[id]])
	quit()
