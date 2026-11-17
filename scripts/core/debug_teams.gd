class_name DebugTeams
extends RefCounted
## Placeholder team builder until the shop and the enemy generator exist.
## Picks random figures (with random levels) using the given RNG.
## Entries have the form {"def": definition, "level": 1..3}.


static func random_player_team(db: ContentDb, rng: RandomNumberGenerator, size: int, max_level: int = 3) -> Array:
	return _pick(db.figures.values(), rng, size, max_level)


static func random_enemy_team(db: ContentDb, rng: RandomNumberGenerator, size: int, max_level: int = 1) -> Array:
	return _pick(db.enemies.values(), rng, size, max_level)


static func _pick(pool: Array, rng: RandomNumberGenerator, size: int, max_level: int) -> Array:
	var sorted_pool := pool.duplicate()
	sorted_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var team: Array = []
	for i in size:
		var definition: Dictionary = sorted_pool[rng.randi_range(0, sorted_pool.size() - 1)]
		# Level 1 is most common: 60 % / 30 % / 10 %.
		var roll := rng.randf()
		var level := 1 if roll < 0.6 else (2 if roll < 0.9 else 3)
		team.append({"def": definition, "level": mini(level, max_level)})
	return team


## Arena only: turns up to two figures into fusions (F1-F3, sometimes pure),
## so fusion forms, auras and master abilities can be watched.
static func add_fusions(db: ContentDb, rng: RandomNumberGenerator, team: Array) -> void:
	var plain: Array = db.figures.values().filter(func(f: Dictionary) -> bool: return not f.get("recipe", false))
	plain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for n in mini(2, team.size()):
		var index := rng.randi_range(0, team.size() - 1)
		var size := rng.randi_range(2, 4)
		var parts: Array = []
		var pure := rng.randf() < 0.5
		var suit := String(plain[rng.randi_range(0, plain.size() - 1)]["suit"])
		while parts.size() < size:
			var pick: Dictionary = plain[rng.randi_range(0, plain.size() - 1)]
			if pure and parts.size() < 3 and pick["suit"] != suit:
				continue
			parts.append(pick["id"])
		var figure := {"uid": 1, "def_id": parts[0], "xp": 0, "fusion": {"parts": parts,
			"suits": parts.map(func(id: String) -> String: return String(db.figures[id]["suit"])),
			"abilities": parts.slice(0, 2), "attack": 6, "health": 9, "partner": parts[1]}}
		team[index] = {"def": Fusion.definition(db, figure), "level": 1, "abilities": Fusion.abilities(db, figure),
			"pierce": Fusion.pierces(db, figure), "suits": figure["fusion"]["suits"], "figure": figure}

