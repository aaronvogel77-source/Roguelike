class_name TeamBuilder
extends RefCounted
## Turns the run's row into battle entries: base figure + level, plus
## equipment, tarot boons and blessings of each figure and the global relics.


## Battle entries ({"def", "level", "bonus_attack", "bonus_health",
## "multipliers", "abilities", "suit"}), front first.
static func player_team(run: RunState) -> Array:
	var team: Array = []
	for figure in run.row:
		if figure != null:
			team.append(_figure_entry(run, figure))
	_apply_suit_bonus(team)
	_apply_relics(run, team)
	_apply_pacts(run, team)
	return team


## Cups health and swords bleed per suit figure.
const SUIT_CUP_HEALTH := 2
const SUIT_SWORDS_PER_BLEED := 2


## Suit bonuses of the whole row (coins raise the interest cap in RunState):
## cups +2 health per cup figure on each cup figure; swords 1 bleed on every
## enemy per 2 sword figures; wands 1 burn on the front enemy per wand figure.
static func suit_counts(team: Array) -> Dictionary:
	var counts := {"coins": 0, "cups": 0, "swords": 0, "wands": 0}
	for entry in team:
		for suit in entry.get("suits", [entry.get("suit", "")]):
			if counts.has(suit):
				counts[suit] += 1
	return counts


static func _apply_suit_bonus(team: Array) -> void:
	var counts := suit_counts(team)
	var bleed: int = counts["swords"] / SUIT_SWORDS_PER_BLEED
	var burn: int = counts["wands"]
	for entry in team:
		var suits: Array = entry.get("suits", [entry.get("suit", "")])
		if "cups" in suits:
			entry["bonus_health"] += SUIT_CUP_HEALTH * counts["cups"]
			entry["sources"].append("suit_cups")
		if bleed > 0 and "swords" in suits:
			var bleed_ability := _ability("battle_start", "all_enemies", "apply_bleed", bleed)
			bleed_ability["suit_bonus"] = true
			entry["abilities"].append(bleed_ability)
			entry["sources"].append("suit_swords")
			bleed = 0
		if burn > 0 and "wands" in suits:
			var burn_ability := _ability("battle_start", "front_enemy", "apply_burn", burn)
			burn_ability["suit_bonus"] = true
			entry["abilities"].append(burn_ability)
			entry["sources"].append("suit_wands")
			burn = 0


## Per-figure pact effects (economy and battle-wide pact effects live in
## RunState and the battle options).
static func _apply_pacts(run: RunState, team: Array) -> void:
	for pact in run.pacts:
		for i in team.size():
			var entry: Dictionary = team[i]
			var affected := true
			match pact:
				"blood_pact":
					entry["multipliers"].append(1.5)
					entry["abilities"].append(_ability("battle_start", "self", "lose_health_pct", 10))
				"ash_pact":
					affected = i == 0
					if affected:
						entry["abilities"].append(_ability("battle_start", "self", "apply_burn", 1))
				"death_pact":
					entry["abilities"].append(_ability("on_ally_death", "self", "mult_attack", 1.1))
				"vanguard_pact":
					if i == 0:
						entry["multipliers"].append(1.5)
						var gather := _ability("battle_start", "self", "gather_shields", 1)
						gather["late"] = true
						entry["abilities"].append(gather)
					elif i == team.size() - 1:
						entry["bonus_attack"] -= 1
					else:
						affected = false
				"soul_hunger":
					entry["abilities"].append(_ability("on_enemy_death", "self", "gain_stats", 1))
				_:
					affected = false
			if affected:
				entry["sources"].append(pact)


static func _figure_entry(run: RunState, figure: Dictionary) -> Dictionary:
	var fused := figure.has("fusion")
	var entry := {
		"def": Fusion.definition(run.db, figure) if fused else run.db.figures[figure["def_id"]],
		"level": run.figure_level(figure),
		"bonus_attack": int(figure.get("bonus_attack", 0)),
		"bonus_health": int(figure.get("bonus_health", 0)),
		"multipliers": [],
		"abilities": [],
		"suit": run.figure_suit(figure),
		"suits": run.figure_suits(figure),
		# What is modifying this figure (shown as marks on its card).
		"sources": [],
		# The run figure itself (equipment, blessing ... for the detail panel).
		"figure": figure,
	}
	if fused:
		entry["abilities"].append_array(Fusion.abilities(run.db, figure))
		entry["pierce"] = Fusion.pierces(run.db, figure)
	if int(figure.get("bonus_attack", 0)) != 0 or int(figure.get("bonus_health", 0)) != 0:
		entry["sources"].append("tarot_strength")
	if figure.has("equipment"):
		var mods := Items.equipment_modifiers(run.db, figure["equipment"])
		entry["bonus_attack"] += mods["attack"]
		entry["bonus_health"] += mods["health"]
		entry["multipliers"].append_array(mods["multipliers"])
		entry["abilities"].append_array(mods["abilities"])
	if figure.get("cursed", false):  # cursed well: +3/+3, but cursed every battle
		entry["abilities"].append(_ability("battle_start", "self", "apply_curse", 2))
	# Negative events: plague (-2 health until the act ends), curse fog (next battle).
	if int(figure.get("sick_act", 0)) == run.act:
		entry["bonus_health"] -= RunState.PLAGUE_HEALTH
		entry["sources"].append("plague")
	if run.flags.get("curse_fog", false):
		entry["abilities"].append(_ability("battle_start", "self", "apply_curse", RunState.FOG_CURSE))
		entry["sources"].append("curse_fog")
	match figure.get("blessing", ""):
		"star":
			entry["abilities"].append(_ability("battle_start", "self", "gain_shield", 3))
		"sun":
			entry["multipliers"].append(1.25)
	return entry


static func _apply_relics(run: RunState, team: Array) -> void:
	var royals := team.filter(func(e: Dictionary) -> bool: return e["def"]["rank"] in ["queen", "king", "legend"]).size()
	for relic in run.relics:
		for i in team.size():
			var entry: Dictionary = team[i]
			var affected := true
			match relic:
				"war_chest":
					affected = "coins" in entry["suits"]
					if affected:
						entry["bonus_attack"] += 1
						entry["bonus_health"] += 1
				"blood_chalice":
					affected = "cups" in entry["suits"]
					if affected:
						entry["abilities"].append(_ability("turn_start", "self", "heal", 1))
				"vanguard_banner":
					affected = i == 0
					if affected:
						entry["multipliers"].append(1.5)
				"death_bell":  # only the rearmost figure grows
					affected = i == team.size() - 1
					if affected:
						entry["abilities"].append(_ability("on_ally_death", "self", "gain_attack", 1))
				"royal_court":
					affected = royals > 0
					entry["bonus_health"] += royals
				"eternal_ember":
					affected = "wands" in entry["suits"] and _applies(entry, "apply_burn")
				"whetstone":
					affected = "swords" in entry["suits"] and _applies(entry, "apply_bleed")
				_:
					affected = false
			if affected:
				entry["sources"].append(relic)


## Whether a figure (with its extra abilities) applies a status effect.
static func _applies(entry: Dictionary, effect: String) -> bool:
	var abilities: Array = entry["abilities"].duplicate()
	if entry["def"].has("ability"):
		abilities.append(entry["def"]["ability"])
	for ability in abilities:
		if ability["effect"] == effect:
			return true
	return false


## Relic bonuses on statuses the player applies (read by the simulator).
static func status_bonus(run: RunState) -> Dictionary:
	var bonus := {}
	if "eternal_ember" in run.relics:
		bonus["burn"] = {"wands": 1}
	if "whetstone" in run.relics:
		bonus["bleed"] = {"swords": 2}
	return bonus


## Extra gold after a won battle: relics, pacts and equipment drawbacks.
static func gold_after_win(run: RunState) -> int:
	var extra := 2 if "beggars_bowl" in run.relics else 0
	if "death_pact" in run.pacts:
		extra -= 1
	for figure in run.row:
		if figure == null:
			continue
		if figure.has("equipment"):
			extra += Items.equipment_modifiers(run.db, figure["equipment"])["run_gold"]
		# Münzknecht: gold after every win (also when its ability lives on in a fusion).
		var sources: Array = figure["fusion"]["abilities"] if figure.has("fusion") else [figure["def_id"]]
		for id in sources:
			var win_gold: Array = run.db.figures[id].get("win_gold", [])
			if not win_gold.is_empty():
				extra += int(win_gold[run.figure_level(figure) - 1])
	return extra


static func _ability(trigger: String, target: String, effect: String, value: Variant) -> Dictionary:
	return {"trigger": trigger, "target": target, "effect": effect, "values": [value, value, value]}
