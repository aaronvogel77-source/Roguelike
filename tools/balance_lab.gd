class_name BalanceLab
extends RefCounted
## Shared helpers of the balancing tools: running batches of bot runs and
## the statistics around them (95 % intervals, significance of a difference).
##
## A batch is deterministic: run i of a strategy always uses seed
## seed_offset + i, so two batches with the same settings differ only by
## what was changed in between.

const STATIONS := ["A1 K1", "A1 K2", "A1 K3", "A2 K1", "A2 K2", "A2 K3"]
const STATION_NAMES := {"A1 K1": "Akt 1 klein", "A1 K2": "Akt 1 groß", "A1 K3": "Akt 1 Boss",
	"A2 K1": "Akt 2 klein", "A2 K2": "Akt 2 groß", "A2 K3": "Akt 2 Boss"}


## Plays `runs` runs per strategy. options go to RunState.new_run (e.g.
## {"locked": {...}}); extra keys "start_relics" / "start_pacts" are given
## to the bot right at the start (BalanceBot.play).
## Returns {"runs", "wins", "bots": {name: {"runs", "wins"}}, "stations": {name: {"n", "won"}}}.
static func batch(db: ContentDb, runs: int, strategies: Array = [], options: Dictionary = {},
		seed_offset: int = 0) -> Dictionary:
	if strategies.is_empty():
		strategies = BalanceBot.STRATEGIES.keys()
	var result := {"runs": 0, "wins": 0, "bots": {}, "stations": {}}
	for strategy in strategies:
		var bot_stats := {"runs": 0, "wins": 0}
		for i in runs:
			var seed_value := seed_offset + i + 1
			var bot := BalanceBot.create(strategy, seed_value)
			var run := bot.play(db, seed_value, options)
			var won := run.stage == RunState.Stage.WON
			bot_stats["runs"] += 1
			bot_stats["wins"] += 1 if won else 0
			for b in bot.log["battles"]:
				var st: Dictionary = result["stations"].get(b["station"], {"n": 0, "won": 0})
				st["n"] += 1
				st["won"] += 1 if b["won"] else 0
				result["stations"][b["station"]] = st
		result["bots"][strategy] = bot_stats
		result["runs"] += bot_stats["runs"]
		result["wins"] += bot_stats["wins"]
	return result


## 95 % Wilson interval of k successes in n tries, as [low, high] in 0..1.
static func wilson(k: int, n: int) -> Array:
	if n <= 0:
		return [0.0, 1.0]
	var z := 1.96
	var p := float(k) / n
	var denom := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / denom
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return [maxf(centre - half, 0.0), minf(centre + half, 1.0)]


## "77.0 % (74–80)": rate with its 95 % interval.
static func rate(k: int, n: int) -> String:
	if n <= 0:
		return "   –   "
	var ci := wilson(k, n)
	return "%5.1f %% (%2.0f–%2.0f)" % [100.0 * k / n, 100.0 * ci[0], 100.0 * ci[1]]


## z value of the difference between two rates (two-proportion test);
## |z| >= 1.96 means the difference is very likely real (95 %).
static func z_score(k1: int, n1: int, k2: int, n2: int) -> float:
	if n1 <= 0 or n2 <= 0:
		return 0.0
	var p1 := float(k1) / n1
	var p2 := float(k2) / n2
	var pooled := float(k1 + k2) / (n1 + n2)
	var se := sqrt(pooled * (1.0 - pooled) * (1.0 / n1 + 1.0 / n2))
	return 0.0 if se == 0.0 else (p2 - p1) / se


## "+4.2 Pkt *" - difference in percentage points, starred when significant.
static func delta(k1: int, n1: int, k2: int, n2: int) -> String:
	if n1 <= 0 or n2 <= 0:
		return "   –"
	var d := 100.0 * (float(k2) / n2 - float(k1) / n1)
	var z := z_score(k1, n1, k2, n2)
	return "%+5.1f Pkt %s" % [d, "*" if absf(z) >= 1.96 else " "]


static func station_rate(result: Dictionary, station: String) -> float:
	var st: Dictionary = result["stations"].get(station, {"n": 0, "won": 0})
	return float(st["won"]) / st["n"] if st["n"] > 0 else -1.0
