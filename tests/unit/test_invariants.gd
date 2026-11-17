extends GutTest
## Rules every battle must follow, checked over many random battles with all
## figures (any level), enemies (elites and bosses too), relics, pacts and
## run modifiers. Catches timing mistakes like a heal that silently vanishes
## or a unit acting after it was removed.

const BATTLES := 400

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _random_run(rng: RandomNumberGenerator) -> RunState:
	var run := RunState.new_run(_db, rng.randi_range(1, 100000))
	run.choose_enemy(rng.randi_range(0, run.enemy_options.size() - 1))
	run.act = rng.randi_range(1, 2)
	var ids: Array = _db.figures.keys()
	ids.sort()
	var size := rng.randi_range(1, 6)
	run.row.resize(size)
	for i in size:
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		run.row[i] = {"uid": i + 1, "def_id": id, "xp": [0, 9, 18][rng.randi_range(0, 2)]}
	var relics: Array = _db.items["relics"].map(func(r: Dictionary) -> String: return r["id"])
	for i in rng.randi_range(0, 3):
		var relic: String = relics[rng.randi_range(0, relics.size() - 1)]
		if not relic in run.relics:
			run.relics.append(relic)
	var pacts: Array = _db.items["pacts"]
	for i in rng.randi_range(0, 2):
		var pact: String = pacts[rng.randi_range(0, pacts.size() - 1)]
		if not pact in run.pacts:
			run.pacts.append(pact)
	run.gold = rng.randi_range(0, 40)
	if rng.randf() < 0.15:
		run.flags["curse_fog"] = true
	return run


func _random_enemies(rng: RandomNumberGenerator) -> Array:
	var ids: Array = _db.enemies.keys()
	ids.sort()
	var team: Array = []
	for i in rng.randi_range(1, 6):
		team.append({"def": _db.enemies[ids[rng.randi_range(0, ids.size() - 1)]], "level": rng.randi_range(1, 3)})
	return team


func test_random_battles_follow_the_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var problems: Array = []
	for n in BATTLES:
		var run := _random_run(rng)
		var team := run.player_battle_team()
		var enemies := _random_enemies(rng)
		var result := BattleSimulator.simulate(team, enemies, run.gold, run.battle_options())
		var removed := {}
		var alive := {}  # uid -> health from the latest snapshot
		var ended := false
		for e in result["events"]:
			if ended:
				problems.append("battle %d: event after the end: %s" % [n, e["type"]])
				break
			match e["type"]:
				"start":
					for u in e["player"] + e["enemy"]:
						alive[u["uid"]] = int(u["health"])
				"update":
					var u: Dictionary = e["unit"]
					if removed.has(u["uid"]) and int(u["health"]) > 0 and not removed[u["uid"]]:
						problems.append("battle %d: removed unit %s changes again" % [n, u["def_id"]])
					if int(u["health"]) > int(u["max_health"]):
						problems.append("battle %d: %s above max health" % [n, u["def_id"]])
					for status in u["statuses"]:
						if int(u["statuses"][status]) <= 0:
							problems.append("battle %d: %s has %s %d" % [n, u["def_id"], status, u["statuses"][status]])
					alive[u["uid"]] = int(u["health"])
				"heal", "damage":
					if removed.has(e["uid"]):
						problems.append("battle %d: %s on a removed unit" % [n, e["type"]])
				"revive":
					removed.erase(e["uid"])
				"removed":
					if removed.has(e["uid"]):
						problems.append("battle %d: unit removed twice" % n)
					removed[e["uid"]] = false
				"end":
					ended = true
		# The outcome matches who is left standing.
		var player_left := 0
		var enemy_left := 0
		for e in result["events"]:
			if e["type"] == "start":
				for u in e["player"]:
					player_left += 0 if removed.has(u["uid"]) else 1
				for u in e["enemy"]:
					enemy_left += 0 if removed.has(u["uid"]) else 1
		if result["outcome"] == BattleSimulator.Outcome.WIN and enemy_left > 0:
			problems.append("battle %d: win with enemies left" % n)
		if result["outcome"] == BattleSimulator.Outcome.LOSS and player_left > 0:
			problems.append("battle %d: loss with figures left" % n)
		if problems.size() > 10:
			break
	assert_eq(problems, [], "\n".join(problems.slice(0, 10)))
