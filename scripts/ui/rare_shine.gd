class_name RareShine
extends Control
## Slowly rotating golden rays behind a rare card (queen) or epic card (king).

var epic := false
## Legendary: polychrome rays cycling through all colors.
var legend := false
## Unique equipment: turquoise-silver rays.
var unique := false
var _angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_angle += delta * (0.9 if legend else (0.6 if epic else 0.35))
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var radius := minf(size.x, size.y) * 0.62
	var rays := 20 if legend else (16 if epic else 10)
	var color := Color(1.0, 0.82, 0.3, 0.32 if epic else 0.22)
	for i in rays:
		var a := _angle + TAU * i / rays
		var spread := PI / rays * 0.45
		if unique:
			color = Color(0.45, 0.95, 0.88, 0.3) if i % 2 == 0 else Color(0.85, 0.9, 0.95, 0.22)
		if legend:
			color = Color.from_hsv(fmod(float(i) / rays + _angle * 0.15, 1.0), 0.7, 1.0, 0.42)
		draw_colored_polygon(PackedVector2Array([
			c,
			c + Vector2(cos(a - spread), sin(a - spread)) * radius * (1.15 if legend else 1.0),
			c + Vector2(cos(a + spread), sin(a + spread)) * radius * (1.15 if legend else 1.0),
		]), color)
	if unique:
		draw_circle(c, radius * 0.45, Color(0.45, 0.95, 0.88, 0.18))
		return
	var glow := Color.from_hsv(fmod(_angle * 0.15, 1.0), 0.5, 1.0, 0.25) if legend else Color(1.0, 0.85, 0.35, 0.18 if epic else 0.1)
	draw_circle(c, radius * 0.45, glow)
