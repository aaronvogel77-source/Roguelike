extends SceneTree
## Balancing report: every bot strategy plays many runs; prints win rates,
## where runs end, and which figures, relics, pacts, masters and bosses stand out.
## Every rate comes with its 95 % interval; --compare shows the change
## against an earlier report (* = the change is very likely real).
## Usage: godot --headless -s tools/balance_report.gd -- [runs per bot] [--out=new.json] [--compare=old.json]

var _old: Dictionary = {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 120
	var out_path := ""
	for arg in args:
		if arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--compare="):
			var text := FileAccess.get_file_as_string(arg.substr(10))
			var parsed: Variant = JSON.parse_string(text)
			_old = parsed if parsed is Dictionary else {}
		elif arg.is_valid_int():
			runs = int(arg)
	var db := ContentDb.load_default()
	var report := {"runs_per_bot": runs, "bots": {}, "figures": {}, "relics": {}, "pacts": {}, "masters": {}, "deaths": {}, "bosses": {}}
	for strategy in BalanceBot.STRATEGIES:
		var stats := {"wins": 0, "battles": 0, "acts": {}, "fusions": 0, "rerolls": 0, "sold": 0, "packs": 0,
			"tarots": 0, "gold_end": 0, "power_end": 0.0}
		for seed_value in range(1, runs + 1):
			var bot := BalanceBot.create(strategy, seed_value)
			var run := bot.play(db, seed_value)
			var won := run.stage == RunState.Stage.WON
			stats["wins"] += 1 if won else 0
			stats["battles"] += run.battles_won
			var where := "Sieg" if won else "Akt %d %s" % [run.act, ["klein", "groß", "Boss"][run.fight]]
			stats["acts"][where] = stats["acts"].get(where, 0) + 1
			for key in ["fusions", "rerolls", "sold", "packs", "tarots"]:
				stats[key] += bot.log[key]
			stats["gold_end"] += run.gold
			for b in bot.log["battles"]:
				var st: Dictionary = report.get("stations", {})
				if not st.has(b["station"]):
					st[b["station"]] = {"n": 0, "won": 0, "mine": 0.0, "theirs": 0.0, "filled": 0, "diff": [0, 0, 0], "diff_won": [0, 0, 0]}
				var e: Dictionary = st[b["station"]]
				e["n"] += 1
				e["won"] += 1 if b["won"] else 0
				e["mine"] += b["mine"]
				e["theirs"] += b["theirs"]
				e["filled"] += b["filled"]
				e["diff"][clampi(b["difficulty"], 0, 2)] += 1
				e["diff_won"][clampi(b["difficulty"], 0, 2)] += 1 if b["won"] else 0
				report["stations"] = st
			if not won:
				report["deaths"][where] = report["deaths"].get(where, 0) + 1
				var boss := String(run.chosen_enemy.get("boss_id", ""))
				if boss != "":
					report["bosses"][boss] = report["bosses"].get(boss, 0) + 1
			for figure in run.row:
				if figure == null:
					continue
				var ids: Array = figure["fusion"]["parts"] if figure.has("fusion") else [figure["def_id"]]
				for id in ids:
					_count(report["figures"], id, won)
				if figure.has("fusion"):
					var master := String(Fusion.definition(db, figure)["fusion"]["master"])
					if master != "":
						_count(report["masters"], master, won)
			for id in run.relics:
				_count(report["relics"], id, won)
			for id in run.pacts:
				_count(report["pacts"], id, won)
		report["bots"][strategy] = stats
	_print(report, runs)
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	quit()


func _count(table: Dictionary, id: String, won: bool) -> void:
	if not table.has(id):
		table[id] = {"seen": 0, "wins": 0}
	table[id]["seen"] += 1
	table[id]["wins"] += 1 if won else 0


func _print(report: Dictionary, runs: int) -> void:
	print("=== Bots (%d Runs je Bot) ===" % runs)
	for strategy in report["bots"]:
		var s: Dictionary = report["bots"][strategy]
		var change := ""
		if _old.get("bots", {}).has(strategy):
			var o: Dictionary = _old["bots"][strategy]
			change = "  " + BalanceLab.delta(int(o["wins"]), int(_old["runs_per_bot"]), int(s["wins"]), runs)
		print("%-15s Siege %s%s  Kämpfe Ø %.1f  Fusionen Ø %.2f  Packs Ø %.1f  Verkauft Ø %.1f  Neu gewürfelt Ø %.1f  Gold am Ende Ø %.0f" % [
			strategy, BalanceLab.rate(int(s["wins"]), runs), change, float(s["battles"]) / runs, float(s["fusions"]) / runs,
			float(s["packs"]) / runs, float(s["sold"]) / runs, float(s["rerolls"]) / runs, float(s["gold_end"]) / runs])
		var keys: Array = s["acts"].keys()
		keys.sort()
		var parts: Array = keys.map(func(k: String) -> String: return "%s %d" % [k, s["acts"][k]])
		print("                ", ", ".join(parts))
	for table in ["figures", "relics", "pacts", "masters"]:
		print("=== %s (gesehen am Run-Ende / Siegquote) ===" % table)
		var rows: Array = report[table].keys()
		rows.sort_custom(func(a: String, b: String) -> bool: return report[table][a]["seen"] > report[table][b]["seen"])
		for id in rows:
			var e: Dictionary = report[table][id]
			print("  %-22s %5d   %5.1f %%" % [id, e["seen"], 100.0 * e["wins"] / maxi(1, e["seen"])])
	print("=== Stationen (alle Bots): Kämpfe, Siegquote, Ø eigene Stärke, Ø Gegnerstärke, Ø Figuren, Wahl leicht/mittel/schwer ===")
	var st: Dictionary = report.get("stations", {})
	var names: Array = st.keys()
	names.sort()
	for k in names:
		var e: Dictionary = st[k]
		var change := ""
		if _old.get("stations", {}).has(k):
			var o: Dictionary = _old["stations"][k]
			change = "  " + BalanceLab.delta(int(o["won"]), int(o["n"]), int(e["won"]), int(e["n"]))
		print("  %-7s %5d  %s%s  %7.0f  %7.0f  %.1f  %s" % [k, e["n"], BalanceLab.rate(int(e["won"]), int(e["n"])), change,
			e["mine"] / e["n"], e["theirs"] / e["n"], float(e["filled"]) / e["n"], str(e["diff"])])
		# Win rate per chosen difficulty (only where it was chosen).
		var parts: Array = []
		for d in 3:
			var n := int(e["diff"][d])
			if n > 0 and not k.ends_with("K3"):
				parts.append("%s %s" % [["leicht", "mittel", "schwer"][d], BalanceLab.rate(int(e["diff_won"][d]), n)])
		if not parts.is_empty():
			print("            ", "  ·  ".join(parts))
	print("=== Niederlagen nach Ort ===")
	for k in report["deaths"]:
		print("  %-16s %d" % [k, report["deaths"][k]])
	print("=== Niederlagen gegen Bosse ===")
	for k in report["bosses"]:
		print("  %-16s %d" % [k, report["bosses"][k]])
