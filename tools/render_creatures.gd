extends SceneTree
## Renders all creature sprites side by side into a PNG (for checking the art).
## Usage: godot --headless -s tools/render_creatures.gd -- out.png

func _init() -> void:
	var ids := ["beggar_ghost", "debt_collector", "coin_thrower", "the_changer", "greedmaw", "vault_warden",
		"greedy_dragon", "mirror_coin", "boss_tax_collector", "boss_golden_wall"]
	var sheet := Image.create(620, 100, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a1418"))
	var x := 4
	for id in ids:
		var art: Dictionary = CreatureArt.build(id)
		var img: Image = art["body"]["tex"].get_image()
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 98 - img.get_height()))
		x += img.get_width() + 4
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var args := OS.get_cmdline_user_args()
	sheet.save_png(args[0] if args.size() > 0 else "creatures.png")
	quit()
