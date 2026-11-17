class_name DetailPanel
extends PanelContainer
## Shows everything about a tapped card: name, suit/rank, level, stats,
## ability text with the value for the current level, and active statuses.

var _title: Label
var _subtitle: HBoxContainer
var _body: RichTextLabel
var _figures: Dictionary = {}  # figure definitions for fusion texts (loaded once)

## Colors of the object categories, used everywhere the category is named.
const CATEGORY_COLORS := {
	"equipment": Color("b8c8dc"), "blessing": Color("ffd25a"), "tarot": Color(0.8, 0.65, 0.95),
	"relic": Color(0.4, 0.85, 0.8), "pact": Color(0.9, 0.3, 0.38), "ability": Color("e0b44a"),
}


## A category label in its color, e.g. "Ausrüstung:".
func _tag(key: String, color: Color) -> String:
	return "[b][color=#%s]%s:[/color][/b]" % [color.to_html(false), tr(key)]


func _init() -> void:
	custom_minimum_size = Vector2(720, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.97)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 16)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(120, 48)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(hide)
	header.add_child(close)

	_subtitle = HBoxContainer.new()
	_subtitle.add_theme_constant_override("separation", 6)
	column.add_child(_subtitle)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", 24)
	_body.add_theme_font_size_override("bold_font_size", 24)
	_body.add_theme_color_override("default_color", Palette.PARCHMENT)
	column.add_child(_body)
	# Taps go through the panel (to the cards underneath); only "close" reacts.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Control in [column, header, _title, _subtitle, _body]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_card(card: UnitCard) -> void:
	show_unit(card.definition, card.snapshot, card.is_enemy, card.extras)


## Details of any unit (cards in the shop/row, figures on the battle stage).
func show_unit(definition: Dictionary, snapshot: Dictionary, is_enemy: bool, extras: Dictionary = {}) -> void:
	_title.text = ContentDb.display_name(definition)
	var level: int = snapshot.get("level", 1)
	# Rank · suit · level, each with its emblem.
	for child in _subtitle.get_children():
		child.queue_free()
	var kinds := UnitCard.identity_kinds(definition, is_enemy, snapshot.get("suit", ""))
	var texts: Array = [tr("UI_ENEMY")] if is_enemy else [
		tr("RANK_" + String(definition["rank"]).to_upper()),
		tr("SUIT_" + String(snapshot.get("suit", definition["suit"])).to_upper()),
	]
	kinds.append("level")
	texts.append(tr("UI_LEVEL") % level)
	for i in kinds.size():
		if i > 0:
			_subtitle.add_child(_subtitle_text("·"))
		var emblem := Emblem.create(kinds[i], 26)
		if kinds[i] == "level":
			emblem.count = level
		_subtitle.add_child(emblem)
		_subtitle.add_child(_subtitle_text(texts[i]))

	var lines: Array[String] = []
	lines.append(Keywords.colorize(tr("UI_STATS") % [snapshot["effective_attack"], maxi(snapshot["health"], 0), snapshot["max_health"]]))
	var multiplier: float = snapshot.get("multiplier", 1.0)
	if absf(multiplier - 1.0) > 0.001:
		lines.append(tr("UI_MULTIPLIER") % NumberFormat.decimal(multiplier))
	if definition.has("fusion"):
		lines.append_array(_fusion_lines(definition["fusion"], level))
	elif definition.has("ability"):
		var ability: Dictionary = definition["ability"]
		var values: Array = ability["values"]
		var value: float = values[mini(level, values.size()) - 1]
		var text := tr("ABIL_" + String(definition["id"]).to_upper())
		lines.append(_tag("UI_CAT_ABILITY", CATEGORY_COLORS["ability"]) + " [b]" + Keywords.colorize(text.replace("{v}", NumberFormat.ability_value(ability["effect"], value))) + "[/b]")
	var statuses: Dictionary = snapshot.get("statuses", {})
	for status in UnitCard.STATUS_ORDER:
		if statuses.get(status, 0) > 0:
			var color := Emblem.COLORS[status] as Color
			lines.append("[color=#%s]%s %d[/color] – %s" % [
				color.to_html(false), tr("STATUS_" + status.to_upper()), statuses[status],
				Keywords.colorize(tr("STATUS_%s_DESC" % status.to_upper())),
			])
	var figure: Dictionary = extras.get("figure", {})
	if not figure.is_empty():
		# Every category in its own color; equipment also shows its rarity.
		if figure.has("xp"):  # own row figures: how many object slots are used
			lines.append("[color=#%s]%s[/color]" % [Palette.MUTED.to_html(false),
				tr("UI_OBJECT_SLOTS") % [RunState.objects_on(figure), RunState.slots_for(figure)]])
		if figure.has("equipment"):
			var item: Dictionary = figure["equipment"]
			var rarity := int(item["rarity"])
			var rarity_color: Color = ItemText.RARITY_COLORS[rarity]
			lines.append("%s [color=#%s][b]%s[/b] · %s[/color]" % [_tag("UI_CAT_EQUIPMENT", CATEGORY_COLORS["equipment"]),
				rarity_color.to_html(false), ItemText.equipment_name(item), ItemText.rarity_line(rarity)])
			for line in ItemText.equipment_lines(extras["db"], item):
				lines.append("   " + Keywords.colorize(line))
		if figure.has("blessing"):
			lines.append("%s [color=#%s][b]%s[/b][/color] – %s" % [_tag("UI_CAT_BLESSING", CATEGORY_COLORS["blessing"]),
				CATEGORY_COLORS["blessing"].to_html(false), ItemText.tarot_name(figure["blessing"]),
				Keywords.colorize(ItemText.tarot_text(figure["blessing"]))])
		if int(figure.get("bonus_attack", 0)) != 0 or int(figure.get("bonus_health", 0)) != 0:
			lines.append("%s %s" % [_tag("UI_CAT_STRENGTH", CATEGORY_COLORS["tarot"]),
				Keywords.colorize(tr("UI_BONUS_STATS") % [figure.get("bonus_attack", 0), figure.get("bonus_health", 0)])])
		var relic_names: Array = []
		var pact_names: Array = []
		for source in extras.get("sources", []):
			if source == "tarot_strength":
				continue
			elif String(source).begins_with("suit_"):
				lines.append("%s %s" % [_tag("UI_CAT_SUIT_BONUS", CATEGORY_COLORS["ability"]),
					Keywords.colorize(tr("SUITBONUS_" + String(source).substr(5).to_upper()))])
			elif source in extras["db"].items["pacts"]:
				pact_names.append(tr("PACT_" + String(source).to_upper()))
			else:
				relic_names.append(ItemText.relic_name(source))
		if not relic_names.is_empty():
			lines.append("%s [color=#%s]%s[/color]" % [_tag("UI_CAT_RELICS", CATEGORY_COLORS["relic"]),
				CATEGORY_COLORS["relic"].to_html(false), ", ".join(relic_names)])
		if not pact_names.is_empty():
			lines.append("%s [color=#%s]%s[/color]" % [_tag("UI_CAT_PACTS", CATEGORY_COLORS["pact"]),
				CATEGORY_COLORS["pact"].to_html(false), ", ".join(pact_names)])
	_body.text = "\n".join(lines)
	show()


## Fusion: stage, contained figures, kept abilities and the master ability.
func _fusion_lines(fusion: Dictionary, level: int) -> Array[String]:
	var lines: Array[String] = []
	var names: Array = fusion["parts"].map(func(id: String) -> String: return tr("FIG_" + id.to_upper()))
	lines.append("[color=#%s]%s · %s[/color]" % [Palette.GOLD.to_html(false), tr("UI_FUSION_STAGE") % int(fusion["stage"]),
		tr("UI_FUSION_PARTS") % ", ".join(names)])
	var figures: Dictionary = ContentDb.load_default().figures if _figures.is_empty() else _figures
	_figures = figures
	for id in fusion["abilities"]:
		var ability: Dictionary = figures[id]["ability"]
		var values: Array = ability["values"]
		var value: float = values[mini(level, values.size()) - 1]
		var text := tr("ABIL_" + String(id).to_upper()).replace("{v}", NumberFormat.ability_value(ability["effect"], value))
		lines.append("[b]" + Keywords.colorize(text) + "[/b]")
	if fusion.get("master", "") != "":
		var key := "MASTER_" + String(fusion["master"]).to_upper()
		lines.append(Keywords.colorize(tr("UI_FUSION_MASTER") % ("[b]%s[/b]" % tr(key)) + " – " + tr(key + "_DESC")))
	return lines


## A plain message (title + text), e.g. instructions.
func show_message(title_text: String, text: String) -> void:
	_title.text = title_text
	for child in _subtitle.get_children():
		child.queue_free()
	_body.text = text
	show()


## Adds a hint line under the current content (e.g. how to use a tarot card).
func show_hint(text: String) -> void:
	_body.text += "\n[color=#%s]%s[/color]" % [Palette.GOLD.to_html(false), text]


## Shows an object (relic, tarot, equipment) in the same panel.
func show_object(object_card: ObjectCard) -> void:
	_title.text = object_card.title
	for child in _subtitle.get_children():
		child.queue_free()
	_body.text = "\n".join(object_card.lines.map(func(l: String) -> String: return Keywords.colorize(l)))
	show()


func _subtitle_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Palette.MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
