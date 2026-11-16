class_name EnemyGenerator
extends RefCounted
## Builds enemy teams from a strength budget (placeholder until M4 adds
## thematic synergies and the rule bosses).

## Budget per fight in act 1: small, big, boss.
const FIGHT_BUDGET := [1.5, 3.0, 4.0]
## Budget grows exponentially per act.
const ACT_GROWTH := 1.5
## Easy / medium / hard options in the enemy choice.
const DIFFICULTY_FACTOR := [0.75, 1.0, 1.35]
## Extra gold for winning against easy / medium / hard (and bosses).
const DIFFICULTY_BONUS := [0, 2, 4]
const BOSS_BONUS := 4
const MAX_TEAM := 6


static func budget(act: int, fight: int, difficulty: int) -> int:
	var value: float = FIGHT_BUDGET[fight] * pow(ACT_GROWTH, act - 1)
	if fight < 2:
		value *= DIFFICULTY_FACTOR[difficulty]
	return maxi(int(round(value)), 1)


## Enemy options for a fight: three difficulties for normal fights, one boss.
static func options(db: ContentDb, act: int, fight: int, rng: RandomNumberGenerator) -> Array:
	if fight == 2:
		return [{"kind": "boss", "difficulty": 2, "bonus": BOSS_BONUS,
			"team": generate(db, budget(act, fight, 2), rng)}]
	var result: Array = []
	for difficulty in 3:
		result.append({"kind": "normal", "difficulty": difficulty,
			"bonus": DIFFICULTY_BONUS[difficulty],
			"team": generate(db, budget(act, fight, difficulty), rng)})
	return result


## Spends the budget on enemies (cost = their "cost"), then on level-ups.
## Returns entries {"def_id": String, "level": int}, front first.
static func generate(db: ContentDb, team_budget: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = db.enemies.values()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var team: Array = []
	var remaining := team_budget
	while team.size() < MAX_TEAM:
		var affordable := pool.filter(func(e: Dictionary) -> bool: return int(e["cost"]) <= remaining)
		if affordable.is_empty():
			break
		var pick: Dictionary = affordable[rng.randi_range(0, affordable.size() - 1)]
		team.append({"def_id": pick["id"], "level": 1})
		remaining -= int(pick["cost"])
	# Leftover budget (full team) buys level-ups at the unit's cost.
	var guard := 0
	while remaining > 0 and guard < 50:
		guard += 1
		var upgradable := team.filter(func(u: Dictionary) -> bool:
			return u["level"] < 3 and int(db.enemies[u["def_id"]]["cost"]) <= remaining)
		if upgradable.is_empty():
			break
		var unit: Dictionary = upgradable[rng.randi_range(0, upgradable.size() - 1)]
		unit["level"] += 1
		remaining -= int(db.enemies[unit["def_id"]]["cost"])
	return team
