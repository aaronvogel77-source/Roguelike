class_name SellZone
extends PanelContainer
## Drop target for selling: drag a row figure here, or select a figure and tap.

signal tapped
signal dropped(data: Dictionary)

var _label: Label
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = UnitCard.CARD_SIZE + Vector2(20, 0)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.25, 0.08, 0.08, 0.35)
	_style.border_color = Color(0.8, 0.3, 0.3, 0.5)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", _style)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Palette.PARCHMENT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_drag_forwarding(Callable(), _can_drop, _drop)
	show_text(tr("UI_SELL_ZONE"), false)


func show_text(text: String, active: bool) -> void:
	_label.text = text
	_style.border_color = Palette.GOLD if active else Color(0.8, 0.3, 0.3, 0.5)
	_style.set_border_width_all(4 if active else 2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit()


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "row"


func _drop(_at: Vector2, data: Variant) -> void:
	dropped.emit(data)
