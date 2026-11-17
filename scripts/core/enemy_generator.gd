class_name EnemyGenerator
extends RefCounted
## Builds enemy teams from a strength budget.
##
## Every team gets a theme of its region (e.g. "vault" = shields). Units of
## that theme are three times as likely to be picked, so teams have a clear
## plan. Teams are ordered by role: front units first, back units last.
## The boss fight of an act adds a rule boss from the region's pool.

## Budget per fight in act 1: small, big, boss.
## The boss budget pays only for the retinue; the boss figure comes on top.
const FIGHT_BUDGET := [1.5, 3.0, 2.0]
## Budget grows exponentially per act.
const ACT_GROWTH := 1.5
## Retinue budget of the boss fight per act (act 1 kept small: the boss itself is strong).
const BOSS_RETINUE := [1.0, 3.0]
## Easy / medium / hard options in the enemy choice.
const DIFFICULTY_FACTOR := [0.75, 1.0, 1.35]
## Extra gold for winning against easy / medium / hard (and bosses).
const DIFFICULTY_BONUS := [0, 2, 4]
const BOSS_BONUS := 4
## Enemy row capacity in card widths (a boss figure takes 2-3 of them).
const MAX_TEAM := 6
const THEME_WEIGHT := 3
const ROLE_ORDER := {"front": 0, "any": 1, "back": 2}
## Each harder option is at least this much stronger than the one before.
const MIN_STEP := 1.3
## The hard option always has at least this many enemies (one dragon alone was too easy).
const HARD_MIN_UNITS := 2


static func budget(act: int, fight: int, difficulty: int) -> int:
	var value: float = FIGHT_BUDGET[fight] * pow(ACT_GROWTH, act - 1)
	if fight == 2:
		value = BOSS_RETINUE[act - 1] if act <= BOSS_RETINUE.size() else BOSS_RETINUE[-1] * pow(ACT_GROWTH, act - BOSS_RETINUE.size())
	if fight < 2:
		value *= DIFFICULTY_FACTOR[difficulty]
	return maxi(int(round(value)), 1)


## Enemy options for a fight: three difficulties for normal fights, one boss.
static func options(db: ContentDb, region: String, act: int, fight: int, rng: RandomNumberGenerator) -> Array:
	if fight == 2:
		var boss := _pick_boss(db, region, act, rng)
		var capacity := 7 if boss.get("rule", "") == "seven_slots" else MAX_TEAM
		var theme := _pick_theme(db, region, rng)
		var team: Array = []
		if boss.has("unit"):
			capacity -= int(boss["unit"].get("width", 1))
			team.append({"def_id": boss["unit"]["id"], "level": 1})
		team.append_array(generate(db, budget(act, fight, 2), rng, theme, capacity))
		return [{"kind": "boss", "difficulty": 2, "bonus": BOSS_BONUS, "theme": theme,
			"boss_id": boss.get("id", ""), "rule": boss.get("rule", ""), "team": team}]
	var teams: Array = []
	var used: Array = []  # enemy ids of earlier options: avoided where possible
	for difficulty in 3:
		var theme := _pick_theme(db, region, rng)
		# Hard teams prefer the stronger (more expensive) enemies.
		var team := generate(db, budget(act, fight, difficulty), rng, theme, MAX_TEAM, used, difficulty == 2)
		for unit in team:
			used.append(unit["def_id"])
		teams.append({"theme": theme, "team": team, "power": power(db, team)})
	# The labels follow the real strength: the weakest team is "easy".
	teams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] < b["power"])
	# Fixed steps: medium >= 1.3 × easy, hard >= 1.3 × medium and at least 2 enemies.
	for difficulty in [1, 2]:
		var team: Array = teams[difficulty]["team"]
		var target: float = teams[difficulty - 1]["power"] * MIN_STEP
		var min_units := HARD_MIN_UNITS if difficulty == 2 else 1
		_strengthen(db, team, rng, teams[difficulty]["theme"], target, min_units)
		teams[difficulty]["power"] = power(db, team)
	var result: Array = []
	for difficulty in 3:
		result.append({"kind": "normal", "difficulty": difficulty, "theme": teams[difficulty]["theme"],
			"bonus": DIFFICULTY_BONUS[difficulty], "team": teams[difficulty]["team"]})
	return result


## Rough fighting strength of a team: sum of attack × health (with levels).
static func power(db: ContentDb, team: Array) -> float:
	var total := 0.0
	for unit in team:
		var definition: Dictionary = db.enemies[unit["def_id"]]
		var level := int(unit["level"])
		total += (int(definition["attack"]) + level - 1) * (int(definition["health"]) + level - 1)
	return total


## Spends the budget on enemies (cost = their "cost"), then on level-ups.
## Returns entries {"def_id": String, "level": int}, front first.
static func generate(db: ContentDb, team_budget: int, rng: RandomNumberGenerator,
		theme: String = "", max_team: int = MAX_TEAM, avoid: Array = [], prefer_strong := false) -> Array:
	var pool: Array = db.regular_enemies()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var team: Array = []
	var remaining := team_budget
	while team.size() < max_team:
		var affordable := pool.filter(func(e: Dictionary) -> bool: return int(e["cost"]) <= remaining)
		if affordable.is_empty():
			break
		# Prefer enemies the other options do not use, so the choices differ.
		var fresh := affordable.filter(func(e: Dictionary) -> bool: return not e["id"] in avoid)
		if not fresh.is_empty():
			affordable = fresh
		var pick := _weighted_pick(affordable, theme, rng, prefer_strong)
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
	_order_by_role(db, team)
	return team


## Adds enemies (cheap ones first) or levels until the team reaches the
## target strength and size.
static func _strengthen(db: ContentDb, team: Array, rng: RandomNumberGenerator, theme: String,
		target: float, min_units: int) -> void:
	var pool: Array = db.regular_enemies()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var cheap := pool.filter(func(e: Dictionary) -> bool: return int(e["cost"]) <= 2)
	var guard := 0
	while (power(db, team) < target or team.size() < min_units) and guard < 30:
		guard += 1
		if team.size() < MAX_TEAM and (team.size() < min_units or rng.randf() < 0.5):
			var pick := _weighted_pick(cheap, theme, rng)
			team.append({"def_id": pick["id"], "level": 1})
			continue
		var upgradable := team.filter(func(u: Dictionary) -> bool: return u["level"] < 3)
		if upgradable.is_empty():
			if team.size() >= MAX_TEAM:
				break
			team.append({"def_id": _weighted_pick(cheap, theme, rng)["id"], "level": 1})
			continue
		upgradable[rng.randi_range(0, upgradable.size() - 1)]["level"] += 1
	_order_by_role(db, team)


static func _weighted_pick(candidates: Array, theme: String, rng: RandomNumberGenerator, prefer_strong := false) -> Dictionary:
	var weights: Array = candidates.map(func(e: Dictionary) -> int:
		var w := THEME_WEIGHT if theme in e.get("themes", []) else 1
		return w * int(e["cost"]) * int(e["cost"]) if prefer_strong else w)
	var total := 0
	for w in weights:
		total += w
	var roll := rng.randi_range(1, total)
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0:
			return candidates[i]
	return candidates[-1]


## Front units first, back units last; ties: more health in front. Stable.
static func _order_by_role(db: ContentDb, team: Array) -> void:
	var indexed: Array = []
	for i in team.size():
		indexed.append([team[i], i])
	indexed.sort_custom(func(a: Array, b: Array) -> bool:
		var da: Dictionary = db.enemies[a[0]["def_id"]]
		var dbb: Dictionary = db.enemies[b[0]["def_id"]]
		var ra: int = ROLE_ORDER.get(da.get("role", "any"), 1)
		var rb: int = ROLE_ORDER.get(dbb.get("role", "any"), 1)
		if ra != rb:
			return ra < rb
		if int(da["health"]) != int(dbb["health"]):
			return int(da["health"]) > int(dbb["health"])
		return a[1] < b[1])
	for i in indexed.size():
		team[i] = indexed[i][0]


static func _pick_theme(db: ContentDb, region: String, rng: RandomNumberGenerator) -> String:
	var themes: Array = db.regions.get(region, {}).get("themes", [])
	if themes.is_empty():
		return ""
	return themes[rng.randi_range(0, themes.size() - 1)]


static func _pick_boss(db: ContentDb, region: String, act: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool := db.bosses_for(region, act)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]
