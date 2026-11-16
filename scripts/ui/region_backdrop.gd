class_name RegionBackdrop
extends Control
## Placeholder region background (until the art pass in M8): a dark gradient in
## the region's color with faint, scattered suit emblems.

var suit := "coins"


func _draw() -> void:
	var base: Color = Palette.SUIT_COLORS.get(suit, Palette.GOLD)
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var color := Palette.BACKGROUND.lerp(base.darkened(0.55), (1.0 - absf(t - 0.5) * 2.0) * 0.6)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / steps + 1), color)
	var rng := RandomNumberGenerator.new()
	rng.seed = suit.hash()
	for i in 40:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r := rng.randf_range(6, 22)
		draw_circle(p, r, Color(base, 0.06))
		draw_arc(p, r * 0.7, 0, TAU, 24, Color(base, 0.1), 2.0)
