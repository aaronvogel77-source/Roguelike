extends SceneTree
## Renders example fusion forms (main body + partner weapon, F1-F3, pure and
## mixed) into a PNG sheet. Usage: godot --headless -s tools/render_fusions.gd -- out.png

const EXAMPLES := [
	["executioner"], ["executioner", "blood_drinker"], ["executioner", "blood_drinker", "spark_bearer"],
	["executioner", "blood_drinker", "spark_bearer", "gold_armored"],
	["king_midas"], ["king_midas", "spark_bearer"], ["coin_squire", "king_midas", "gold_armored", "golden_scales"],
	["the_judge", "clear_blade", "executioner", "blade_apprentice"],
	["altar_server", "drowned_king"], ["drowned_king", "chalice_of_return", "altar_server", "blood_drinker"],
	["enraged_one", "ash_king", "mistress_of_embers", "spark_bearer"], ["gold_armored", "the_judge", "drowned_king"],
]


func _init() -> void:
	var db := ContentDb.load_default()
	var renderer: Script = load("res://tools/render_figures.gd")
	var cell := Vector2i(70, 100)
	var sheet := Image.create(cell.x * 6, cell.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e6d6b4"))
	for i in EXAMPLES.size():
		var parts: Array = EXAMPLES[i]
		var definition: Dictionary = db.figures[parts[0]]
		if parts.size() > 1:
			var figure := {"uid": 1, "def_id": parts[0], "xp": 0, "fusion": {"parts": parts,
				"suits": parts.map(func(id: String) -> String: return String(db.figures[id]["suit"])),
				"abilities": [], "attack": 1, "health": 1, "partner": parts[1]}}
			definition = Fusion.definition(db, figure)
		var built := FigureArt.build(FigureArt.look_for_figure(definition))
		renderer.new()._draw(sheet, built, Vector2i((i % 6) * cell.x + cell.x / 2, (i / 6) * cell.y + cell.y - 6))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var args := OS.get_cmdline_user_args()
	sheet.save_png(args[0] if args.size() > 0 else "fusions.png")
	quit()
