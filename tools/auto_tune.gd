extends SceneTree
## Auto-tuning: searches enemy values station by station (in game order, since
## later stations depend on earlier ones) until all bots together win inside
## the target corridor of tools/balance_targets.json. Bisection: a higher
## value always means stronger enemies. Nothing is written to the game files -
## the result is a proposal with the values and the measured rates.
## Usage: godot --headless -s tools/auto_tune.gd -- [runs per bot for act 1] [runs per bot for act 2] [station prefix, e.g. A2]

const STEPS := 6

## Knob: station it steers, range, and how to set it.
var _knobs := [
	{"name": "Akt 1 klein: Budget", "station": "A1 K1", "lo": 1.5, "hi": 5.0, "set": func(v: float) -> void: EnemyGenerator.FIGHT_BUDGET[0] = v},
	{"name": "Akt 1 groß: Budget", "station": "A1 K2", "lo": 3.0, "hi": 9.0, "set": func(v: float) -> void: EnemyGenerator.FIGHT_BUDGET[1] = v},
	{"name": "Akt 1 Boss: Leben Steuereintreiber", "station": "A1 K3", "lo": 10.0, "hi": 30.0, "boss": "boss_tax_collector", "stat": "health"},
	{"name": "Akt 2: Wachstum je Akt", "station": "A2 K2", "lo": 2.5, "hi": 5.0, "set": func(v: float) -> void: EnemyGenerator.ACT_GROWTH = v},
	{"name": "Akt 2 klein: Zusatzfaktor", "station": "A2 K1", "lo": 1.0, "hi": 2.5, "set": func(v: float) -> void: EnemyGenerator.LATE_SMALL_FACTOR = v},
	{"name": "Akt 2 Boss: Gefolge-Budget", "station": "A2 K3", "lo": 10.0, "hi": 70.0, "set": func(v: float) -> void: EnemyGenerator.BOSS_RETINUE[1] = v},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs_act1 := int(args[0]) if args.size() > 0 else 20
	var runs_act2 := int(args[1]) if args.size() > 1 else 50
	var only := String(args[2]) if args.size() > 2 else ""
	var db := ContentDb.load_default()
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/balance_targets.json"))
	var corridors: Dictionary = targets["stations"]
	print("=== Auto-Tuning (Ziele aus tools/balance_targets.json) ===")
	for knob in _knobs:
		var station: String = knob["station"]
		if only != "" and not station.begins_with(only):
			continue
		var corridor: Array = corridors[station]
		var goal := (float(corridor[0]) + float(corridor[1])) / 200.0
		var runs := runs_act1 if station.begins_with("A1") else runs_act2
		var lo: float = knob["lo"]
		var hi: float = knob["hi"]
		var start := _knob_value(db, knob)
		var best_value := start
		var best_gap := INF
		var best_rate := -1.0
		var tried: Array = []
		var value := start
		for step in STEPS:
			_set_knob(db, knob, value)
			var result := BalanceLab.batch(db, runs)
			var r := BalanceLab.station_rate(result, station)
			tried.append("%.2f→%s" % [value, "–" if r < 0 else "%.0f %%" % (100.0 * r)])
			if r >= 0 and absf(r - goal) < best_gap:
				best_gap = absf(r - goal)
				best_value = value
				best_rate = r
			if r < 0:
				break
			# Too easy (bots win too often) -> stronger enemies -> higher value.
			if r > goal:
				lo = value
			else:
				hi = value
			value = (lo + hi) / 2.0
		_set_knob(db, knob, best_value)
		var inside := best_rate * 100.0 >= float(corridor[0]) and best_rate * 100.0 <= float(corridor[1])
		print("%-36s %s  jetzt %.2f → Vorschlag %.2f  (%.0f %%, Ziel %d–%d %%)%s" % [knob["name"], station, start, best_value,
			100.0 * best_rate, corridor[0], corridor[1], "" if inside else "  NICHT ERREICHT"])
		print("     versucht: ", ", ".join(tried))
	# Final check with all proposals together.
	var final := BalanceLab.batch(db, runs_act2)
	print("=== Kontrolle mit allen Vorschlägen (%d Runs je Bot) ===" % runs_act2)
	for station in BalanceLab.STATIONS:
		var st: Dictionary = final["stations"].get(station, {"n": 0, "won": 0})
		var corridor: Array = corridors[station]
		var r := BalanceLab.station_rate(final, station) * 100.0
		var ok := r >= float(corridor[0]) and r <= float(corridor[1])
		print("  %-7s %-12s %s  Ziel %d–%d %%  %s" % [station, BalanceLab.STATION_NAMES[station], BalanceLab.rate(st["won"], st["n"]),
			corridor[0], corridor[1], "ok" if ok else "daneben"])
	var won: Array = targets["runs_won"]
	print("  Runs gewonnen: %s  Ziel %d–%d %%" % [BalanceLab.rate(final["wins"], final["runs"]), won[0], won[1]])
	quit()


func _knob_value(db: ContentDb, knob: Dictionary) -> float:
	if knob.has("boss"):
		return float(db.enemies[knob["boss"]][knob["stat"]])
	match knob["station"]:
		"A1 K1": return float(EnemyGenerator.FIGHT_BUDGET[0])
		"A1 K2": return float(EnemyGenerator.FIGHT_BUDGET[1])
		"A2 K2": return EnemyGenerator.ACT_GROWTH
		"A2 K1": return EnemyGenerator.LATE_SMALL_FACTOR
		"A2 K3": return float(EnemyGenerator.BOSS_RETINUE[1])
	return 0.0


func _set_knob(db: ContentDb, knob: Dictionary, value: float) -> void:
	if knob.has("boss"):
		db.enemies[knob["boss"]][knob["stat"]] = int(round(value))
		return
	knob["set"].call(value)
