extends SceneTree
## Plays whole runs with a simple greedy bot to sanity-check difficulty.
## Usage: godot --headless -s tools/simulate_runs.gd -- [runs] [difficulty 0-2]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 300
	var difficulty := int(args[1]) if args.size() > 1 else 1
	var db := ContentDb.load_default()
	var reached: Dictionary = {}
	var wins := 0
	for seed_value in range(1, runs + 1):
		var run := RunState.new_run(db, seed_value)
		while run.stage != RunState.Stage.WON and run.stage != RunState.Stage.LOST:
			if run.stage == RunState.Stage.ENEMY_CHOICE or run.stage == RunState.Stage.PLANNING:
				if run.stage == RunState.Stage.ENEMY_CHOICE:
					run.choose_enemy(mini(difficulty, run.enemy_options.size() - 1))
				_shop(run)
				var result := BattleSimulator.simulate(run.player_battle_team(), run.enemy_battle_team(), run.gold, run.battle_options())
				run.apply_battle_result(result)
			elif run.stage == RunState.Stage.REWARD:
				if not run.take_reward(0):
					run.skip_reward()
			elif run.stage == RunState.Stage.EVENT:
				run.resolve_event("leave")
		var key := "act %d fight %d" % [run.act, run.fight + 1]
		if run.stage == RunState.Stage.WON:
			wins += 1
			key = "WON"
		reached[key] = reached.get(key, 0) + 1
	print("runs %d  difficulty %d  win rate %.1f %%" % [runs, difficulty, 100.0 * wins / runs])
	var keys := reached.keys()
	keys.sort()
	for k in keys:
		print("  %-16s %d" % [k, reached[k]])
	quit()


## Greedy bot: buy into free slots or merges while gold allows; buy a slot at 12+ gold.
func _shop(run: RunState) -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		var bought := false
		for i in run.shop.size():
			if run.shop[i] == "" or run.gold < run.price_of(run.shop[i]):
				continue
			var target := run.reward_target(run.shop[i])
			if target >= 0 and run.buy(i, target):
				bought = true
		if not bought:
			if run.gold >= 6 and run.reroll():
				continue
			break
