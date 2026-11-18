class_name ObjectCard
extends PanelContainer
## Card for an object in a pack or the relic/tarot bar: emblem, name,
## rarity (equipment) and effect text with colored keywords.

signal tapped(card: ObjectCard)

const SIZE := Vector2(150, 222)
## Major arcana numbers (Rider-Waite) shown on tarot cards.
const TAROT_NUMERALS := {"magician": "I", "strength": "VIII", "wheel_of_fortune": "X", "hanged_man": "XII",
	"star": "XVII", "sun": "XIX"}

## {"kind": "equipment|tarot|relic", ...} as stored in the run.
var entry: Dictionary = {}
var title := ""
var lines: Array = []
var _style: StyleBoxFlat
var _dark_face := true  # light card faces (most equipment) need dark headings


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
	_style.bg_color = Color(0, 0, 0, 0)
	_style.border_color = border
	_style.set_border_width_all(0)
	_style.set_corner_radius_all(10)
	var margin := 4 if compact else 9
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style.set_content_margin(side, margin)
	add_theme_stylebox_override("panel", _style)
	# The pixel card face (rarity / category colour, gloss and polychrome).
	var rarity := int(entry["item"]["rarity"]) if kind == "equipment" else 0
	var face_holder := Control.new()
	face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face_holder)
	var face_info := CardArt.for_object(kind, rarity, card_size)
	_dark_face = face_info.get("dark", false)
	var face := CardArt.face_rect(face_info)
	face_holder.add_child(face)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]:
		face.set(side, -margin)
	for side in ["offset_right", "offset_bottom"]:
		face.set(side, margin)

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
	if kind == "tarot":
		_build_tarot(card_size, margin)
		return
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var emblem_box := CenterContainer.new()
	emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "tarot":  # major arcana number above the picture, like a real tarot card
		var numeral := String(TAROT_NUMERALS.get(String(entry.get("id", "")), ""))
		column.add_child(_label(numeral, 15, Color("ffe08a")))
	var roomy := card_size.y >= 240
	emblem_box.add_child(_symbol(emblem_kind, (72 if roomy else 54) if kind == "tarot" else (56 if roomy else 44)))
	column.add_child(emblem_box)
	# Category label in the category color above the name.
	var category_keys := {"equipment": "UI_CAT_EQUIPMENT", "tarot": "UI_CAT_TAROT", "relic": "UI_CAT_RELIC", "pact": "UI_CAT_PACT"}
	if category_keys.has(kind) and kind != "tarot":
		var category_color: Color = DetailPanel.CATEGORY_COLORS[kind] if kind != "tarot" else Emblem.COLORS["tarot"]
		column.add_child(_label(TranslationServer.translate(category_keys[kind]).to_upper(), 12, category_color))
	var heading := _label(title, 18 if card_size.y >= 240 else 16, Palette.PARCHMENT if _dark_face else Color("2a1a10"))
	heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85) if _dark_face else Color(1, 0.97, 0.9, 0.9))
	heading.add_theme_constant_override("outline_size", 4)
	column.add_child(heading)
	if subtitle != "":  # rarity name on a small dark band so it reads on every face
		var rarity_label := _label(subtitle, 14, border.lightened(0.15))
		var band := StyleBoxFlat.new()
		band.bg_color = Color(0.03, 0.02, 0.06, 0.8)
		band.set_corner_radius_all(5)
		rarity_label.add_theme_stylebox_override("normal", band)
		column.add_child(rarity_label)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 13 if card_size.y >= 240 else 12)
	if kind in ["tarot", "relic", "pact", "equipment"]:  # a dark plate keeps the text readable on the card art
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.03, 0.02, 0.06, 0.82)
		plate.set_corner_radius_all(6)
		plate.content_margin_left = 3
		plate.content_margin_right = 3
		plate.content_margin_top = 2
		plate.content_margin_bottom = 2
		text.add_theme_stylebox_override("normal", plate)
		text.add_theme_color_override("default_color", Color("f6f0e2"))
		text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		text.add_theme_constant_override("outline_size", 3)
	text.add_theme_color_override("default_color", Palette.PARCHMENT)
	text.text = "[center]" + "\n".join(lines.map(func(l: String) -> String: return _highlight_label(Keywords.colorize(l, true, 15)))) + "[/center]"
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
	_style.set_border_width_all(4 if selected else 0)


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
	var id := String(entry["item"]["base"]) if entry.get("kind", "") == "equipment" else String(entry.get("id", ""))
	var icon := HandmadeArt.icon("icon_" + id)
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


## Tarot cards have fixed areas matching CardArt._tarot: the numeral and the
## picture inside the arch, the name on the plate, the text in its own field.
func _build_tarot(card_size: Vector2, margin: int) -> void:
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	var h := card_size.y
	var w := card_size.x
	var place := func(node: Control, top: float, bottom: float, inset := 16.0) -> void:
		node.position = Vector2(inset - margin, h * top - margin)
		node.size = Vector2(w - inset * 2.0, h * (bottom - top))
		area.add_child(node)
	var numeral := _label(String(TAROT_NUMERALS.get(String(entry.get("id", "")), "")), 14, Color("ffe08a"))
	place.call(numeral, 0.105, 0.165)
	var picture := CenterContainer.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(_symbol("tarot", 54 if h < 240 else 72))
	place.call(picture, 0.165, CardArt.TAROT_ARCH_END - 0.01)
	# The name shrinks until it fits on the plate (long names like "Das Rad des Schicksals").
	var font_size := 14 if h < 240 else 16
	var font := get_theme_default_font()
	while font_size > 9 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > w - 32.0:
		font_size -= 1
	var name := _label(title, font_size, Palette.PARCHMENT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	place.call(name, CardArt.TAROT_NAME[0], CardArt.TAROT_NAME[1], 14.0)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 12 if h < 240 else 13)
	text.add_theme_color_override("default_color", Color("f6f0e2"))
	text.text = "[center]" + "\n".join(lines.map(func(l: String) -> String: return Keywords.colorize(l, true, 15))) + "[/center]"
	place.call(text, CardArt.TAROT_TEXT[0] + 0.01, CardArt.TAROT_TEXT[1] - 0.005, 18.0)

