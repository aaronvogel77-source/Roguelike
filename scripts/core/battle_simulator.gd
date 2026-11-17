class_name BattleSimulator
extends RefCounted
## Deterministic auto-battle.
##
## Turn order:
##   battle start: "battle_start" abilities (player front→back, then enemies,
##                 then abilities flagged "late")
##   every turn:   burn + bleed tick → "turn_start" abilities → front units clash
##                 (simultaneous) → "on_hit" / "on_attack" abilities →
##                 curse countdown → decay (from turn 15)
##   after every damage step: deaths, death abilities, revives.
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

var rows: Array = [[], []]
var events: Array = []
## Gold as abilities see it (0 under the Tax Collector's rule).
var gold := 0
## The player's real gold; thefts always take from this.
var real_gold := 0
var _gold_hidden := false
## Extra stacks for statuses the player applies, e.g. {"burn": {"all": 1}, "bleed": {"swords": 1}}.
var status_bonus: Dictionary = {}
## Pact hooks (see RunState.battle_options): gold factor, burn ×2 and spread,
## bleed ×2, weaker player healing, team-wide revives.
var gold_factor := 1
var burn_factor_vs_enemy := 1.0
var burn_spread := false
var bleed_factor := 1
var player_heal_factor := 1.0
var team_revives_left := 0
var turn := 0
var _next_uid := 1


## player_team / enemy_team: arrays of entries, front first. An entry is either
## a content definition or {"def": definition, "level": 1..3}.
## Returns { "outcome", "victory", "turns", "gold_after", "events" }.
## options: {"blessing": {"suit", "status", "amount"}} gives the player's
## figures of that suit a status at battle start (region blessing);
## {"gold_zero": true} makes abilities see 0 gold (thefts still hit real gold).
static func simulate(player_team: Array, enemy_team: Array, player_gold: int = 0, options: Dictionary = {}) -> Dictionary:
	var battle := BattleSimulator.new()
	return battle._run(player_team, enemy_team, player_gold, options)


## A unit as it would enter battle (for showing run modifiers on cards).
static func preview_unit(entry: Dictionary, side: int) -> BattleUnit:
	return BattleSimulator.new()._make_unit(entry, side)


## Decay damage on a given turn: 1, 2, 4, 8 ... starting at DECAY_START_TURN.
static func decay_damage(turn_number: int) -> int:
	if turn_number < DECAY_START_TURN:
		return 0
	return 1 << mini(turn_number - DECAY_START_TURN, 30)


func _run(player_team: Array, enemy_team: Array, player_gold: int, options: Dictionary = {}) -> Dictionary:
	real_gold = player_gold
	_gold_hidden = options.get("gold_zero", false)
	status_bonus = options.get("status_bonus", {})
	gold_factor = int(options.get("gold_factor", 1))
	burn_factor_vs_enemy = float(options.get("burn_factor_vs_enemy", 1.0))
	burn_spread = bool(options.get("burn_spread", false))
	bleed_factor = int(options.get("bleed_factor", 1))
	player_heal_factor = float(options.get("player_heal_factor", 1.0))
	team_revives_left = int(options.get("team_revives", 0))
	gold = 0 if _gold_hidden else real_gold * gold_factor
	for entry in player_team:
		rows[PLAYER].append(_make_unit(entry, PLAYER))
	for entry in enemy_team:
		rows[ENEMY].append(_make_unit(entry, ENEMY))

	events.append({
		"type": "start", "gold": real_gold,
		"player": rows[PLAYER].map(func(u: BattleUnit) -> Dictionary: return u.snapshot()),
		"enemy": rows[ENEMY].map(func(u: BattleUnit) -> Dictionary: return u.snapshot()),
	})

	if not _battle_over():
		_apply_blessing(options.get("blessing", {}))
		_fire_trigger("battle_start", false)
		_fire_trigger("battle_start", true)
		_process_deaths()

	while not _battle_over() and turn < MAX_TURNS:
		turn += 1
		events.append({"type": "turn", "turn": turn})
		_tick_damage_over_time()
		_process_deaths()
		if _battle_over():
			break
		_fire_trigger("turn_start", false)
		_process_deaths()
		if _battle_over():
			break
		_clash()
		_process_deaths()
		_tick_curses()
		if turn >= DECAY_START_TURN and not _battle_over():
			_apply_decay()
			_process_deaths()

	var outcome := _outcome()
	events.append({"type": "end", "outcome": outcome, "turn": turn})
	return {
		"outcome": outcome,
		"victory": outcome != Outcome.LOSS,  # a draw counts as a victory
		"turns": turn,
		"gold_after": real_gold,
		"events": events,
	}


func _make_unit(entry: Dictionary, side: int) -> BattleUnit:
	var definition: Dictionary = entry.get("def", entry)
	var level := int(entry.get("level", 1))
	var unit := BattleUnit.from_definition(definition, side, _next_uid, level)
	_next_uid += 1
	# Run modifiers: equipment, tarot boons, relics, blessings, suit changes.
	unit.attack += int(entry.get("bonus_attack", 0))
	unit.health += int(entry.get("bonus_health", 0))
	unit.health = maxi(unit.health, 1)
	unit.max_health = unit.health
	for factor in entry.get("multipliers", []):
		unit.multipliers.append(float(factor))
	unit.abilities.append_array(entry.get("abilities", []))
	if entry.has("suit"):
		unit.suit = entry["suit"]
		if unit.suits.is_empty() or not unit.display.has("fusion"):
			unit.suits = [unit.suit]
		else:
			unit.suits[0] = unit.suit
	unit.pierce = bool(definition.get("pierce", false)) or bool(entry.get("pierce", false))
	return unit


## Region blessing: player figures of the region's suit get a status first.
func _apply_blessing(blessing: Dictionary) -> void:
	if blessing.is_empty():
		return
	for unit: BattleUnit in rows[PLAYER]:
		if unit.has_suit(blessing["suit"]):
			unit.add_status(blessing["status"], int(blessing["amount"]))
			events.append({"type": "blessing", "uid": unit.uid, "status": blessing["status"]})
			_emit_update(unit)


# --- Turn steps ---------------------------------------------------------------

func _clash() -> void:
	var player_front: BattleUnit = rows[PLAYER][0]
	var enemy_front: BattleUnit = rows[ENEMY][0]
	# Both hits are computed before either is applied: simultaneous strike.
	var damage_to_enemy := _attack_damage(player_front, enemy_front)
	var damage_to_player := _attack_damage(enemy_front, player_front)
	events.append({"type": "clash", "player_uid": player_front.uid, "enemy_uid": enemy_front.uid})
	var dealt_to_enemy := _deal_damage(enemy_front, damage_to_enemy, "pierce" if player_front.pierce else "attack")
	var dealt_to_player := _deal_damage(player_front, damage_to_player, "pierce" if enemy_front.pierce else "attack")
	# Who struck the killing blow (read by "Soul Harvest").
	if not enemy_front.is_alive():
		enemy_front.flags["killed_by"] = player_front.uid
	if not player_front.is_alive():
		player_front.flags["killed_by"] = enemy_front.uid

	# Reactions: the hit units first, then the attackers.
	# "on_hit" counts any attack that connects, even if a shield absorbed it.
	for pair in [[enemy_front, player_front, damage_to_enemy], [player_front, enemy_front, damage_to_player]]:
		var hit_unit: BattleUnit = pair[0]
		if hit_unit.is_alive() and pair[2] > 0:
			_fire_unit_abilities(hit_unit, "on_hit", {"attacker": pair[1]})
	for pair in [[player_front, enemy_front, dealt_to_enemy], [enemy_front, player_front, dealt_to_player]]:
		var attacker: BattleUnit = pair[0]
		if attacker.is_alive():
			_fire_unit_abilities(attacker, "on_attack", {"attack_target": pair[1], "damage_dealt": pair[2]})


## Normal attack damage; "Glühhieb" (master) hits burning targets harder.
func _attack_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	var damage := attacker.effective_attack()
	var glow := attacker.aura("glow_strike")
	if not glow.is_empty() and target.status(BattleUnit.STATUS_BURN) > 0:
		damage = int(floor(damage * attacker.level_value(glow)))
	return damage


## Turn start, every unit wherever it stands in the row:
## burn deals its stacks (× burn auras) and loses one stack;
## bleed deals its stacks and keeps them.
func _tick_damage_over_time() -> void:
	for side in [PLAYER, ENEMY]:
		for unit: BattleUnit in rows[side].duplicate():
			var burn := unit.status(BattleUnit.STATUS_BURN)
			if burn > 0:
				var amount := int(floor(burn * _burn_multiplier_against(unit)))
				_deal_damage(unit, amount, "burn")
				unit.add_status(BattleUnit.STATUS_BURN, -1)
				events.append({"type": "burn_tick", "uid": unit.uid, "from": burn, "to": burn - 1})
				_emit_update(unit)
			var bleed := unit.status(BattleUnit.STATUS_BLEED)
			if bleed > 0 and unit.is_alive():
				var dealt := _deal_damage(unit, bleed, "bleed")
				# "Aderlass" (master): opponents heal by the bleed damage dealt.
				for healer: BattleUnit in living(1 - unit.side):
					if dealt > 0 and not healer.aura("bloodletting").is_empty():
						events.append({"type": "trigger", "uid": healer.uid, "effect": "bloodletting", "targets": [healer.uid]})
						_heal(healer, dealt)


func _tick_curses() -> void:
	for side in [PLAYER, ENEMY]:
		for unit: BattleUnit in rows[side]:
			if unit.status(BattleUnit.STATUS_CURSE) <= 0:
				continue
			unit.curse_turns_left -= 1
			if unit.curse_turns_left <= 0:
				unit.statuses.erase(BattleUnit.STATUS_CURSE)
				_emit_update(unit)


func _apply_decay() -> void:
	var amount := decay_damage(turn)
	events.append({"type": "decay", "turn": turn, "amount": amount})
	for side in [PLAYER, ENEMY]:
		for unit: BattleUnit in rows[side]:
			_deal_damage(unit, amount, "decay")


## Burn damage multiplier from "burn_mult" auras of the burning unit's opponents.
func _burn_multiplier_against(unit: BattleUnit) -> float:
	var factor := burn_factor_vs_enemy if unit.side == ENEMY else 1.0
	for owner: BattleUnit in rows[1 - unit.side]:
		for ability in owner.abilities:
			if ability["trigger"] == "aura" and ability["effect"] == "burn_mult":
				factor *= owner.level_value(ability)
	return factor


# --- Damage, healing, deaths -----------------------------------------------------

## Applies damage, shield first (decay ignores shields). Returns damage to health.
func _deal_damage(unit: BattleUnit, amount: int, source: String) -> int:
	if amount <= 0 or not unit.is_alive():
		return 0
	var remaining := amount
	var shield := unit.status(BattleUnit.STATUS_SHIELD)
	# The darkness and piercing attacks ignore shields.
	if shield > 0 and source != "decay" and source != "pierce":
		var absorbed := mini(shield, remaining)
		unit.add_status(BattleUnit.STATUS_SHIELD, -absorbed)
		remaining -= absorbed
		events.append({"type": "shielded", "uid": unit.uid, "amount": absorbed})
	if remaining > 0:
		unit.health -= remaining
		events.append({
			"type": "damage", "uid": unit.uid, "amount": remaining,
			"health_after": unit.health, "source": source,
		})
	_emit_update(unit)
	return remaining


func _heal(unit: BattleUnit, amount: int) -> void:
	if unit.side == PLAYER and player_heal_factor < 1.0:
		amount = int(floor(amount * player_heal_factor))
	var healed := mini(amount, unit.max_health - unit.health)
	if not unit.is_alive():
		return
	# "Überfluss" (master): healing beyond full health becomes shield.
	var excess := amount - maxi(healed, 0)
	if excess > 0 and not unit.aura("overflow").is_empty():
		unit.add_status(BattleUnit.STATUS_SHIELD, excess)
		events.append({"type": "trigger", "uid": unit.uid, "effect": "overflow", "targets": [unit.uid]})
		_emit_update(unit)
	if healed <= 0:
		return
	unit.health += healed
	events.append({"type": "heal", "uid": unit.uid, "amount": healed})
	_emit_update(unit)


## Resolves deaths until stable: death abilities may revive or change units.
func _process_deaths() -> void:
	while true:
		var dying: Array = []
		for side in [PLAYER, ENEMY]:
			for unit: BattleUnit in rows[side]:
				if not unit.is_alive() and not unit.flags.get("death_resolved", false):
					dying.append(unit)
		if dying.is_empty():
			return
		for unit: BattleUnit in dying:
			unit.flags["death_resolved"] = true
			events.append({"type": "dying", "uid": unit.uid})
			_fire_death_abilities(unit)
			_pact_death_hooks(unit)
			if unit.is_alive():  # revived by an ability
				unit.flags["death_resolved"] = false
			else:
				rows[unit.side].erase(unit)
				events.append({"type": "removed", "uid": unit.uid, "side": unit.side})


## Pacts: burning enemies pass their burn on; team revives for the player.
func _pact_death_hooks(unit: BattleUnit) -> void:
	if burn_spread and unit.side == ENEMY and unit.status(BattleUnit.STATUS_BURN) > 0:
		var next_units := living(ENEMY)
		if not next_units.is_empty():
			var next_unit: BattleUnit = next_units[0]
			next_unit.add_status(BattleUnit.STATUS_BURN, unit.status(BattleUnit.STATUS_BURN))
			_emit_update(next_unit)
	if unit.side == PLAYER and not unit.is_alive() and team_revives_left > 0:
		team_revives_left -= 1
		unit.health = maxi(unit.max_health / 2, 1)
		unit.statuses.clear()
		events.append({"type": "revive", "uid": unit.uid, "health": unit.health})
		_emit_update(unit)


func _fire_death_abilities(dying_unit: BattleUnit) -> void:
	# The unit's own "on death" abilities (e.g. equipment that pays gold).
	_fire_unit_abilities(dying_unit, "on_death", {"dying_unit": dying_unit})
	for owner: BattleUnit in rows[dying_unit.side].duplicate():
		if owner != dying_unit and owner.is_alive():
			_fire_unit_abilities(owner, "on_ally_death", {"dying_unit": dying_unit})
	for owner: BattleUnit in rows[1 - dying_unit.side].duplicate():
		if owner.is_alive():
			_fire_unit_abilities(owner, "on_enemy_death", {"dying_unit": dying_unit})


# --- Abilities -------------------------------------------------------------------

## Fires a trigger for every living unit: player side first, front to back.
func _fire_trigger(trigger: String, late_only: bool) -> void:
	for side in [PLAYER, ENEMY]:
		for unit: BattleUnit in rows[side].duplicate():
			if unit.is_alive():
				_fire_unit_abilities(unit, trigger, {}, late_only)


func _fire_unit_abilities(unit: BattleUnit, trigger: String, context: Dictionary, late_only: bool = false) -> void:
	for ability in unit.abilities.duplicate():
		if ability["trigger"] != trigger:
			continue
		if trigger == "battle_start" and bool(ability.get("late", false)) != late_only:
			continue
		_execute(unit, ability, context)


func _execute(owner: BattleUnit, ability: Dictionary, context: Dictionary) -> void:
	var value := owner.level_value(ability)
	var targets := _resolve_targets(owner, ability["target"], context)
	if targets.is_empty() and ability["target"] != "self":
		return
	# The trigger event is inserted before the effect's own events, so the view
	# first highlights the source and then shows what the ability did.
	var insert_at := events.size()
	var changed := AbilityEffects.apply(self, owner, ability["effect"], value, targets, context)
	if changed:
		events.insert(insert_at, {
			"type": "trigger", "uid": owner.uid, "effect": ability["effect"],
			"targets": targets.map(func(t: BattleUnit) -> int: return t.uid),
		})


func _resolve_targets(owner: BattleUnit, target: String, context: Dictionary) -> Array:
	var allies: Array = rows[owner.side].filter(func(u: BattleUnit) -> bool: return u.is_alive())
	var enemies: Array = rows[1 - owner.side].filter(func(u: BattleUnit) -> bool: return u.is_alive())
	match target:
		"self":
			return [owner]
		"attack_target":
			var t: BattleUnit = context.get("attack_target")
			return [t] if t != null else []
		"dying_unit":
			return [context["dying_unit"]]
		"front_ally":
			return allies.slice(0, 1)
		"back_ally":
			return allies.slice(allies.size() - 1) if not allies.is_empty() else []
		"ally_in_front":
			var index := allies.find(owner)
			return [allies[index - 1]] if index > 0 else []
		"front_enemy":
			return enemies.slice(0, 1)
		"back_enemy":
			return enemies.slice(enemies.size() - 1) if not enemies.is_empty() else []
		"all_enemies":
			return enemies
		"all_allies":
			return allies
	push_error("Unknown ability target: " + target)
	return []


# --- Helpers used by AbilityEffects ---------------------------------------------

## Extra stacks when a player unit applies a status (relics like Eternal Ember).
func bonus_stacks(owner: BattleUnit, status: String) -> int:
	if owner.side != PLAYER or not status_bonus.has(status):
		return 0
	var rule: Dictionary = status_bonus[status]
	var extra := 0
	for suit in owner.suits if not owner.suits.is_empty() else [owner.suit]:
		extra = maxi(extra, int(rule.get(suit, 0)))
	return int(rule.get("all", 0)) + extra

func deal_damage(unit: BattleUnit, amount: int, source: String) -> int:
	return _deal_damage(unit, amount, source)


func heal(unit: BattleUnit, amount: int) -> void:
	_heal(unit, amount)


## Changes the player's real gold; returns the actual change.
func change_gold(delta: int) -> int:
	var before := real_gold
	real_gold = maxi(real_gold + delta, 0)
	gold = 0 if _gold_hidden else real_gold * gold_factor * gold_factor
	if real_gold != before:
		events.append({"type": "gold", "gold": real_gold, "delta": real_gold - before})
	return real_gold - before


func emit_update(unit: BattleUnit) -> void:
	_emit_update(unit)


func living(side: int) -> Array:
	return rows[side].filter(func(u: BattleUnit) -> bool: return u.is_alive())


func _emit_update(unit: BattleUnit) -> void:
	events.append({"type": "update", "unit": unit.snapshot()})


func _battle_over() -> bool:
	return rows[PLAYER].is_empty() or rows[ENEMY].is_empty()


func _outcome() -> Outcome:
	var player_alive: bool = not rows[PLAYER].is_empty()
	var enemy_alive: bool = not rows[ENEMY].is_empty()
	if player_alive and not enemy_alive:
		return Outcome.WIN
	if enemy_alive and not player_alive:
		return Outcome.LOSS
	# Both wiped out at once (or the safety limit hit): counts as a draw.
	return Outcome.DRAW
