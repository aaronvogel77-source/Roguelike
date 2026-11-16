class_name AbilityEffects
extends RefCounted
## The effect library of the ability building kit.
## An ability in the content files is: trigger + target + effect + values.
## Each effect below is one building block; special figures get their own
## small effect (e.g. "midas"), which is the agreed "kit + special scripts".
##
## apply() returns true when something actually happened, so the battle view
## only highlights abilities that had a visible result.

const STEAL_CAP_PER_BATTLE := 3


static func apply(battle: BattleSimulator, owner: BattleUnit, effect: String, value: float,
		targets: Array, context: Dictionary) -> bool:
	match effect:
		"gain_shield":
			return _add_status(battle, owner, targets, BattleUnit.STATUS_SHIELD, int(value))
		"apply_burn":
			return _add_status(battle, owner, targets, BattleUnit.STATUS_BURN, int(value))
		"apply_bleed":
			return _add_status(battle, owner, targets, BattleUnit.STATUS_BLEED, int(value))
		"apply_curse":
			return _add_status(battle, owner, targets, BattleUnit.STATUS_CURSE, int(value))
		"gain_attack":
			for t: BattleUnit in targets:
				t.attack += int(value)
				battle.emit_update(t)
			return not targets.is_empty()
		"gain_stats":
			for t: BattleUnit in targets:
				t.attack += int(value)
				t.health += int(value)
				t.max_health += int(value)
				battle.emit_update(t)
			return not targets.is_empty()
		"mult_attack":
			for t: BattleUnit in targets:
				t.multipliers.append(value)
				battle.emit_update(t)
			return not targets.is_empty()
		"heal":
			for t: BattleUnit in targets:
				battle.heal(t, int(value))
			return not targets.is_empty()
		"damage":
			for t: BattleUnit in targets:
				battle.deal_damage(t, int(value), "ability")
			return not targets.is_empty()
		"health_per_gold":
			return _health_per_gold(battle, owner, int(value))
		"midas":
			return _midas(battle, owner, value)
		"spread_burn_and_mult":
			return _spread_burn_and_mult(battle, owner, value, context)
		"lifesteal":
			return _lifesteal(battle, owner, value, context)
		"revive":
			return _revive(battle, owner, int(value), targets)
		"absorb":
			return _absorb(battle, owner, value, context)
		"execute":
			return _execute(battle, int(value), targets)
		"shields_to_bleed":
			return _shields_to_bleed(battle, int(value), targets)
		"detonate_bleed":
			return _detonate_bleed(battle, int(value), targets)
		"steal_gold":
			return _steal_gold(battle, owner, int(value))
		"attack_per_ten_gold":
			# Debt Collector: +value attack for every full 10 gold the player owns.
			var bonus := battle.gold / 10 * int(value)
			if bonus <= 0:
				return false
			owner.attack += bonus
			battle.emit_update(owner)
			return true
		"swap_stats":
			for t: BattleUnit in targets:
				var old_attack := t.attack
				t.attack = t.health
				t.health = old_attack
				t.max_health = t.health
				battle.emit_update(t)
			return not targets.is_empty()
		"eat_shield":
			return _eat_shield(battle, owner, targets)
		"lose_health_pct":
			# Blood pact: lose a share of max health (at least 1).
			var loss := maxi(int(floor(owner.max_health * value / 100.0)), 1)
			owner.health = maxi(owner.health - loss, 1)
			battle.emit_update(owner)
			return true
		"gather_shields":
			# Vanguard pact: the front figure takes every ally's shield.
			var gathered := 0
			for ally: BattleUnit in battle.living(owner.side):
				if ally != owner and ally.status(BattleUnit.STATUS_SHIELD) > 0:
					gathered += ally.status(BattleUnit.STATUS_SHIELD)
					ally.statuses.erase(BattleUnit.STATUS_SHIELD)
					battle.emit_update(ally)
			if gathered <= 0:
				return false
			owner.add_status(BattleUnit.STATUS_SHIELD, gathered)
			battle.emit_update(owner)
			return true
		"gain_gold":
			return battle.change_gold(int(value)) != 0
		"shield_from_interest":
			# Ace of Coins: shield = interest (1 per 5 gold, max 5) × value.
			var shield := mini(battle.gold / 5, 5) * int(value)
			if shield <= 0:
				return false
			return _add_status(battle, owner, targets, BattleUnit.STATUS_SHIELD, shield)
		"revive_half":
			return _revive_half(battle, owner, int(value), targets)
		"double_bleed":
			for t: BattleUnit in targets:
				var bleed := t.status(BattleUnit.STATUS_BLEED)
				if bleed > 0 and t.is_alive():
					t.add_status(BattleUnit.STATUS_BLEED, bleed)
					battle.emit_update(t)
					return true
			return false
		"pawn_gold":
			# Tax Collector boss: steals 1 real gold and grows (max 3x per battle).
			if not _steal_gold(battle, owner, 1):
				return false
			owner.attack += int(value)
			battle.emit_update(owner)
			return true
		"warden_shield":
			# Vault Warden: shield at battle start, plus +1 shield whenever hit.
			owner.add_status(BattleUnit.STATUS_SHIELD, int(value))
			owner.abilities.append({"trigger": "on_hit", "target": "self", "effect": "gain_shield", "values": [1, 1, 1]})
			battle.emit_update(owner)
			return true
		"copy_ability":
			return _copy_ability(battle, owner, targets, context)
		"burn_mult":
			return false  # aura, read directly by the simulator when burn ticks
	push_error("Unknown ability effect: " + effect)
	return false


static func _add_status(battle: BattleSimulator, owner: BattleUnit, targets: Array, status: String, amount: int) -> bool:
	# Shields are protection; relic bonuses only add to damaging statuses.
	if status != BattleUnit.STATUS_SHIELD:
		amount += battle.bonus_stacks(owner, status)
	if status == BattleUnit.STATUS_BLEED and owner.side == BattleSimulator.PLAYER:
		amount *= battle.bleed_factor
	for t: BattleUnit in targets:
		t.add_status(status, amount)
		battle.emit_update(t)
	return not targets.is_empty() and amount > 0


static func _health_per_gold(battle: BattleSimulator, owner: BattleUnit, gold_per_health: int) -> bool:
	var bonus := battle.gold / maxi(gold_per_health, 1)
	if bonus <= 0:
		return false
	owner.health += bonus
	owner.max_health += bonus
	battle.emit_update(owner)
	return true


## King Midas: attack × (1 + gold / divisor).
static func _midas(battle: BattleSimulator, owner: BattleUnit, divisor: float) -> bool:
	if battle.gold <= 0:
		return false
	owner.multipliers.append(1.0 + battle.gold / divisor)
	battle.emit_update(owner)
	return true


## Ash King: a dying enemy's burn jumps to the next enemy; the king gains a multiplier.
static func _spread_burn_and_mult(battle: BattleSimulator, owner: BattleUnit, factor: float, context: Dictionary) -> bool:
	var dying: BattleUnit = context["dying_unit"]
	var burn := dying.status(BattleUnit.STATUS_BURN)
	if burn > 0:
		var next_enemies := battle.living(dying.side)
		if not next_enemies.is_empty():
			var next_enemy: BattleUnit = next_enemies[0]
			next_enemy.add_status(BattleUnit.STATUS_BURN, burn)
			battle.emit_update(next_enemy)
	owner.multipliers.append(factor)
	battle.emit_update(owner)
	return true


static func _lifesteal(battle: BattleSimulator, owner: BattleUnit, share: float, context: Dictionary) -> bool:
	var amount := int(floor(int(context.get("damage_dealt", 0)) * share))
	if amount <= 0 or owner.health >= owner.max_health:
		return false
	battle.heal(owner, amount)
	return true


## Chalice of Return: once per battle, a fallen ally comes back.
static func _revive(battle: BattleSimulator, owner: BattleUnit, health: int, targets: Array) -> bool:
	if owner.flags.get("revive_used", false) or targets.is_empty():
		return false
	var unit: BattleUnit = targets[0]
	if unit.is_alive():
		return false
	owner.flags["revive_used"] = true
	unit.health = mini(health, unit.max_health)
	unit.statuses.clear()
	battle.events.append({"type": "revive", "uid": unit.uid, "health": unit.health})
	battle.emit_update(unit)
	return true


## Ace of Cups: a fallen ally returns with half its health (charges per battle).
static func _revive_half(battle: BattleSimulator, owner: BattleUnit, charges: int, targets: Array) -> bool:
	var used: int = owner.flags.get("revives_used", 0)
	if used >= charges or targets.is_empty():
		return false
	var unit: BattleUnit = targets[0]
	if unit.is_alive():
		return false
	owner.flags["revives_used"] = used + 1
	unit.health = maxi(unit.max_health / 2, 1)
	unit.statuses.clear()
	battle.events.append({"type": "revive", "uid": unit.uid, "health": unit.health})
	battle.emit_update(unit)
	return true


## Drowned King: takes a share of a fallen ally's attack and health.
static func _absorb(battle: BattleSimulator, owner: BattleUnit, share: float, context: Dictionary) -> bool:
	var dying: BattleUnit = context["dying_unit"]
	# Both attack and health are absorbed only partly (30 / 60 / 100 %).
	var gained_health := int(floor(dying.max_health * share))
	owner.attack += int(floor(dying.attack * share))
	owner.health += gained_health
	owner.max_health += gained_health
	battle.emit_update(owner)
	return true


static func _execute(battle: BattleSimulator, threshold: int, targets: Array) -> bool:
	for t: BattleUnit in targets:
		if t.is_alive() and t.health <= threshold:
			battle.deal_damage(t, t.health + t.status(BattleUnit.STATUS_SHIELD), "execute")
			return true
	return false


## Clear Blade: removes every enemy shield; each removed shield point adds bleed.
static func _shields_to_bleed(battle: BattleSimulator, bleed_per_point: int, targets: Array) -> bool:
	var any := false
	for t: BattleUnit in targets:
		var shield := t.status(BattleUnit.STATUS_SHIELD)
		if shield <= 0:
			continue
		t.statuses.erase(BattleUnit.STATUS_SHIELD)
		t.add_status(BattleUnit.STATUS_BLEED, shield * bleed_per_point)
		battle.emit_update(t)
		any = true
	return any


## The Judge: the target's bleed bursts at once (bleed × factor), bleed stays.
static func _detonate_bleed(battle: BattleSimulator, factor: int, targets: Array) -> bool:
	for t: BattleUnit in targets:
		var bleed := t.status(BattleUnit.STATUS_BLEED)
		if bleed > 0 and t.is_alive():
			battle.deal_damage(t, bleed * factor, "ability")
			return true
	return false


static func _steal_gold(battle: BattleSimulator, owner: BattleUnit, amount: int) -> bool:
	var stolen: int = owner.flags.get("gold_stolen", 0)
	var allowed := mini(amount, STEAL_CAP_PER_BATTLE - stolen)
	if allowed <= 0:
		return false
	var taken := -battle.change_gold(-allowed)
	owner.flags["gold_stolen"] = stolen + taken
	return taken > 0


static func _eat_shield(battle: BattleSimulator, owner: BattleUnit, targets: Array) -> bool:
	for t: BattleUnit in targets:
		var shield := t.status(BattleUnit.STATUS_SHIELD)
		if shield > 0:
			t.statuses.erase(BattleUnit.STATUS_SHIELD)
			battle.emit_update(t)
			owner.max_health = maxi(owner.max_health, owner.health + shield)
			battle.heal(owner, shield)
			return true
	return false


## Mirror Coin: copies the ability of the opposing front unit.
static func _copy_ability(battle: BattleSimulator, owner: BattleUnit, targets: Array, context: Dictionary) -> bool:
	if targets.is_empty() or targets[0].abilities.is_empty():
		return false
	var copied: Dictionary = targets[0].abilities[0].duplicate(true)
	owner.abilities.append(copied)
	battle.emit_update(owner)
	battle.events.append({"type": "trigger", "uid": owner.uid, "effect": "copy_ability", "targets": [targets[0].uid]})
	# A copied battle-start ability fires right away.
	if copied["trigger"] == "battle_start" and copied["effect"] != "copy_ability":
		battle._execute(owner, copied, context)
	return false  # the trigger event was already emitted above
