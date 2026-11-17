extends SceneTree
## Duel matrix: every figure against every regular enemy, at levels 1-3,
## without shop or pack luck. The figure fights next to a neutral 2/4
## helper (in front and behind - the better order counts) against two copies
## of the enemy, so support abilities (healing, buffs from behind) work too.
## Prints the share of duels each figure wins, compared within its rank,
## and how dangerous each enemy is. Gold for gold abilities: 10.
## Usage: godot --headless -s tools/duel_matrix.gd -- [gold]

const HELPER := {"id": "helper", "attack": 2, "health": 4}
## A figure this many points above / below its rank's average is flagged.
const OUTLIER := 15.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var gold := int(args[0]) if args.size() > 0 else 10
	var db := ContentDb.load_default()
	var enemies: Array = db.regular_enemies()
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var figures: Array = db.figures.values()
	figures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var figure_rows := {}
	var enemy_wins := {}
	for figure in figures:
		var per_level: Array = []
		for level in [1, 2, 3]:
			var won := 0
			for enemy in enemies:
				var foes := [{"def": enemy, "level": level}, {"def": enemy, "level": level}]
				var me := {"def": figure, "level": level}
				var helper := {"def": HELPER, "level": level}
				var a := BattleSimulator.simulate([me, helper], foes, gold)
				var b := BattleSimulator.simulate([helper, me], foes, gold)
				if a["victory"] or b["victory"]:
					won += 1
				else:
					enemy_wins[enemy["id"]] = enemy_wins.get(enemy["id"], 0) + 1
			per_level.append(100.0 * won / enemies.size())
		figure_rows[figure["id"]] = {"rank": String(figure["rank"]), "levels": per_level,
			"avg": (per_level[0] + per_level[1] + per_level[2]) / 3.0}
	print("=== Figuren: gewonnene Duelle je Stufe (gegen %d Gegner, Gold %d) ===" % [enemies.size(), gold])
	for rank in ["page", "knight", "queen", "king", "legend"]:
		var ids: Array = figure_rows.keys().filter(func(id: String) -> bool: return figure_rows[id]["rank"] == rank)
		if ids.is_empty():
			continue
		var mean := 0.0
		for id in ids:
			mean += figure_rows[id]["avg"]
		mean /= ids.size()
		ids.sort_custom(func(a: String, b: String) -> bool: return figure_rows[a]["avg"] > figure_rows[b]["avg"])
		print("-- %s (Schnitt %.0f %%) --" % [rank, mean])
		for id in ids:
			var r: Dictionary = figure_rows[id]
			var flag := ""
			if r["avg"] > mean + OUTLIER:
				flag = "  << stark"
			elif r["avg"] < mean - OUTLIER:
				flag = "  << schwach"
			print("  %-20s  I %3.0f %%  II %3.0f %%  III %3.0f %%  Ø %3.0f %%%s" % [id, r["levels"][0], r["levels"][1], r["levels"][2], r["avg"], flag])
	print("=== Gegner: gewonnene Duelle gegen alle Figuren und Stufen (Kosten) ===")
	var total := figures.size() * 3
	var ids: Array = enemies.map(func(e: Dictionary) -> String: return e["id"])
	ids.sort_custom(func(a: String, b: String) -> bool: return enemy_wins.get(a, 0) > enemy_wins.get(b, 0))
	for id in ids:
		print("  %-20s %3.0f %%   Kosten %d" % [id, 100.0 * enemy_wins.get(id, 0) / total, int(db.enemies[id]["cost"])])
	quit()
