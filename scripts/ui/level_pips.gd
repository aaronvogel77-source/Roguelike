class_name LevelPips
extends Control
## Progress to the next level as three diamonds under a figure: a duplicate
## fills one diamond, a won battle a third of one. At level 3 three gold stars.

var progress := 0.0  # 0..3 diamonds
var maxed := false
var color := Color("8fd8ff")


static func create(figure: Dictionary, run: RunState) -> LevelPips:
	var pips := LevelPips.new()
	var level := run.figure_level(figure)
	pips.maxed = level >= 3
	if not pips.maxed:
		var start: int = RunState.XP_FOR_LEVEL[level - 1]
		pips.progress = (int(figure["xp"]) - start) / 3.0
	pips.custom_minimum_size = Vector2(UnitCard.CARD_SIZE.x, 20)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pips


func _draw() -> void:
	var gap := 22.0
	var start := size.x / 2 - gap
	for i in 3:
		var center := Vector2(start + i * gap, size.y / 2)
		var r := 7.0
		var shape := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
		if maxed:
			draw_colored_polygon(shape, Palette.GOLD)
			draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]), Color(0.3, 0.2, 0.05), 1.5)
			continue
		draw_colored_polygon(shape, Color(0, 0, 0, 0.45))
		var fill := clampf(progress - i, 0.0, 1.0)
		if fill > 0.0:
			# Fill from the bottom up, in thirds.
			var top := center.y + r - 2.0 * r * fill
			var clipped := PackedVector2Array()
			for p in shape:
				clipped.append(Vector2(p.x, maxf(p.y, top)))
			draw_colored_polygon(clipped, color)
		draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]), Color(1, 1, 1, 0.6), 1.5)
