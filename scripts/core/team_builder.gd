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
	_apply_relics(run, team)
	return team


static func _figure_entry(run: RunState, figure: Dictionary) -> Dictionary:
	var entry := {
		"def": run.db.figures[figure["def_id"]],
		"level": run.figure_level(figure),
		"bonus_attack": int(figure.get("bonus_attack", 0)),
		"bonus_health": int(figure.get("bonus_health", 0)),
		"multipliers": [],
		"abilities": [],
		"suit": run.figure_suit(figure),
	}
	if figure.has("equipment"):
		var mods := Items.equipment_modifiers(run.db, figure["equipment"])
		entry["bonus_attack"] += mods["attack"]
		entry["bonus_health"] += mods["health"]
		entry["multipliers"].append_array(mods["multipliers"])
		entry["abilities"].append_array(mods["abilities"])
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
			match relic:
				"war_chest":
					if entry["suit"] == "coins":
						entry["bonus_attack"] += 1
				"blood_chalice":
					if entry["suit"] == "cups":
						entry["abilities"].append(_ability("turn_start", "self", "heal", 1))
				"vanguard_banner":
					if i == 0:
						entry["multipliers"].append(1.5)
				"death_bell":
					entry["abilities"].append(_ability("on_ally_death", "self", "gain_attack", 1))
				"royal_court":
					entry["bonus_health"] += royals


## Relic bonuses on statuses the player applies (read by the simulator).
static func status_bonus(run: RunState) -> Dictionary:
	var bonus := {}
	if "eternal_ember" in run.relics:
		bonus["burn"] = {"all": 1}
	if "whetstone" in run.relics:
		bonus["bleed"] = {"swords": 1}
	return bonus


## Extra gold after a won battle: relics plus equipment drawbacks.
static func gold_after_win(run: RunState) -> int:
	var extra := 1 if "beggars_bowl" in run.relics else 0
	for figure in run.row:
		if figure != null and figure.has("equipment"):
			extra += Items.equipment_modifiers(run.db, figure["equipment"])["run_gold"]
	return extra


static func _ability(trigger: String, target: String, effect: String, value: Variant) -> Dictionary:
	return {"trigger": trigger, "target": target, "effect": effect, "values": [value, value, value]}
