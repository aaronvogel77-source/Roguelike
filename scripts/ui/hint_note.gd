class_name HintNote
extends Control
## A small parchment note with an arrow pointing at the element it explains,
## one or two sentences and "Verstanden". The rest of the screen stays usable.

const WIDTH := 380.0
const ARROW := 18.0
const PARCHMENT := Color(0.86, 0.79, 0.62)
const INK := Color(0.2, 0.13, 0.08)

var hint_id := ""
var _target: Control
var _panel: PanelContainer
var _below := true


static func create(id: String, target: Control) -> HintNote:
	var note := HintNote.new()
	note.hint_id = id
	note._target = target
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return note


func _ready() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PARCHMENT
	style.border_color = Color(0.45, 0.3, 0.15)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var title := Label.new()
	title.text = tr("HINT_" + hint_id.to_upper() + "_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.45, 0.12, 0.08))
	column.add_child(title)
	var text := Label.new()
	text.text = tr("HINT_" + hint_id.to_upper())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - 24, 0)
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", INK)
	column.add_child(text)
	var ok := Button.new()
	ok.text = tr("HINT_OK")
	ok.add_theme_font_size_override("font_size", 18)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_dismiss)
	column.add_child(ok)
	add_child(_panel)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_place.call_deferred()


func _dismiss() -> void:
	Hints.mark_seen(hint_id)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


## Below the target if there is room, otherwise above; kept on screen.
func _place() -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		queue_free()
		return
	var rect := _target.get_global_rect()
	var note_size := _panel.get_combined_minimum_size()
	var view := get_viewport_rect().size
	_below = rect.end.y + ARROW + note_size.y < view.y - 8
	var x := clampf(rect.get_center().x - note_size.x / 2, 8, view.x - note_size.x - 8)
	var y := rect.end.y + ARROW if _below else rect.position.y - ARROW - note_size.y
	y = clampf(y, 8, view.y - note_size.y - 8)
	_panel.global_position = Vector2(x, y)
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		queue_free()


func _draw() -> void:
	if _panel == null or not is_instance_valid(_target):
		return
	var rect := _target.get_global_rect()
	rect.position -= global_position  # draw in this note's own space
	var panel_pos := _panel.global_position - global_position
	var tip_x := clampf(rect.get_center().x, panel_pos.x + 16, panel_pos.x + _panel.size.x - 16)
	var base_y := panel_pos.y if _below else panel_pos.y + _panel.size.y
	var tip_y := base_y - ARROW + 2 if _below else base_y + ARROW - 2
	var points := PackedVector2Array([Vector2(tip_x - 12, base_y), Vector2(tip_x + 12, base_y), Vector2(tip_x, tip_y)])
	draw_colored_polygon(points, PARCHMENT)
	draw_polyline(PackedVector2Array([points[0], points[2], points[1]]), Color(0.45, 0.3, 0.15), 3.0)
