class_name BattleSimulator
extends RefCounted
## Deterministic auto-battle: the two front units hit each other at the
## same time every turn. Dead units leave the row and the next one moves up.
##
## The simulator never touches the UI. It returns a list of events that the
## battle view replays step by step, and that tests and balancing tools read.

const PLAYER := 0
const ENEMY := 1

## From this turn on, "the darkness devours" every unit (anti-stalemate).
const DECAY_START_TURN := 15
## Hard safety limit; decay guarantees an end long before this.
const MAX_TURNS := 100

enum Outcome { WIN, LOSS, DRAW }


## player_team / enemy_team: arrays of content definitions, front first.
## Returns { "outcome": Outcome, "victory": bool, "turns": int, "events": Array }.
static func simulate(player_team: Array, enemy_team: Array) -> Dictionary:
	var next_uid := 1
	var rows: Array = [[], []]
	for definition in player_team:
		rows[PLAYER].append(BattleUnit.from_definition(definition, PLAYER, next_uid))
		next_uid += 1
	for definition in enemy_team:
		rows[ENEMY].append(BattleUnit.from_definition(definition, ENEMY, next_uid))
		next_uid += 1

	var events: Array = []
	events.append({
		"type": "start",
		"player": rows[PLAYER].map(func(u: BattleUnit) -> Dictionary: return u.snapshot()),
		"enemy": rows[ENEMY].map(func(u: BattleUnit) -> Dictionary: return u.snapshot()),
	})

	var turn := 0
	while not rows[PLAYER].is_empty() and not rows[ENEMY].is_empty() and turn < MAX_TURNS:
		turn += 1
		events.append({"type": "turn", "turn": turn})
		_resolve_clash(rows, events)
		_remove_dead(rows, events)
		if turn >= DECAY_START_TURN and not _battle_over(rows):
			_apply_decay(rows, turn, events)
			_remove_dead(rows, events)

	var outcome := _outcome(rows)
	events.append({"type": "end", "outcome": outcome, "turn": turn})
	return {
		"outcome": outcome,
		"victory": outcome != Outcome.LOSS,  # a draw counts as a victory
		"turns": turn,
		"events": events,
	}


## Decay damage on a given turn: 1, 2, 4, 8 ... starting at DECAY_START_TURN.
static func decay_damage(turn: int) -> int:
	if turn < DECAY_START_TURN:
		return 0
	return 1 << mini(turn - DECAY_START_TURN, 30)


static func _resolve_clash(rows: Array, events: Array) -> void:
	var player_front: BattleUnit = rows[PLAYER][0]
	var enemy_front: BattleUnit = rows[ENEMY][0]
	# Both hits are computed before either is applied: simultaneous strike.
	var damage_to_enemy := player_front.attack
	var damage_to_player := enemy_front.attack
	events.append({
		"type": "clash",
		"player_uid": player_front.uid,
		"enemy_uid": enemy_front.uid,
	})
	_deal_damage(enemy_front, damage_to_enemy, "attack", events)
	_deal_damage(player_front, damage_to_player, "attack", events)


static func _apply_decay(rows: Array, turn: int, events: Array) -> void:
	var amount := decay_damage(turn)
	events.append({"type": "decay", "turn": turn, "amount": amount})
	for side in [PLAYER, ENEMY]:
		for unit: BattleUnit in rows[side]:
			_deal_damage(unit, amount, "decay", events)


static func _deal_damage(unit: BattleUnit, amount: int, source: String, events: Array) -> void:
	if amount <= 0:
		return
	unit.health -= amount
	events.append({
		"type": "damage", "uid": unit.uid, "amount": amount,
		"health_after": unit.health, "source": source,
	})


static func _remove_dead(rows: Array, events: Array) -> void:
	for side in [PLAYER, ENEMY]:
		var survivors: Array = []
		for unit: BattleUnit in rows[side]:
			if unit.is_alive():
				survivors.append(unit)
			else:
				events.append({"type": "death", "uid": unit.uid, "side": side})
		rows[side] = survivors


static func _battle_over(rows: Array) -> bool:
	return rows[PLAYER].is_empty() or rows[ENEMY].is_empty()


static func _outcome(rows: Array) -> Outcome:
	var player_alive: bool = not rows[PLAYER].is_empty()
	var enemy_alive: bool = not rows[ENEMY].is_empty()
	if player_alive and not enemy_alive:
		return Outcome.WIN
	if enemy_alive and not player_alive:
		return Outcome.LOSS
	# Both wiped out at once (or the safety limit hit): counts as a draw.
	return Outcome.DRAW
