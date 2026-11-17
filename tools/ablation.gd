extends SceneTree
## Card strength test: how much does one card change the win rate?
##  - Figures: all bots play without the figure (it never shows up anywhere).
##    A big drop means the card carries runs; a rise means it is a trap.
##  - Relics and pacts: all bots start with the card (they are rare now, so
##    leaving them out would change almost nothing).
## Every run uses the same seeds as the baseline, so only the card differs.
## Usage: godot --headless -s tools/ablation.gd -- [runs per bot] [figures|relics|pacts|all]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 30
	var only := String(args[1]) if args.size() > 1 else "all"
	var db := ContentDb.load_default()
	var base := BalanceLab.batch(db, runs)
	print("=== Basis: %s Siege über %d Runs (%d je Bot) ===" % [BalanceLab.rate(base["wins"], base["runs"]), base["runs"], runs])
	var rows: Array = []
	if only in ["figures", "all"]:
		var ids: Array = db.figures.keys().filter(func(id: String) -> bool: return not db.figures[id].get("recipe", false))
		ids.sort()
		for id in ids:
			var result := BalanceLab.batch(db, runs, [], {"locked": {"banned_figures": [id]}})
			rows.append(["ohne", id, String(db.figures[id]["rank"]), result])
	if only in ["relics", "all"]:
		for relic in db.items["relics"]:
			var result := BalanceLab.batch(db, runs, [], {"start_relics": [relic["id"]]})
			rows.append(["mit", relic["id"], "relic", result])
	if only in ["pacts", "all"]:
		for pact in db.items["pacts"]:
			var result := BalanceLab.batch(db, runs, [], {"start_pacts": [pact]})
			rows.append(["mit", pact, "pact", result])
	# "Strength" = how much the card adds: drop without it, or gain with it.
	rows.sort_custom(func(a: Array, b: Array) -> bool: return _strength(a, base) > _strength(b, base))
	print("=== Karten nach Stärke (Siegquote mit/ohne Karte, Änderung zur Basis, * = sicher) ===")
	for row in rows:
		var result: Dictionary = row[3]
		print("  %-4s %-20s %-7s %s  %s  Stärke %+5.1f" % [row[0], row[1], row[2], BalanceLab.rate(result["wins"], result["runs"]),
			BalanceLab.delta(base["wins"], base["runs"], result["wins"], result["runs"]), _strength(row, base)])
	quit()


## Percentage points the card is worth: baseline - without, or with - baseline.
static func _strength(row: Array, base: Dictionary) -> float:
	var result: Dictionary = row[3]
	var d: float = 100.0 * (float(result["wins"]) / result["runs"] - float(base["wins"]) / base["runs"])
	return -d if row[0] == "ohne" else d
