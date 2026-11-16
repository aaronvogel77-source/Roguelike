class_name ObjectCard
extends PanelContainer
## Card for an object in a pack or the relic/tarot bar: emblem, name,
## rarity (equipment) and effect text with colored keywords.

signal tapped(card: ObjectCard)

const SIZE := Vector2(150, 210)

## {"kind": "equipment|tarot|relic", ...} as stored in the run.
var entry: Dictionary = {}
var title := ""
var lines: Array = []
var _style: StyleBoxFlat


static func create(db: ContentDb, object_entry: Dictionary, card_size: Vector2 = SIZE, compact := false) -> ObjectCard:
	var card := ObjectCard.new()
	card.entry = object_entry
	card._build(db, card_size, compact)
	return card


func _build(db: ContentDb, card_size: Vector2, compact: bool) -> void:
	custom_minimum_size = card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var kind: String = entry["kind"]
	var emblem_kind := "star"
	var border := Palette.GOLD
	var subtitle := ""
	match kind:
		"equipment":
			var item: Dictionary = entry["item"]
			emblem_kind = Emblem.EQUIPMENT_KINDS.get(item["base"], "sword")
			title = ItemText.equipment_name(item)
			border = ItemText.RARITY_COLORS[int(item["rarity"])]
			subtitle = ItemText.rarity_name(int(item["rarity"]))
			lines = ItemText.equipment_lines(db, item)
		"tarot":
			emblem_kind = "tarot"
			title = ItemText.tarot_name(entry["id"])
			border = Emblem.COLORS["tarot"]
			lines = [ItemText.tarot_text(entry["id"])]
		"relic":
			emblem_kind = "relic"
			title = ItemText.relic_name(entry["id"])
			border = Emblem.COLORS["relic"]
			lines = [ItemText.relic_text(entry["id"])]
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.PANEL
	_style.border_color = border
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style.set_content_margin(side, 4 if compact else 8)
	add_theme_stylebox_override("panel", _style)

	if compact:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(Emblem.create(emblem_kind, card_size.y * 0.7))
		add_child(holder)
		return
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var emblem_box := CenterContainer.new()
	emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem_box.add_child(Emblem.create(emblem_kind, 48))
	column.add_child(emblem_box)
	column.add_child(_label(title, 18, Palette.PARCHMENT))
	if subtitle != "":
		column.add_child(_label(subtitle, 14, border))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 13)
	text.add_theme_color_override("default_color", Palette.PARCHMENT)
	text.text = "[center]" + "\n".join(lines.map(func(l: String) -> String: return Keywords.colorize(l))) + "[/center]"
	column.add_child(text)


func set_selected(selected: bool) -> void:
	_style.set_border_width_all(6 if selected else 3)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit(self)
