class_name SlotView
extends Control
## One card place in the planning screen: a row slot (may be empty) or a shop
## offer. Supports tapping and drag & drop; the run screen decides what a tap
## or a drop means.

signal tapped(slot: SlotView)
signal dropped(data: Dictionary, slot: SlotView)

const TAP_TOLERANCE := 12.0

var kind := "row"  # "row" or "shop"
var index := 0
var card: UnitCard
var accepts_drops := true

var _frame: Panel
var _frame_style: StyleBoxFlat
var _press_position := Vector2.INF


func _init(slot_kind: String, slot_index: int) -> void:
	kind = slot_kind
	index = slot_index
	custom_minimum_size = UnitCard.CARD_SIZE
	size = UnitCard.CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = Panel.new()
	_frame.size = UnitCard.CARD_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(1, 1, 1, 0.03)
	_frame_style.border_color = Color(1, 1, 1, 0.18)
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(10)
	_frame.add_theme_stylebox_override("panel", _frame_style)
	add_child(_frame)
	set_drag_forwarding(_drag_data, _can_drop, _drop)


func set_card(new_card: UnitCard) -> void:
	if card != null:
		card.queue_free()
	card = new_card
	if card != null:
		# Let presses fall through the card to this slot (taps and drags).
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.body.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(card)


func set_selected(selected: bool) -> void:
	_frame_style.border_color = Palette.GOLD if selected else Color(1, 1, 1, 0.18)
	_frame_style.set_border_width_all(4 if selected else 2)
	_frame.position = Vector2(-5, -5) if selected else Vector2.ZERO
	_frame.size = UnitCard.CARD_SIZE + (Vector2(10, 10) if selected else Vector2.ZERO)
	if card != null:
		card.position.y = -8.0 if selected else 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif _press_position != Vector2.INF and event.position.distance_to(_press_position) < TAP_TOLERANCE:
			_press_position = Vector2.INF
			tapped.emit(self)


func _drag_data(_at: Vector2) -> Variant:
	if card == null:
		return null
	_press_position = Vector2.INF
	var preview := UnitCard.for_definition(card.definition, card.snapshot.get("level", 1), false)
	preview.modulate = Color(1, 1, 1, 0.8)
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -UnitCard.CARD_SIZE / 2
	set_drag_preview(holder)
	return {"kind": kind, "index": index}


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return accepts_drops and kind == "row" and data is Dictionary and data.has("kind")


func _drop(_at: Vector2, data: Variant) -> void:
	dropped.emit(data, self)
