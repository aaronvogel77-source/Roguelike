extends SceneTree
## Renders every player figure (rest pose, arms down) into a PNG sheet for
## checking the art. Usage: godot --headless -s tools/render_figures.gd -- out.png

func _init() -> void:
	var db := ContentDb.load_default()
	var ids: Array = ["coin_squire", "gold_armored", "golden_scales", "king_midas", "spark_bearer", "enraged_one",
		"mistress_of_embers", "ash_king", "altar_server", "blood_drinker", "chalice_of_return", "drowned_king",
		"blade_apprentice", "executioner", "clear_blade", "the_judge", "ace_of_coins", "ace_of_wands", "ace_of_cups",
		"ace_of_swords", "midas_scales", "ash_flood_king"]
	var cell := Vector2i(70, 96)
	var sheet := Image.create(cell.x * 12, cell.y * 2 + 0, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e6d6b4"))
	for i in ids.size():
		FigureArt.gold_hint = 0
		var parts := FigureArt.build(FigureArt.look_for_figure(db.figures[ids[i]]))
		_draw(sheet, parts, Vector2i((i % 12) * cell.x + cell.x / 2, (i / 12) * cell.y + cell.y - 6))
	# Gold-Armored with 0 / 8 / 15 / 30 gold
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var args := OS.get_cmdline_user_args()
	sheet.save_png(args[0] if args.size() > 0 else "figures.png")
	var bulk := Image.create(cell.x * 4, cell.y, false, Image.FORMAT_RGBA8)
	bulk.fill(Color("e6d6b4"))
	for j in 4:
		FigureArt.gold_hint = [0, 8, 15, 30][j]
		_draw(bulk, FigureArt.build(FigureArt.look_for_figure(db.figures["gold_armored"])), Vector2i(j * cell.x + cell.x / 2, cell.y - 6))
	bulk.resize(bulk.get_width() * 3, bulk.get_height() * 3, Image.INTERPOLATE_NEAREST)
	bulk.save_png((args[0] if args.size() > 0 else "figures.png").replace(".png", "_bulk.png"))
	quit()


func _blit(sheet: Image, part: Dictionary, at: Vector2i) -> void:
	var img: Image = part["tex"].get_image()
	sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at - Vector2i(part["pivot"]))


func _draw(sheet: Image, p: Dictionary, feet: Vector2i) -> void:
	var d: Dictionary = p["dim"]
	var hip := feet + Vector2i(0, -int(d["leg"]))
	var neck := hip + Vector2i(0, -int(p["torso_h"]))
	var half := int(d["tw"]) / 2
	if p.has("cape"):
		_blit(sheet, p["cape"], neck + Vector2i(-half + 4, 1))
	_blit(sheet, p["armB"], neck + Vector2i(-half + 3, 3))
	if p.has("shield"):
		_blit(sheet, p["shield"], neck + Vector2i(-half + 3, 3 + int(p["arm_len"]) - 2))
	_blit(sheet, p["legB"], hip + Vector2i(-2, 0))
	_blit(sheet, p["legF"], hip + Vector2i(1, 0))
	_blit(sheet, p["torso"], hip)
	# Same order as on the stage: the weapon behind the head, the arm in front.
	var shoulder := neck + Vector2i(half - 2, 3)
	var small: bool = p["weapon"]["tex"].get_height() <= 18
	if not small:
		_blit(sheet, p["weapon"], shoulder + Vector2i(0, int(p["arm_len"])))
	_blit(sheet, p["armF"], shoulder)
	if small:
		_blit(sheet, p["weapon"], shoulder + Vector2i(0, int(p["arm_len"])))
	_blit(sheet, p["head"], neck + Vector2i(1, 1))  # faces are never covered
