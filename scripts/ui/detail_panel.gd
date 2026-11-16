class_name DetailPanel
extends PanelContainer
## Shows everything about a tapped card: name, suit/rank, level, stats,
## ability text with the value for the current level, and active statuses.

var _title: Label
var _subtitle: Label
var _body: RichTextLabel


func _init() -> void:
	custom_minimum_size = Vector2(620, 0)
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
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size = Vector2(120, 48)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(hide)
	header.add_child(close)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Palette.MUTED)
	column.add_child(_subtitle)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.add_theme_font_size_override("bold_font_size", 20)
	_body.add_theme_color_override("default_color", Palette.PARCHMENT)
	column.add_child(_body)
	# Taps go through the panel (to the cards underneath); only "close" reacts.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Control in [column, header, _title, _subtitle, _body]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_card(card: UnitCard) -> void:
	var definition := card.definition
	var snapshot := card.snapshot
	_title.text = tr(ContentDb.name_key(definition))
	var level: int = snapshot.get("level", 1)
	if card.is_enemy:
		_subtitle.text = "%s · %s" % [tr("UI_ENEMY"), tr("UI_LEVEL") % level]
	else:
		_subtitle.text = "%s · %s · %s" % [
			tr("RANK_" + String(definition["rank"]).to_upper()),
			tr("SUIT_" + String(definition["suit"]).to_upper()),
			tr("UI_LEVEL") % level,
		]

	var lines: Array[String] = []
	lines.append(Keywords.colorize(tr("UI_STATS") % [snapshot["effective_attack"], maxi(snapshot["health"], 0), snapshot["max_health"]]))
	var multiplier: float = snapshot.get("multiplier", 1.0)
	if absf(multiplier - 1.0) > 0.001:
		lines.append(tr("UI_MULTIPLIER") % NumberFormat.decimal(multiplier))
	if definition.has("ability"):
		var ability: Dictionary = definition["ability"]
		var values: Array = ability["values"]
		var value: float = values[mini(level, values.size()) - 1]
		var text := tr("ABIL_" + String(definition["id"]).to_upper())
		lines.append("[b]" + Keywords.colorize(text.replace("{v}", NumberFormat.ability_value(ability["effect"], value))) + "[/b]")
	var statuses: Dictionary = snapshot.get("statuses", {})
	for status in UnitCard.STATUS_ORDER:
		if statuses.get(status, 0) > 0:
			var color := Emblem.COLORS[status] as Color
			lines.append("[color=#%s]%s %d[/color] – %s" % [
				color.to_html(false), tr("STATUS_" + status.to_upper()), statuses[status],
				Keywords.colorize(tr("STATUS_%s_DESC" % status.to_upper())),
			])
	_body.text = "\n".join(lines)
	show()
