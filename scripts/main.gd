extends Control
## M0 skeleton screen: verifies landscape scaling, text rendering,
## localization and touch/mouse input in the web build.

const GOLD := Color(0.85, 0.68, 0.32)
const PARCHMENT := Color(0.91, 0.86, 0.74)
const MUTED := Color(0.62, 0.58, 0.52)

var _tap_count := 0
var _tap_label: Label
var _info_label: Label


func _ready() -> void:
	TranslationServer.set_locale("de")
	_build_ui()
	get_viewport().size_changed.connect(_update_info)
	_update_info()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	column.add_child(_make_label(tr("M0_TITLE"), 64, GOLD))
	column.add_child(_make_label(tr("M0_SUBTITLE"), 28, PARCHMENT))

	var button := Button.new()
	button.text = tr("M0_TAP_BUTTON")
	button.custom_minimum_size = Vector2(320, 88)
	button.add_theme_font_size_override("font_size", 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_tap)
	column.add_child(button)

	_tap_label = _make_label("", 26, GOLD)
	column.add_child(_tap_label)

	var hint := _make_label(tr("M0_HINT"), 20, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(900, 0)
	column.add_child(hint)

	_info_label = _make_label("", 18, MUTED)
	column.add_child(_info_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_tap() -> void:
	_tap_count += 1
	_tap_label.text = tr("M0_TAP_RESULT") % _tap_count


func _update_info() -> void:
	var viewport_size := get_viewport_rect().size
	var screen_size := DisplayServer.window_get_size()
	_info_label.text = tr("M0_INFO") % [
		"%dx%d" % [viewport_size.x, viewport_size.y],
		"%dx%d" % [screen_size.x, screen_size.y],
		OS.get_name(),
	]
