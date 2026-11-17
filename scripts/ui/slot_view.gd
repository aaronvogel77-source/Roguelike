class_name SlotView
extends Control
## One card place in the planning screen: a row slot (may be empty) or a shop
## offer. Supports tapping and drag & drop; the run screen decides what a tap
## or a drop means.

signal tapped(slot: SlotView)
signal dropped(data: Dictionary, slot: SlotView)
## Dropped near the left or right edge: insert there instead of swapping.
signal inserted(data: Dictionary, slot: SlotView, side: String)

## Outer share of the card that counts as "between two cards".
const EDGE_ZONE := 0.2

const TAP_TOLERANCE := 12.0

var kind := "row"  # "row" or "shop"
var index := 0
var card: UnitCard
var accepts_drops := true

var _frame: Panel
var _frame_style: StyleBoxFlat
var _press_position := Vector2.INF
var _hover_zone := ""  # "", "left", "right", "center" while a drag hovers
## Set by the run screen: (drag data, slot index) -> "merge", "free", "swap", "no" or "".
var drop_check: Callable
var _drop_state := ""
const DROP_COLORS := {"merge": Color(1.0, 0.84, 0.3), "free": Color(0.45, 0.9, 1.0),
	"swap": Color(0.85, 0.85, 0.95), "no": Color(0.95, 0.25, 0.25)}


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


func _can_drop(at: Vector2, data: Variant) -> bool:
	var ok: bool = accepts_drops and kind == "row" and data is Dictionary and data.has("kind")
	var zone := _zone(at, data) if ok else ""
	if zone != _hover_zone:
		_hover_zone = zone
		queue_redraw()
	return ok


func _drop(at: Vector2, data: Variant) -> void:
	var zone := _zone(at, data)
	_hover_zone = ""
	queue_redraw()
	if zone == "left" or zone == "right":
		inserted.emit(data, self, zone)
	else:
		dropped.emit(data, self)


## Edge zones only exist for moving row figures next to another figure.
func _zone(at: Vector2, data: Dictionary) -> String:
	if data.get("kind") != "row" or card == null or data.get("index") == index:
		return "center"
	if at.x < size.x * EDGE_ZONE:
		return "left"
	if at.x > size.x * (1.0 - EDGE_ZONE):
		return "right"
	return "center"


func _notification(what: int) -> void:
	# While anything is dragged, every row place shows what a drop would do.
	if what == NOTIFICATION_DRAG_BEGIN and kind == "row" and drop_check.is_valid():
		var data: Variant = get_viewport().gui_get_drag_data()
		_drop_state = String(drop_check.call(data, index)) if data is Dictionary else ""
		queue_redraw()
	if what == NOTIFICATION_DRAG_END and _drop_state != "":
		_drop_state = ""
		queue_redraw()
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _hover_zone != "":
			_hover_zone = ""
			queue_redraw()


## Insert marker: a gold bar at the edge; a gold frame when swapping/merging.
func _draw() -> void:
	if _drop_state != "":
		var color: Color = DROP_COLORS.get(_drop_state, Color.WHITE)
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(Rect2(Vector2(-5, -5), size + Vector2(10, 10)), Color(color, 0.18 * pulse))
		draw_rect(Rect2(Vector2(-5, -5), size + Vector2(10, 10)), Color(color, pulse), false, 4.0)
		var font := ThemeDB.fallback_font
		var merging := _drop_state == "merge" and _hover_zone == "center"
		if merging:
			# Over the card: it glows gold and promises the level-up.
			for ring in 3:
				var grow := 6.0 + ring * 5.0
				draw_rect(Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2), Color(color, 0.22 * pulse / (ring + 1)), false, 5.0)
		var text: String = {"merge": "+1 Stufe" if merging else "+1", "no": "×"}.get(_drop_state, "")
		if text != "":
			var font_size := 26 if merging else 34
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			# Below the card while merging (the dragged card covers the middle).
			var at := Vector2((size.x - width) / 2, size.y + 34.0 if merging else size.y / 2 + font_size / 2.0)
			if merging:
				draw_rect(Rect2(at + Vector2(-10, -font_size - 4), Vector2(width + 20, font_size + 14)), Color(0.25, 0.15, 0.02, 0.85))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 0.95))
		queue_redraw()  # keeps the pulse going while dragging
	# Edges: a glowing line where the figure will be placed beside this one.
	var line := Color(0.55, 0.95, 1.0)
	match _hover_zone:
		"left":
			draw_rect(Rect2(-14, -10, 14, size.y + 20), Color(line, 0.25))
			draw_rect(Rect2(-10, -10, 6, size.y + 20), line)
		"right":
			draw_rect(Rect2(size.x, -10, 14, size.y + 20), Color(line, 0.25))
			draw_rect(Rect2(size.x + 4, -10, 6, size.y + 20), line)
		"center":
			draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Palette.GOLD, false, 3.0)
