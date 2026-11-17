class_name Fusion
extends RefCounted
## Fusion rules (pure data helpers, no UI).
##
## A fused figure in the row: {"uid", "def_id" (main figure), "xp",
##   "fusion": {"parts": [def ids], "suits": [suit per part],
##              "abilities": [def ids whose ability is kept], "attack", "health"}}
## Fusion stage = parts - 1 (F1 = 2 figures ... F3 = 4). On F3 the master
## ability of the suit combination joins. Secret recipes turn a specific pair
## into a handmade figure ({"def_id": recipe, "recipe_parts": [a, b]}), which
## cannot be fused any further.


## What a row figure brings into a fusion.
static func parts_of(run: RunState, figure: Dictionary) -> Dictionary:
	if figure.has("fusion"):
		var data: Dictionary = figure["fusion"].duplicate(true)
		data["final"] = false
		return data
	var definition: Dictionary = run.db.figures[figure["def_id"]]
	return {
		"parts": [figure["def_id"]],
		"suits": [run.figure_suit(figure)],
		"abilities": [figure["def_id"]] if definition.has("ability") else [],
		"attack": int(definition["attack"]),
		"health": int(definition["health"]),
		"final": definition.get("recipe", false),
	}


static func stage_of(figure: Dictionary) -> int:
	if figure.has("fusion"):
		return figure["fusion"]["parts"].size() - 1
	return 0


## The recipe result for two plain figures, or "".
static func recipe_for(db: ContentDb, a: String, b: String) -> String:
	for recipe in db.fusion["recipes"]:
		var parts: Array = recipe["parts"]
		if (parts[0] == a and parts[1] == b) or (parts[0] == b and parts[1] == a):
			return recipe["result"]
	return ""


## Everything about a planned fusion; "reason" is "" when it is possible.
## Keys: reason, recipe, stage, attack, health, suits, parts, candidates
## (def ids whose ability can be kept), keep (how many may stay), master, cost.
static func preview(run: RunState, main_index: int, partner_index: int) -> Dictionary:
	var result := {"reason": ""}
	if main_index == partner_index or main_index < 0 or partner_index < 0 \
			or main_index >= run.row.size() or partner_index >= run.row.size() \
			or run.row[main_index] == null or run.row[partner_index] == null:
		result["reason"] = "pick"
		return result
	var main: Dictionary = run.row[main_index]
	var partner: Dictionary = run.row[partner_index]
	var a := parts_of(run, main)
	var b := parts_of(run, partner)
	if a["final"] or b["final"] or main.has("recipe_parts") or partner.has("recipe_parts"):
		result["reason"] = "final"
		return result
	var parts: Array = a["parts"] + b["parts"]
	if parts.size() > int(run.db.fusion["max_parts"]):
		result["reason"] = "too_many"
		return result
	result["parts"] = parts
	result["suits"] = a["suits"] + b["suits"]
	result["stage"] = parts.size() - 1
	var costs: Array = run.db.fusion["altar_costs"]
	result["cost"] = int(costs[mini(result["stage"], costs.size() - 1)])
	# Secret recipe: two plain figures of a recipe pair.
	if a["parts"].size() == 1 and b["parts"].size() == 1:
		var recipe := recipe_for(run.db, a["parts"][0], b["parts"][0])
		if recipe != "":
			var definition: Dictionary = run.db.figures[recipe]
			result["recipe"] = recipe
			result["stage"] = 1
			result["cost"] = int(costs[1])
			result["attack"] = int(definition["attack"])
			result["health"] = int(definition["health"])
			result["candidates"] = []
			result["keep"] = 0
			result["master"] = ""
			return result
	result["recipe"] = ""
	var bonus := int(run.db.fusion["stat_bonus"])
	result["attack"] = maxi(int(a["attack"]), int(b["attack"])) + bonus
	result["health"] = maxi(int(a["health"]), int(b["health"])) + bonus
	result["candidates"] = a["abilities"] + b["abilities"]
	result["keep"] = mini(result["candidates"].size(), int(run.db.fusion["max_abilities"]))
	var master := master_for(run.db, result["suits"]) if result["stage"] >= 3 else {}
	result["master"] = master.get("id", "")
	return result


## Master ability of a suit combination: a suit present 3+ times counts pure,
## otherwise the two most frequent suits (ties: the earlier fused one).
static func master_for(db: ContentDb, suits: Array) -> Dictionary:
	var counts := {}
	var order: Array = []
	for suit in suits:
		if not counts.has(suit):
			order.append(suit)
		counts[suit] = counts.get(suit, 0) + 1
	var first := order.duplicate()
	order.sort_custom(func(x: String, y: String) -> bool:
		if counts[x] != counts[y]:
			return counts[x] > counts[y]
		return first.find(x) < first.find(y))
	var pair: Array = [order[0], order[0]]
	if counts[order[0]] < 3 and order.size() > 1:
		pair = [order[0], order[1]]
	for master in db.fusion["masters"]:
		var suits_of: Array = master["suits"]
		if (suits_of[0] == pair[0] and suits_of[1] == pair[1]) or (suits_of[0] == pair[1] and suits_of[1] == pair[0]):
			return master
	return {}


static func master_by_id(db: ContentDb, id: String) -> Dictionary:
	for master in db.fusion["masters"]:
		if master["id"] == id:
			return master
	return {}


## The built definition a fused figure fights with (and is shown as).
static func definition(db: ContentDb, figure: Dictionary) -> Dictionary:
	var data: Dictionary = figure["fusion"]
	var main: Dictionary = db.figures[figure["def_id"]]
	var stage: int = data["parts"].size() - 1
	var master := master_for(db, data["suits"]) if stage >= 3 else {}
	# Name: first part from the (latest) partner, second from the main figure,
	# e.g. Henker + Bluttrinker -> "Blut-Henker".
	var partner: String = data.get("partner", data["parts"][1])
	return {
		"id": figure["def_id"], "rank": main["rank"], "suit": data["suits"][0],
		"attack": int(data["attack"]), "health": int(data["health"]),
		"fusion": {"stage": stage, "suits": data["suits"].duplicate(), "parts": data["parts"].duplicate(),
			"abilities": data["abilities"].duplicate(), "master": master.get("id", "")},
		"fusion_name": TranslationServer.translate("NAME_STEM_" + partner.to_upper()) + "-"
			+ TranslationServer.translate("NAME_CORE_" + String(figure["def_id"]).to_upper()),
	}


## Abilities a fused figure fights with: the kept ones plus the master ability.
static func abilities(db: ContentDb, figure: Dictionary) -> Array:
	var result: Array = []
	for id in figure["fusion"]["abilities"]:
		var source: Dictionary = db.figures[id]
		if source.has("ability"):
			result.append(source["ability"])
		result.append_array(source.get("extra_abilities", []))
	var data: Dictionary = figure["fusion"]
	if data["parts"].size() - 1 >= 3:
		result.append_array(master_for(db, data["suits"]).get("abilities", []))
	return result


## Whether the fused figure's attacks pierce (master or a kept ace ability).
static func pierces(db: ContentDb, figure: Dictionary) -> bool:
	var data: Dictionary = figure["fusion"]
	for id in data["abilities"]:
		if db.figures[id].get("pierce", false):
			return true
	if data["parts"].size() - 1 >= 3:
		return master_for(db, data["suits"]).get("pierce", false)
	return false
