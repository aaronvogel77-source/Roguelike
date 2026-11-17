class_name LegendaryReveal
extends Control
## The big moment for a legendary skin: the screen goes black, a pillar of
## light in the skin's colour strikes, sparks explode, the skin's weather
## fills the screen (fire rain, snowstorm, starfield, golden rain) and the
## figure stands tall in the middle and performs its special attack under its
## name and "LEGENDÄR".

signal finished

var _skin := ""
var _theme := "hellfire"
var _main := Color.WHITE
var _light := Color.WHITE
var _time := 0.0
var _actor: FigureActor
var _labels: Array = []
var _can_close := false


static func create(skin_id: String) -> LegendaryReveal:
	var view := LegendaryReveal.new()
	view._skin = skin_id
	view._theme = String(FigureArt.SKINS.get(skin_id, {}).get("fx", "hellfire"))
	view._main = Color(FigureArt.FX_COLORS[view._theme][0])
	view._light = Color(FigureArt.FX_COLORS[view._theme][1])
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _ready() -> void:
	# The skinned figure, big and crisp (pixel art scaled by whole numbers).
	var db := ContentDb.load_default()
	var figure_id := String(MetaState.cosmetic(db, _skin).get("figure", "executioner"))
	var worn := Cosmetics.skins.duplicate()
	Cosmetics.skins[figure_id] = _skin
	_actor = FigureActor.new()
	_actor.showcase = true
	_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actor.setup(db.figures[figure_id], {"uid": 0, "health": 1, "max_health": 1}, false)
	Cosmetics.skins = worn
	_actor.scale = Vector2(7, 7)
	_actor.modulate.a = 0.0
	add_child(_actor)
	for text in [tr("UI_LEGENDARY"), tr("COSMETIC_" + _skin.to_upper()), tr("SPECIAL_" + _skin.to_upper())]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
		label.add_theme_constant_override("outline_size", 12)
		label.modulate.a = 0.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
	_labels[0].add_theme_font_size_override("font_size", 30)
	_labels[0].add_theme_color_override("font_color", _light)
	_labels[1].add_theme_font_size_override("font_size", 64)
	_labels[1].add_theme_color_override("font_color", _main.lerp(Color.WHITE, 0.25))
	_labels[2].add_theme_font_size_override("font_size", 28)
	_labels[2].add_theme_color_override("font_color", Palette.PARCHMENT)
	_layout.call_deferred()
	_play.call_deferred()


func _layout() -> void:
	_actor.position = Vector2(size.x * 0.5, size.y * 0.8)
	_labels[0].position = Vector2(0, size.y * 0.06)
	_labels[1].position = Vector2(0, size.y * 0.06 + 34)
	_labels[2].position = Vector2(0, size.y * 0.84)
	for label in _labels:
		label.size = Vector2(size.x, 70)


func _play() -> void:
	var tween := create_tween()
	tween.tween_interval(0.9)  # darkness, then the pillar strikes (drawn by time)
	tween.tween_property(_actor, "modulate:a", 1.0, 0.3)
	for i in _labels.size():
		tween.tween_property(_labels[i], "modulate:a", 1.0, 0.25)
	tween.tween_callback(func() -> void: _actor.strike(0.5))
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		_actor.strike(0.5)
		_can_close = true)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and _can_close:
		_can_close = false
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void:
			finished.emit()
			queue_free())


func _process(delta: float) -> void:
	_time += delta
	if _can_close and fmod(_time, 1.6) < delta:
		_actor.strike(0.5)  # keeps showing off its special attack
	queue_redraw()


func _draw() -> void:
	var dark := clampf(_time / 0.35, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.97 * dark))
	_draw_weather()
	var cx := size.x * 0.5
	# The pillar of light strikes at 0.6 s and stays as a glow behind the figure.
	var t := _time - 0.6
	if t > 0.0:
		# The pillar strikes and fades; a pulsing halo stays behind the figure.
		var width := 30.0 + 190.0 * exp(-t * 5.0)
		var fade := exp(-t * 2.2)
		var glow := _main
		glow.a = 0.75 * fade
		draw_rect(Rect2(cx - width, 0, width * 2.0, size.y), glow)
		var core := _light
		core.a = 0.95 * fade
		draw_rect(Rect2(cx - width * 0.3, 0, width * 0.6, size.y), core)
		var halo_center := Vector2(cx, size.y * 0.8 - 230.0)
		var pulse := 0.5 + 0.5 * sin(_time * 2.2)
		for ring in 6:
			var halo := _main
			halo.a = (0.05 + 0.03 * pulse) * minf(t, 1.0)
			draw_circle(halo_center, 120.0 + ring * 45.0 + pulse * 12.0, halo)
		if t < 0.15:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 1.0 - t / 0.15))
		# Sparks exploding from the impact on the ground.
		var q := clampf(t / 1.2, 0.0, 1.0)
		if q < 1.0:
			for i in 48:
				var a := -PI + TAU * i / 48.0
				var r := q * (160.0 + (i % 7) * 40.0)
				var p := Vector2(cx, size.y * 0.78) + Vector2(cos(a), sin(a) * 0.6) * r + Vector2(0, q * q * 120.0)
				var c := _light if i % 2 else _main
				c.a = 1.0 - q
				draw_rect(Rect2(p, Vector2(8, 8) if i % 3 == 0 else Vector2(5, 5)), c)


## Weather over the whole screen in the skin's theme.
func _draw_weather() -> void:
	var w := size.x
	var h := size.y
	match _theme:
		"hellfire":  # embers and fire rain rising from below
			for i in 70:
				var ph := fmod(_time * (0.25 + (i % 5) * 0.05) + i * 0.137, 1.0)
				var p := Vector2(fmod(i * 97.0, w) + sin(_time * 2 + i) * 14.0, h - ph * (h + 40))
				var c := Color("ff9a20") if i % 3 else Color("fff0a0")
				c.a = 0.9 * (1.0 - ph)
				draw_rect(Rect2(p, Vector2(5, 7) if i % 4 == 0 else Vector2(4, 4)), c)
		"frost":  # a snowstorm blowing across
			for i in 110:
				var ph := fmod(_time * (0.2 + (i % 4) * 0.06) + i * 0.071, 1.0)
				var p := Vector2(fmod(i * 131.0 + ph * w * 0.6, w), ph * (h + 30) - 15)
				var c := Color(0.9, 0.96, 1.0, 0.85 if i % 3 else 0.5)
				draw_rect(Rect2(p, Vector2(5, 5) if i % 5 == 0 else Vector2(3, 3)), c)
		"void":  # a starfield that slowly turns, with drifting runes
			for i in 140:
				var a := i * 2.399 + _time * 0.05
				var r := fmod(i * 37.0, maxf(w, h) * 0.7)
				var p := Vector2(w * 0.5, h * 0.5) + Vector2(cos(a), sin(a)) * r
				var tw := 0.5 + 0.5 * sin(_time * (2.0 + i % 4) + i)
				var c := Color(0.85, 0.75, 1.0, 0.35 + 0.6 * tw) if i % 4 else Color(0.7, 0.4, 1.0, 0.5 + 0.5 * tw)
				draw_rect(Rect2(p, Vector2(4, 4) if i % 9 == 0 else Vector2(2, 2)), c)
		"sun":  # golden rain and slow sun rays
			for i in 16:
				var a := _time * 0.15 + TAU * i / 16.0
				draw_line(Vector2(w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.5) + Vector2(cos(a), sin(a)) * w,
					Color(1.0, 0.85, 0.4, 0.08), 26.0)
			for i in 90:
				var ph := fmod(_time * (0.22 + (i % 5) * 0.05) + i * 0.113, 1.0)
				var p := Vector2(fmod(i * 89.0, w), ph * (h + 30) - 15)
				var c := Color("ffd860") if i % 3 else Color("fffbe0")
				c.a = 0.9 * sin(ph * PI)
				draw_rect(Rect2(p, Vector2(4, 6) if i % 4 == 0 else Vector2(3, 3)), c)
