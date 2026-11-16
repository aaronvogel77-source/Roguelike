class_name UnitCard
extends Control
## Placeholder card for one battle unit: name, level, status chips,
## multiplier, attack (bottom left) and health (bottom right).
## The outer Control keeps its slot in the row; the inner body is what moves.

signal tapped(card: UnitCard)

const CARD_SIZE := Vector2(96, 140)
const STATUS_ORDER := ["shield", "burn", "curse", "bleed"]

var uid: int
var definition: Dictionary
var is_enemy: bool
var snapshot: Dictionary = {}
var body: PanelContainer

var _style: StyleBoxFlat
var _level_label: Label
var _chips: HFlowContainer
var _attack_label: Label
var _health_label: Label


## Card for a figure outside of battle (shop, row, rewards, previews).
static func for_definition(unit_definition: Dictionary, level: int, enemy: bool) -> UnitCard:
	var side := BattleSimulator.ENEMY if enemy else BattleSimulator.PLAYER
	var unit := BattleUnit.from_definition(unit_definition, side, 0, level)
	var card := UnitCard.new()
	card.setup(unit.snapshot(), unit_definition, enemy)
	return card


func setup(initial: Dictionary, unit_definition: Dictionary, enemy: bool) -> void:
	uid = initial["uid"]
	definition = unit_definition
	is_enemy = enemy
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE

	body = PanelContainer.new()
	body.size = CARD_SIZE
	body.pivot_offset = CARD_SIZE / 2
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_body_input)
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.PANEL
	_style.border_color = base_border_color()
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style.set_content_margin(side, 5)
	body.add_theme_stylebox_override("panel", _style)
	add_child(body)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(column)

	var name_label := Label.new()
	name_label.text = tr(ContentDb.name_key(definition))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", _fitting_font_size(name_label))
	name_label.add_theme_color_override("font_color", Palette.PARCHMENT)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.max_lines_visible = 2
	column.add_child(name_label)

	_level_label = _small_label(Palette.GOLD)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_level_label)

	_chips = HFlowContainer.new()
	_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("h_separation", 3)
	_chips.add_theme_constant_override("v_separation", 1)
	_chips.custom_minimum_size = Vector2(0, 20)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_chips)

	var stats := HBoxContainer.new()
	column.add_child(stats)
	_attack_label = _make_badge(Palette.ATTACK)
	stats.add_child(_attack_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	_health_label = _make_badge(Palette.HEALTH)
	stats.add_child(_health_label)

	apply_snapshot(initial)


func base_border_color() -> Color:
	if is_enemy:
		return Palette.ENEMY_BORDER
	return Palette.SUIT_COLORS.get(definition.get("suit", ""), Palette.GOLD)


func apply_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot
	_attack_label.text = str(snapshot["effective_attack"])
	_health_label.text = str(maxi(snapshot["health"], 0))
	var level: int = snapshot.get("level", 1)
	_level_label.text = tr("UI_LEVEL_SHORT") % level if level > 1 else ""
	_rebuild_chips()


## Short gold flash on the frame when this unit's ability fires.
func flash_trigger(duration: float) -> void:
	_style.border_color = Palette.GOLD
	_style.set_border_width_all(5)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void:
		_style.border_color = base_border_color()
		_style.set_border_width_all(3))


## Colored halo pulse around the card (abilities that act on the unit itself).
func pulse_glow(color: Color, duration: float) -> void:
	var halo := Panel.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.0)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(color, 0.7)
	style.shadow_size = 14
	halo.add_theme_stylebox_override("panel", style)
	halo.position = body.position - Vector2(6, 6)
	halo.size = CARD_SIZE + Vector2(12, 12)
	halo.pivot_offset = halo.size / 2
	add_child(halo)  # on the outer card, not inside the PanelContainer layout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(halo, "scale", Vector2(1.08, 1.08), duration)
	tween.tween_property(halo, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tween.chain().tween_callback(halo.queue_free)


## Center of the card in canvas coordinates (for floating numbers).
func center_position() -> Vector2:
	return body.global_position + CARD_SIZE / 2


func _rebuild_chips() -> void:
	for child in _chips.get_children():
		child.queue_free()
	var statuses: Dictionary = snapshot.get("statuses", {})
	for status in STATUS_ORDER:
		if statuses.get(status, 0) > 0:
			_chips.add_child(_make_chip(status, str(statuses[status])))
	var multiplier: float = snapshot.get("multiplier", 1.0)
	if absf(multiplier - 1.0) > 0.001:
		_chips.add_child(_make_chip("star", "×%s" % NumberFormat.decimal(multiplier)))


## A status emblem with its stack count (or a multiplier) on a dark pill.
func _make_chip(kind: String, text: String) -> Control:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.border_color = Emblem.COLORS.get(kind, Color.WHITE)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 1
	style.content_margin_right = 4
	pill.add_theme_stylebox_override("panel", style)
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 1)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(chip)
	chip.add_child(Emblem.create(kind, 24))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	chip.add_child(label)
	return pill


func _small_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	return label


func _on_body_input(event: InputEvent) -> void:
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	if released:
		tapped.emit(self)


## Largest font size (14 down to 9) at which the name wraps into at most two
## lines and no single word is wider than the card (no mid-word breaks).
func _fitting_font_size(label: Label) -> int:
	var font := label.get_theme_font("font")
	var available := CARD_SIZE.x - 14.0
	var words := label.text.split(" ")
	for font_size in range(14, 8, -1):
		if _wrapped_line_count(words, font, font_size, available) <= 2:
			return font_size
	return 9


## Greedy word wrap; returns 99 if a single word does not fit at all.
func _wrapped_line_count(words: PackedStringArray, font: Font, font_size: int, available: float) -> int:
	var lines := 1
	var line := ""
	for word in words:
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			return 99
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			lines += 1
			line = word
		else:
			line = candidate
	return lines


func _make_badge(color: Color) -> Label:
	var badge := Label.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(17)
	badge.add_theme_stylebox_override("normal", style)
	return badge
