class_name UnlockFlash
extends Control
## A short celebration for vault purchases (altar upgrade, occultist, mirror):
## rays spin up behind a big emblem, "Freigeschaltet!" and the name appear,
## sparks fly. Closes by itself or on tap.

signal finished

var _emblem_kind := "star"
var _title := ""
var _color := Palette.GOLD
var _big := false
var _time := 0.0
var _closing := false


static func create(emblem_kind: String, title: String, color: Color = Palette.GOLD, big := false) -> UnlockFlash:
	var view := UnlockFlash.new()
	view._emblem_kind = emblem_kind
	view._title = title
	view._color = color
	view._big = big
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _ready() -> void:
	var emblem := Emblem.create(_emblem_kind, 150 if _big else 110)
	emblem.pivot_offset = emblem.size / 2
	emblem.scale = Vector2(0.2, 0.2)
	add_child(emblem)
	var labels: Array = []
	for line in [[tr("UI_UNLOCKED"), 30, Palette.PARCHMENT], [_title, 52, _color]]:
		var label := Label.new()
		label.text = line[0]
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
		label.add_theme_constant_override("outline_size", 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate.a = 0.0
		add_child(label)
		labels.append(label)
	await get_tree().process_frame
	emblem.position = Vector2(size.x / 2, size.y * 0.42) - emblem.size / 2
	labels[0].size = Vector2(size.x, 40)
	labels[0].position = Vector2(0, size.y * 0.62)
	labels[1].size = Vector2(size.x, 64)
	labels[1].position = Vector2(0, size.y * 0.62 + 38)
	var tween := create_tween()
	tween.tween_property(emblem, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(emblem, "scale", Vector2.ONE, 0.15)
	for label in labels:
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.6 if _big else 1.1)
	tween.tween_callback(_close)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and _time > 0.4:
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.005, 0.02, minf(_time * 4.0, 0.88)))
	var center := Vector2(size.x / 2, size.y * 0.42)
	var grow := minf(_time * 2.5, 1.0)
	for i in 18:  # turning rays behind the emblem
		var a := _time * 0.5 + TAU * i / 18.0
		var tip := center + Vector2(cos(a), sin(a)) * 420.0 * grow
		var side := Vector2(-sin(a), cos(a)) * 22.0 * grow
		draw_colored_polygon(PackedVector2Array([center, tip + side, tip - side]), Color(_color, 0.13))
	var q := clampf(_time / 0.9, 0.0, 1.0)
	if q < 1.0:  # sparks
		for i in 30:
			var a := TAU * i / 30.0
			var p := center + Vector2(cos(a), sin(a)) * q * (150.0 + (i % 4) * 40.0)
			draw_rect(Rect2(p, Vector2(5, 5)), Color(_color.lerp(Color.WHITE, 0.4), 1.0 - q))
