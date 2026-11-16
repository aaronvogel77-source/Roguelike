class_name DebugTeams
extends RefCounted
## Placeholder team builder for M1/M2 until the shop and the enemy
## generator exist. Picks random figures with the given RNG.


static func random_player_team(db: ContentDb, rng: RandomNumberGenerator, size: int) -> Array:
	return _pick(db.figures.values(), rng, size)


static func random_enemy_team(db: ContentDb, rng: RandomNumberGenerator, size: int) -> Array:
	return _pick(db.enemies.values(), rng, size)


static func _pick(pool: Array, rng: RandomNumberGenerator, size: int) -> Array:
	var sorted_pool := pool.duplicate()
	sorted_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var team: Array = []
	for i in size:
		team.append(sorted_pool[rng.randi_range(0, sorted_pool.size() - 1)])
	return team
