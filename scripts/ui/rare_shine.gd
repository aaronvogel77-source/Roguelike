class_name RareShine
extends Control
## Slowly rotating golden rays behind a rare card (queen) or epic card (king).

var epic := false
var _angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_angle += delta * (0.6 if epic else 0.35)
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var radius := minf(size.x, size.y) * 0.62
	var rays := 16 if epic else 10
	var color := Color(1.0, 0.82, 0.3, 0.32 if epic else 0.22)
	for i in rays:
		var a := _angle + TAU * i / rays
		var spread := PI / rays * 0.45
		draw_colored_polygon(PackedVector2Array([
			c,
			c + Vector2(cos(a - spread), sin(a - spread)) * radius,
			c + Vector2(cos(a + spread), sin(a + spread)) * radius,
		]), color)
	draw_circle(c, radius * 0.45, Color(1.0, 0.85, 0.35, 0.18 if epic else 0.1))
