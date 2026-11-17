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
			subtitle = ItemText.rarity_name(int(item["rarity"]))  # rarity in its color under the name
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
		"pact":
			emblem_kind = "pact"
			var key := "PACT_" + String(entry["id"]).to_upper()
			title = TranslationServer.translate(key)
			border = Emblem.COLORS["pact"]
			lines = [TranslationServer.translate(key + "_DESC"),
				TranslationServer.translate("PACT_COST_PREFIX") % TranslationServer.translate(key + "_COST")]
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.PANEL
	_style.border_color = border
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style.set_content_margin(side, 4 if compact else 8)
	add_theme_stylebox_override("panel", _style)

	var unique := kind == "equipment" and int(entry["item"]["rarity"]) == Items.RARITY_UNIQUE
	if unique:
		_style.shadow_color = Color(border, 0.6)
		_style.shadow_size = 14
		_style.set_border_width_all(4)
	if compact:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_symbol(emblem_kind, card_size.y * 0.7))
		add_child(holder)
		return
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var emblem_box := CenterContainer.new()
	emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem_box.add_child(_symbol(emblem_kind, 56))
	column.add_child(emblem_box)
	# Category label in the category color above the name.
	var category_keys := {"equipment": "UI_CAT_EQUIPMENT", "tarot": "UI_CAT_TAROT", "relic": "UI_CAT_RELIC", "pact": "UI_CAT_PACT"}
	if category_keys.has(kind):
		var category_color: Color = DetailPanel.CATEGORY_COLORS[kind] if kind != "tarot" else Emblem.COLORS["tarot"]
		column.add_child(_label(TranslationServer.translate(category_keys[kind]).to_upper(), 12, category_color))
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
	text.text = "[center]" + "\n".join(lines.map(func(l: String) -> String: return _highlight_label(Keywords.colorize(l)))) + "[/center]"
	column.add_child(text)
	if unique:
		_add_unique_shine(card_size)


## Turquoise rays behind a unique item and an "Einzigartig!" tag above it.
func _add_unique_shine(card_size: Vector2) -> void:
	var shine := RareShine.new()
	shine.unique = true
	shine.show_behind_parent = true
	shine.top_level = false
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.show_behind_parent = true
	add_child(holder)
	holder.add_child(shine)
	# Anchored to the card: the rays stay centred whatever size it ends up with.
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := card_size * 0.4
	shine.offset_left = -pad.x
	shine.offset_right = pad.x
	shine.offset_top = -pad.y
	shine.offset_bottom = pad.y
	var tag := _label(TranslationServer.translate("UI_RARE_UNIQUE"), 16, ItemText.RARITY_COLORS[Items.RARITY_UNIQUE])
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 6)
	tag.size = Vector2(card_size.x, 24)
	resized.connect(func() -> void: tag.size.x = size.x)
	tag.position = Vector2(0, -26)
	holder.add_child(tag)


## "Grundwirkung:" / "Zusatz:" / "Nachteil:" labels in their own colors.
func _highlight_label(line: String) -> String:
	for pair in [["UI_BASE_EFFECT", Palette.PARCHMENT], ["UI_EXTRA_EFFECT", Color(0.5, 0.75, 1.0)], ["UI_DRAWBACK", Palette.HEALTH],
			["UI_UNIQUE_EFFECT", ItemText.RARITY_COLORS[Items.RARITY_UNIQUE]]]:
		var label := TranslationServer.translate(pair[0]) + ":"
		if line.begins_with(label):
			return "[color=#%s][b]%s[/b][/color]%s" % [(pair[1] as Color).to_html(false), label, line.substr(label.length())]
	return line


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


## The object's own hand-drawn icon (each relic and tarot card has one), else
## the emblem of its kind. Icons are scaled by whole pixels so they stay crisp.
func _symbol(emblem_kind: String, symbol_size: float) -> Control:
	var icon := HandmadeArt.icon("icon_" + String(entry.get("id", "")))
	if icon == null:
		return Emblem.create(emblem_kind, symbol_size)
	var rect := TextureRect.new()
	rect.texture = icon
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var side := maxf(18.0, floorf(symbol_size / 18.0) * 18.0)
	rect.custom_minimum_size = Vector2(side, side)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

