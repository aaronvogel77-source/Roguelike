class_name UnitCard
extends Control
## Placeholder card for one battle unit: name, suit-colored frame,
## attack (bottom left) and health (bottom right).
## The outer Control keeps its slot in the row; the inner body is what moves.

const CARD_SIZE := Vector2(96, 140)

var uid: int
var attack: int
var health: int
var body: PanelContainer
var _attack_label: Label
var _health_label: Label


func setup(snapshot: Dictionary, definition: Dictionary, is_enemy: bool) -> void:
	uid = snapshot["uid"]
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE

	body = PanelContainer.new()
	body.size = CARD_SIZE
	body.pivot_offset = CARD_SIZE / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.ENEMY_BORDER if is_enemy else Palette.SUIT_COLORS.get(definition.get("suit", ""), Palette.GOLD)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	body.add_theme_stylebox_override("panel", style)
	add_child(body)

	var column := VBoxContainer.new()
	body.add_child(column)

	var name_label := Label.new()
	name_label.text = tr(ContentDb.name_key(definition))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", _fitting_font_size(name_label))
	name_label.add_theme_color_override("font_color", Palette.PARCHMENT)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(name_label)

	var stats := HBoxContainer.new()
	column.add_child(stats)
	_attack_label = _make_badge(Palette.ATTACK)
	stats.add_child(_attack_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	_health_label = _make_badge(Palette.HEALTH)
	stats.add_child(_health_label)
	set_stats(snapshot["attack"], snapshot["health"])


func set_stats(new_attack: int, new_health: int) -> void:
	attack = new_attack
	health = new_health
	_attack_label.text = str(attack)
	_health_label.text = str(maxi(health, 0))


## Center of the card in canvas coordinates (for floating numbers).
func center_position() -> Vector2:
	return body.global_position + CARD_SIZE / 2


## Largest font size (14 down to 9) at which every single word of the name
## fits the card width, so long German words never break mid-word.
func _fitting_font_size(label: Label) -> int:
	var font := label.get_theme_font("font")
	var available := CARD_SIZE.x - 14.0
	for font_size in range(14, 8, -1):
		var fits := true
		for word in label.text.split(" "):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
				fits = false
				break
		if fits:
			return font_size
	return 9


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
