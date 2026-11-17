class_name UnitCard
extends Control
## Placeholder card for one battle unit: name, level, status chips,
## multiplier, attack (bottom left) and health (bottom right).
## The outer Control keeps its slot in the row; the inner body is what moves.

signal tapped(card: UnitCard)

const CARD_SIZE := Vector2(112, 164)
## Gap between cards in a row; a card "width" units wide also spans the gaps.
const ROW_GAP := 6.0
const STATUS_ORDER := ["shield", "burn", "curse", "bleed"]

var uid: int
var definition: Dictionary
## Run data for figures in the row: {"figure": dict, "db": ContentDb}.
var extras: Dictionary = {}
var is_enemy: bool
var snapshot: Dictionary = {}
var body: PanelContainer
## Actual size: boss figures span 2-3 card widths.
var card_size := CARD_SIZE

var _style: StyleBoxFlat
var _identity: HBoxContainer
var _chips: HFlowContainer
var _attack_label: Label
var _health_label: Label


## Card for a row figure: stats include equipment, boons, blessing and relics.
static func for_entry(entry: Dictionary, figure: Dictionary, db: ContentDb) -> UnitCard:
	var unit := BattleSimulator.preview_unit(entry, BattleSimulator.PLAYER)
	var base := BattleUnit.from_definition(entry["def"], BattleSimulator.PLAYER, 0, entry["level"])
	var card := UnitCard.new()
	card.extras = {"figure": figure, "db": db, "sources": entry.get("sources", []),
		"base_attack": base.effective_attack(), "base_health": base.max_health}
	card.setup(unit.snapshot(), entry["def"], false)
	return card


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
	var width := int(unit_definition.get("width", 1))
	card_size = Vector2(CARD_SIZE.x * width + ROW_GAP * (width - 1), CARD_SIZE.y)
	custom_minimum_size = card_size
	size = card_size

	body = PanelContainer.new()
	body.size = card_size
	body.pivot_offset = card_size / 2
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.gui_input.connect(_on_body_input)
	_style = StyleBoxFlat.new()
	# Tarot look: player figures on parchment, enemies on dark red cloth.
	_style.bg_color = Color("2e1a1e") if enemy else Color("e6d6b4")
	_style.border_color = base_border_color()
	_style.set_border_width_all(5 if unit_definition.get("boss", false) else 3)
	_style.set_corner_radius_all(10)
	if unit_definition.get("boss", false):
		_style.bg_color = Color(0.2, 0.06, 0.08)
	# Fusions glow in their suits; every stage adds to the glow (F3 cycles).
	var stage := int(unit_definition.get("fusion", {}).get("stage", 0))
	if stage > 0:
		var suits: Array = unit_definition["fusion"]["suits"]
		_style.shadow_color = Color(Palette.SUIT_COLORS.get(suits[-1], Palette.GOLD), 0.75)
		_style.shadow_size = 3 + 3 * stage
		_style.set_border_width_all(3 + stage)
		if stage >= 3:
			_cycle_glow(suits)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style.set_content_margin(side, 5)
	body.add_theme_stylebox_override("panel", _style)
	add_child(body)
	_add_portrait(initial, unit_definition, enemy)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(column)

	var name_label := Label.new()
	name_label.text = ContentDb.display_name(definition)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", _fitting_font_size(name_label))
	name_label.add_theme_color_override("font_color", Palette.PARCHMENT if enemy else Color("3a2414"))
	# An outline keeps the name readable on top of the figure.
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85) if enemy else Color("e6d6b4"))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.max_lines_visible = 2
	column.add_child(name_label)

	# Rank, suit and level as small emblems (placeholders for the M8 art).
	_identity = HBoxContainer.new()
	_identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_identity.add_theme_constant_override("separation", 2)
	_identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_identity)

	_chips = HFlowContainer.new()
	_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("h_separation", 3)
	_chips.add_theme_constant_override("v_separation", 1)
	_chips.custom_minimum_size = Vector2(0, 20)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_chips)

	var stats := HBoxContainer.new()
	column.add_child(stats)
	_attack_label = _add_stat_badge(stats, "attack")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	_health_label = _add_stat_badge(stats, "life")

	apply_snapshot(initial)


## The animated pixel figure in the middle of the card (drawn under the texts).
func _add_portrait(initial: Dictionary, unit_definition: Dictionary, enemy: bool) -> void:
	var actor := FigureActor.new()
	actor.portrait = true
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shown := initial.duplicate()
	shown["uid"] = 0
	actor.setup(unit_definition, shown, enemy)
	var height := maxf(actor.hit_rect().size.y - 26.0, 20.0)
	var room := card_size.y - 70.0
	var factor := clampf(room / height, 0.6, 1.5)
	if factor > 1.0:
		factor = maxf(1.0, floorf(factor * 4.0) / 4.0)
	actor.scale = Vector2(factor, factor)
	actor.position = Vector2(card_size.x / 2.0, card_size.y - 46.0)
	actor.home_x = randf() * 10.0
	body.add_child(actor)
	body.move_child(actor, 0)


func base_border_color() -> Color:
	if definition.get("boss", false):
		return Palette.GOLD
	if is_enemy:
		return Palette.ENEMY_BORDER
	return Palette.SUIT_COLORS.get(snapshot.get("suit", definition.get("suit", "")), Palette.GOLD)


func apply_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot
	_style.border_color = base_border_color()
	_attack_label.text = str(snapshot["effective_attack"])
	_health_label.text = str(maxi(snapshot["health"], 0))
	# Values raised by equipment, tarot or relics glow gold.
	if extras.has("base_attack"):
		var attack_up: bool = snapshot["effective_attack"] > extras["base_attack"]
		var health_up: bool = snapshot["max_health"] > extras["base_health"]
		_attack_label.add_theme_color_override("font_color", Color("ffe84a") if attack_up else Color.WHITE)
		_health_label.add_theme_color_override("font_color", Color("ffe84a") if health_up else Color.WHITE)
	_rebuild_identity(snapshot.get("level", 1))
	_rebuild_chips()


## F3: the glow slowly cycles through the fused suits' colors.
func _cycle_glow(suits: Array) -> void:
	var colors: Array = suits.map(func(s: String) -> Color: return Color(Palette.SUIT_COLORS.get(s, Palette.GOLD), 0.8))
	var tween := create_tween().set_loops()
	for color in colors:
		tween.tween_property(_style, "shadow_color", color, 0.8)


## Short gold flash on the frame when this unit's ability fires.
func flash_trigger(duration: float) -> void:
	_style.border_color = Palette.GOLD
	_style.set_border_width_all(5)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void:
		_style.border_color = base_border_color()
		_style.set_border_width_all(5 if definition.get("boss", false) else 3))


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
	halo.size = card_size + Vector2(12, 12)
	halo.pivot_offset = halo.size / 2
	add_child(halo)  # on the outer card, not inside the PanelContainer layout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(halo, "scale", Vector2(1.08, 1.08), duration)
	tween.tween_property(halo, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tween.chain().tween_callback(halo.queue_free)


## Center of the card in canvas coordinates (for floating numbers).
func center_position() -> Vector2:
	return body.global_position + card_size / 2


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
	var available := card_size.x - 14.0
	var words := label.text.split(" ")
	var largest := 21 if definition.get("boss", false) else 17
	for font_size in range(largest, 8, -1):
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


## Rank + suit + level emblems for the card (enemies: enemy mark + level).
func _rebuild_identity(level: int) -> void:
	for child in _identity.get_children():
		child.queue_free()
	for kind in identity_kinds(definition, is_enemy, snapshot.get("suit", "")):
		_identity.add_child(Emblem.create(kind, 19))
	var chevrons := Emblem.create("level", 19)
	chevrons.count = level
	_identity.add_child(chevrons)
	var stage := int(definition.get("fusion", {}).get("stage", 0))
	if stage > 0:
		var badge := _small_label(Palette.GOLD)
		badge.text = "F%d" % stage
		badge.add_theme_font_size_override("font_size", 15)
		_identity.add_child(badge)
	# Equipment and blessing marks for row figures.
	var figure: Dictionary = extras.get("figure", {})
	if figure.has("equipment"):
		var gear := Emblem.create(Emblem.EQUIPMENT_KINDS.get(figure["equipment"]["base"], "sword"), 19)
		gear.color = ItemText.RARITY_COLORS[int(figure["equipment"]["rarity"])]  # rarity at a glance
		_identity.add_child(gear)
	if figure.has("blessing"):
		_identity.add_child(Emblem.create("blessing_" + String(figure["blessing"]), 19))
	var sources: Array = extras.get("sources", [])
	if "tarot_strength" in sources:
		_identity.add_child(Emblem.create("tarot", 19))



static func identity_kinds(unit_definition: Dictionary, enemy: bool, suit: String = "") -> Array:
	if enemy:
		return ["enemy"]
	var rank := String(unit_definition.get("rank", "page"))
	if rank == "legend":
		rank = "king"  # placeholder emblem until M8
	if suit == "":
		suit = String(unit_definition.get("suit", "coins"))
	return ["rank_" + rank, "suit_" + suit]


## Attack / health: the number sits in the middle of its emblem.
func _add_stat_badge(parent: Control, kind: String) -> Label:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(44, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	holder.add_child(Emblem.create(kind, 44))
	var label := Label.new()
	label.size = Vector2(44, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	holder.add_child(label)
	return label
