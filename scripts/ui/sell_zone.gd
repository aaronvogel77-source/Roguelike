class_name SellZone
extends PanelContainer
## Drop target for selling: drag a row figure here, or select a figure and tap.

signal tapped
signal dropped(data: Dictionary)

## Hidden until a figure or object is held, dragged or selected.
var auto_hide := false
var _label: Label
var _style: StyleBoxFlat
var _active := false


func _init() -> void:
	custom_minimum_size = UnitCard.CARD_SIZE + Vector2(20, 0)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.22, 0.06, 0.12, 0.92)
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
	_active = active
	_style.border_color = Palette.GOLD if active else Color(0.8, 0.3, 0.3, 0.5)
	_style.set_border_width_all(4 if active else 2)
	if auto_hide:
		_reveal(active)


func set_auto_hide(value: bool) -> void:
	auto_hide = value
	_reveal(false)


func _reveal(on: bool) -> void:
	if not auto_hide:
		return
	modulate.a = 1.0 if on else 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if not auto_hide:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.get("kind") in SELLABLE:
			_reveal(true)
	elif what == NOTIFICATION_DRAG_END:
		_reveal(_active)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit()


## What can be dropped here to sell it: own figures and relics.
const SELLABLE := ["row", "relic"]


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") in SELLABLE


func _drop(_at: Vector2, data: Variant) -> void:
	dropped.emit(data)
