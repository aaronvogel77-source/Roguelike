class_name DetailPanel
extends PanelContainer
## Shows everything about a tapped card: name, suit/rank, level, stats,
## ability text with the value for the current level, and active statuses.

var _title: Label
var _subtitle: HBoxContainer
var _body: RichTextLabel
var _figures: Dictionary = {}  # figure definitions for fusion texts (loaded once)
## Left: a big picture of the card; below the text: the symbols it uses,
## each tappable for a one-line explanation.
var _visual: CenterContainer
var _legend: HBoxContainer
var _explain: RichTextLabel
## Optional action under the info (e.g. "Buy & open" for a pack).
var _action: Button
var _action_call: Callable
static var _db: ContentDb
## Suit counts of the player's row (set by the run screen) for the suit
## bonus explanations; the suits of the unit shown right now.
static var suit_counts: Dictionary = {}
var _pending_suits: Array = []

## Colors of the object categories, used everywhere the category is named.
const CATEGORY_COLORS := {
	"equipment": Color("b8c8dc"), "blessing": Color("ffd25a"), "tarot": Color(0.8, 0.65, 0.95),
	"relic": Color(0.4, 0.85, 0.8), "pact": Color(0.9, 0.3, 0.38), "ability": Color("e0b44a"),
}


## A category label in its color, e.g. "Ausrüstung:".
func _tag(key: String, color: Color) -> String:
	return "[b][color=#%s]%s:[/color][/b]" % [color.to_html(false), tr(key)]


func _init() -> void:
	custom_minimum_size = Vector2(860, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.97)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 16)
	add_theme_stylebox_override("panel", style)

	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	_visual = CenterContainer.new()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_visual)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(column)

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
	_legend = HBoxContainer.new()
	_legend.add_theme_constant_override("separation", 8)
	column.add_child(_legend)
	_explain = RichTextLabel.new()
	_explain.bbcode_enabled = true
	_explain.fit_content = true
	_explain.scroll_active = false
	_explain.add_theme_font_size_override("normal_font_size", 20)
	_explain.add_theme_color_override("default_color", Palette.MUTED)
	_explain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_explain)
	_action = Button.new()
	_action.custom_minimum_size = Vector2(300, 56)
	_action.add_theme_font_size_override("font_size", 22)
	_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_action.pressed.connect(func() -> void:
		var call := _action_call
		hide()
		if call.is_valid():
			call.call())
	_action.hide()
	column.add_child(_action)
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
	var enemy_label := tr("UI_ELITE") if is_enemy and int(definition.get("min_act", 1)) >= 2 else tr("UI_ENEMY")
	var texts: Array = [enemy_label] if is_enemy else [
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

	# Short and to the point: what it does first, then the numbers, then where bonuses come from.
	var lines: Array[String] = []
	if definition.has("fusion"):
		lines.append_array(_fusion_lines(definition["fusion"], level))
	elif definition.has("ability"):
		var ability: Dictionary = definition["ability"]
		var values: Array = ability["values"]
		var value: float = values[mini(level, values.size()) - 1]
		var text := tr("ABIL_" + String(definition["id"]).to_upper())
		lines.append("[b]" + Keywords.colorize(text.replace("{v}", NumberFormat.ability_value(ability["effect"], value))) + "[/b]")
	var stats := tr("UI_STATS") % [snapshot["effective_attack"], maxi(snapshot["health"], 0), snapshot["max_health"]]
	var multiplier: float = snapshot.get("multiplier", 1.0)
	if absf(multiplier - 1.0) > 0.001:
		stats += " · ×" + NumberFormat.decimal(multiplier)
	if extras.has("base_attack") and (int(extras["base_attack"]) != int(snapshot["effective_attack"])
			or int(extras["base_health"]) != int(snapshot["max_health"])):
		stats += "  [color=#%s]%s[/color]" % [Palette.MUTED.to_html(false), tr("UI_STATS_BASE") % [extras["base_attack"], extras["base_health"]]]
	lines.append(Keywords.colorize(stats))
	var statuses: Dictionary = snapshot.get("statuses", {})
	var status_parts: Array = []
	for status in UnitCard.STATUS_ORDER:
		if statuses.get(status, 0) > 0:
			status_parts.append("[color=#%s]%s %d[/color]" % [(Emblem.COLORS[status] as Color).to_html(false),
				tr("STATUS_" + status.to_upper()), statuses[status]])
	if not status_parts.is_empty():
		lines.append(" · ".join(status_parts))
	var figure: Dictionary = extras.get("figure", {})
	if not figure.is_empty():
		# Every category in its own color; equipment also shows its rarity.
		if figure.has("xp") and RunState.objects_on(figure) > 0:  # object slots only when something is equipped
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
		var suit_names: Array = []
		for source in extras.get("sources", []):
			if source == "tarot_strength":
				continue
			elif source in ["plague", "curse_fog"]:
				lines.append("%s %s" % [_tag("UI_CAT_DANGER", Color(0.7, 0.45, 0.85)), Keywords.colorize(tr("SOURCE_" + String(source).to_upper()))])
			elif String(source).begins_with("region_"):
				lines.append("%s %s" % [_tag("UI_CAT_BLESSING", CATEGORY_COLORS["blessing"]), tr("SOURCE_" + String(source).to_upper())])
			elif String(source).begins_with("suit_"):
				suit_names.append(tr("SUIT_" + String(source).substr(5).to_upper()))
			elif source in extras["db"].items["pacts"]:
				pact_names.append(tr("PACT_" + String(source).to_upper()))
			else:
				relic_names.append(ItemText.relic_name(source))
		if not suit_names.is_empty():
			lines.append("%s %s" % [_tag("UI_CAT_SUIT_BONUS", CATEGORY_COLORS["ability"]), ", ".join(suit_names)])
		if not relic_names.is_empty():
			lines.append("%s [color=#%s]%s[/color]" % [_tag("UI_CAT_RELICS", CATEGORY_COLORS["relic"]),
				CATEGORY_COLORS["relic"].to_html(false), ", ".join(relic_names)])
		if not pact_names.is_empty():
			lines.append("%s [color=#%s]%s[/color]" % [_tag("UI_CAT_PACTS", CATEGORY_COLORS["pact"]),
				CATEGORY_COLORS["pact"].to_html(false), ", ".join(pact_names)])
	_body.text = "\n".join(lines)
	var level_card := UnitCard.for_definition(definition, level, is_enemy)
	_set_visual(level_card, 1.15)
	_pending_suits = [] if is_enemy else snapshot.get("suits", [snapshot.get("suit", definition.get("suit", ""))])
	_open()


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
		var at := maxi(level, int(fusion.get("ability_levels", {}).get(id, 1)))
		var value: float = values[mini(at, values.size()) - 1]
		var text := tr("ABIL_" + String(id).to_upper()).replace("{v}", NumberFormat.ability_value(ability["effect"], value))
		lines.append("[b]" + Keywords.colorize(text) + "[/b] " + tr("UI_ABILITY_LEVEL") % ["", "I", "II", "III"][clampi(at, 1, 3)])
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
	_set_visual(null, 1.0)
	_open()


## Adds a hint line under the current content (e.g. how to use a tarot card).
func show_hint(text: String) -> void:
	_body.text += "\n[color=#%s]%s[/color]" % [Palette.GOLD.to_html(false), text]


## Shows an object (relic, tarot, equipment) in the same panel.
func show_object(object_card: ObjectCard) -> void:
	_title.text = object_card.title
	for child in _subtitle.get_children():
		child.queue_free()
	_body.text = "\n".join(object_card.lines.map(func(l: String) -> String: return Keywords.colorize(l)))
	if _db == null:
		_db = ContentDb.load_default()
	_set_visual(ObjectCard.create(_db, object_card.entry, Vector2(120, 178)), 1.0)
	_open()


## The picture on the left (null = none), scaled.
func _set_visual(control: Control, factor: float) -> void:
	for child in _visual.get_children():
		child.queue_free()
	_visual.visible = control != null
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in control.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(control)
	control.scale = Vector2(factor, factor)
	var base := control.custom_minimum_size if control.custom_minimum_size != Vector2.ZERO else control.get_combined_minimum_size()
	holder.custom_minimum_size = base * factor
	_visual.add_child(holder)


## Shows the panel with a symbol legend for the current text.
func _open() -> void:
	_action.hide()
	for child in _legend.get_children():
		child.queue_free()
	_explain.text = ""
	var found := RegEx.create_from_string("keywords/(\\w+)\\.png").search_all(_body.text)
	var kinds: Array = []
	for match in found:
		if not match.get_string(1) in kinds:
			kinds.append(match.get_string(1))
	for kind: String in kinds:
		var chip := Button.new()
		chip.icon = load(Keywords.ICON_PATH % kind)
		chip.text = tr(LEGEND_NAMES[kind])
		chip.add_theme_font_size_override("font_size", 18)
		chip.custom_minimum_size = Vector2(0, 48)
		chip.pressed.connect(func() -> void:
			_explain.text = "%s [b]%s:[/b] %s" % [Keywords.icon(kind, 22), tr(LEGEND_NAMES[kind]), tr(LEGEND_DESCS[kind])])
		_legend.add_child(chip)
	# Suit bonus of the figure's family (all suits for a fusion).
	for suit in _pending_suits:
		if not SUIT_KEYS.has(suit):
			continue
		var chip := Button.new()
		chip.text = tr("UI_SUIT_BONUS_CHIP") % tr("SUIT_" + String(suit).to_upper())
		chip.add_theme_font_size_override("font_size", 18)
		chip.add_theme_color_override("font_color", Palette.SUIT_COLORS.get(suit, Palette.PARCHMENT))
		chip.custom_minimum_size = Vector2(0, 48)
		chip.pressed.connect(func() -> void:
			_explain.text = "[b]%s:[/b] %s %s" % [tr("SUIT_" + String(suit).to_upper()), tr(SUIT_KEYS[suit]),
				tr("UI_SUIT_BONUS_NOW") % int(suit_counts.get(suit, 0))])
		_legend.add_child(chip)
	_pending_suits = []
	_legend.visible = _legend.get_child_count() > 0
	show()


const SUIT_KEYS := {"coins": "SUIT_BONUS_COINS", "cups": "SUIT_BONUS_CUPS", "swords": "SUIT_BONUS_SWORDS",
	"wands": "SUIT_BONUS_WANDS"}


const LEGEND_NAMES := {"shield": "STATUS_SHIELD", "burn": "STATUS_BURN", "bleed": "STATUS_BLEED", "curse": "STATUS_CURSE",
	"attack": "KW_ATTACK", "health": "KW_HEALTH", "gold": "KW_GOLD"}
const LEGEND_DESCS := {"shield": "STATUS_SHIELD_DESC", "burn": "STATUS_BURN_DESC", "bleed": "STATUS_BLEED_DESC",
	"curse": "STATUS_CURSE_DESC", "attack": "KW_ATTACK_DESC", "health": "KW_HEALTH_DESC", "gold": "KW_GOLD_DESC"}


func _subtitle_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Palette.MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Adds an action button to the info shown right now.
func show_action(text: String, call: Callable, enabled := true) -> void:
	_action.text = text
	_action_call = call
	_action.disabled = not enabled
	_action.show()


func _notification(what: int) -> void:
	# While a card is dragged the info steps aside (it would cover the targets).
	if what == NOTIFICATION_DRAG_BEGIN and visible:
		hide()
