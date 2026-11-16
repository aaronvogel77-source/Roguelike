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
