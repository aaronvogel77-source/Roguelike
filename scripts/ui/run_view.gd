extends Control
## The run screen: enemy choice, planning/shop, battle, reward and run end.
## All rules live in RunState; this script only shows them and forwards input.

const STAGE_NAMES := ["UI_FIGHT_SMALL", "UI_FIGHT_BIG", "UI_FIGHT_BOSS"]
const DIFFICULTY_NAMES := ["UI_EASY", "UI_MEDIUM", "UI_HARD"]
const ROW_GAP := 56
const CARD_SPACING := 6
const BattleScene := preload("res://scenes/battle.tscn")

var _db: ContentDb
var _run: RunState
var _undo: Array = []  # RunState.to_dict() snapshots taken before shop actions
var _selected: Dictionary = {}  # {"kind": "row"/"shop", "index": int}
var _sell_armed := -1  # row index whose sale awaits a confirming second tap

var _screen: Control
var _detail_panel: DetailPanel
var _battle_view: Control


func _ready() -> void:
	TranslationServer.set_locale("de")
	theme = UiTheme.build()
	_db = ContentDb.load_default()
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_detail_panel = DetailPanel.new()
	_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_detail_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_panel.position.y += 64
	add_child(_detail_panel)
	_new_run()


func _new_run() -> void:
	var seed_value := _url_seed()
	if seed_value < 0:
		seed_value = randi() % 1000000
	_run = RunState.new_run(_db, seed_value)
	_undo.clear()
	_show_stage()
	_show_region_intro()


## Interstitial before entering a region: background, name, mood, blessing,
## enemy themes and bosses.
func _show_region_intro() -> void:
	var region: Dictionary = _db.regions[_run.region]
	var key := "REGION_" + _run.region.to_upper()
	var overlay := RegionBackdrop.new()
	overlay.suit = _run.region
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	overlay.add_child(column)
	var emblem := Emblem.create("suit_" + _run.region, 110)
	var emblem_box := CenterContainer.new()
	emblem_box.add_child(emblem)
	column.add_child(emblem_box)
	for line in [[tr(key), 56, Palette.GOLD], [tr(key + "_DESC"), 22, Palette.PARCHMENT]]:
		var label := _label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		column.add_child(label)
	var themes: Array = region.get("themes", []).map(func(t: String) -> String: return tr("THEME_" + t.to_upper()))
	var bosses: Array = []
	for boss in _db.bosses.values():
		if boss["region"] == _run.region:
			bosses.append(tr("BOSS_" + String(boss["id"]).to_upper()))
	for text in [tr("BLESSING_" + _run.region.to_upper()), tr("UI_REGION_ENEMIES") % ", ".join(themes), tr("UI_REGION_BOSSES") % ", ".join(bosses)]:
		var line := _rich_line(text, 22)
		line.custom_minimum_size = Vector2(900, 0)
		var line_box := CenterContainer.new()
		line_box.add_child(line)
		column.add_child(line_box)
	var enter := _button(tr("UI_ENTER_REGION"), Vector2(280, 72), overlay.queue_free)
	enter.add_theme_font_size_override("font_size", 28)
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(enter)
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.4)


func _show_stage() -> void:
	_selected = {}
	_sell_armed = -1
	_detail_panel.hide()
	for child in _screen.get_children():
		child.queue_free()
	match _run.stage:
		RunState.Stage.ENEMY_CHOICE:
			_build_enemy_choice()
		RunState.Stage.PLANNING:
			_build_planning()
			if not _run.open_pack.is_empty():
				_build_pack_overlay()
		RunState.Stage.REWARD:
			_build_reward()
		RunState.Stage.EVENT:
			_build_event()
			if not _run.open_pack.is_empty():
				_build_pack_overlay()
		RunState.Stage.WON, RunState.Stage.LOST:
			_build_run_end()


# --- Shared building blocks ----------------------------------------------------------

func _top_bar(title: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 60)
	bar.add_theme_constant_override("separation", 28)
	bar.add_child(_spacer(8))
	bar.add_child(_label(title, 30, Palette.GOLD))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	bar.add_child(_label(tr("UI_GOLD") % _run.gold, 30, Palette.GOLD))
	bar.add_child(_label(tr("UI_INTEREST") % _run.interest(), 20, Palette.MUTED))
	bar.add_child(_label(tr("UI_SLOTS") % [_filled_slots(), _run.slot_count()], 22, Palette.PARCHMENT))
	var souls := HBoxContainer.new()
	souls.add_child(Emblem.create("soul", 26))
	souls.add_child(_label(tr("UI_SOULS") % _run.souls, 22, Emblem.COLORS["soul"]))
	bar.add_child(souls)
	if _url_flag("debug"):
		# Debug tools in a compact row (small font).
		var tools := HBoxContainer.new()
		tools.add_theme_constant_override("separation", 4)
		var entries := [["+10 Gold", _debug_gold], ["Boss", _debug_to_boss], [tr("UI_DEBUG_EVENT"), _debug_event], ["+5 " + tr("UI_PACTS_SOULS"), _debug_souls], ["Unikat", _debug_unique]]
		if _run.stage == RunState.Stage.PLANNING:
			entries.insert(2, ["Legende", _debug_legend])
		for entry in entries:
			var button := _button(entry[0], Vector2(0, 40), entry[1])
			button.add_theme_font_size_override("font_size", 13)
			tools.add_child(button)
		bar.add_child(tools)
	bar.add_child(_spacer(8))
	return bar


# --- Debug tools ("?debug=1" in the address) ---------------------------------------

## Starts the next event in the list (cycles through all eight).
func _debug_event() -> void:
	var ids: Array = _db.items["events"]["ids"]
	var current: String = _run.event.get("id", ids[-1])
	_run.start_event(ids[(ids.find(current) + 1) % ids.size()])
	_event_option = ""
	_undo.clear()
	_show_stage()


## Cursed well with +10 gold; throwing in 10 gold surely gives a unique item.
func _debug_unique() -> void:
	_run.gold += 10
	_run.flags["force_unique"] = true
	_run.start_event("cursed_well")
	_event_option = ""
	_undo.clear()
	_show_stage()


func _debug_souls() -> void:
	_run.souls += 5
	_show_stage()


func _debug_legend() -> void:
	_run.debug_legend_pack()
	_undo.clear()
	_show_stage()


func _debug_gold() -> void:
	_run.gold += 10
	_show_stage()


## Wins every fight until the next boss choice (for testing bosses quickly).
func _debug_to_boss() -> void:
	var guard := 0
	while guard < 20 and not (_run.stage == RunState.Stage.PLANNING and _run.is_boss_fight()):
		guard += 1
		match _run.stage:
			RunState.Stage.ENEMY_CHOICE:
				_run.choose_enemy(0)
			RunState.Stage.PLANNING:
				_run.apply_battle_result({"victory": true, "gold_after": _run.gold})
			RunState.Stage.REWARD:
				_run.skip_reward()
			_:
				break
	_undo.clear()
	_show_stage()


func _url_flag(flag: String) -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("window.location.search", true)).contains(flag + "=1")


## Region blessing, plus the boss rule when the chosen enemy is a boss.
func _info_line() -> Control:
	var text := tr("REGION_" + _run.region.to_upper()) + " · " + tr("BLESSING_" + _run.region.to_upper())
	if _rule_text() != "":
		text += "   ·   " + _rule_text()
	return _rich_line(text, 17)


func _boss_name() -> String:
	var boss_id: String = _run.chosen_enemy.get("boss_id", "")
	return tr("BOSS_" + boss_id.to_upper()) if boss_id != "" else ""


func _rule_text() -> String:
	var boss_id: String = _run.chosen_enemy.get("boss_id", "")
	if boss_id == "":
		return ""
	return tr("UI_BOSS_RULE") % tr("BOSS_" + boss_id.to_upper() + "_RULE")


## Centered one-line text with colored keywords.
func _rich_line(text: String, font_size: int) -> RichTextLabel:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	line.custom_minimum_size = Vector2(320, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", font_size)
	line.add_theme_color_override("default_color", Palette.PARCHMENT)
	line.text = "[center]" + Keywords.colorize(text) + "[/center]"
	return line


func _stage_title() -> String:
	return tr("UI_ACT_FIGHT") % [_run.act, _run.fight + 1, RunState.FIGHTS_PER_ACT, tr(STAGE_NAMES[_run.fight])]


func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	_screen.add_child(column)
	return column


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
	return spacer


## Wraps a control so it is drawn scaled (containers would reset the scale).
func _scaled(content: Control, factor: float) -> Control:
	var holder := Control.new()
	holder.add_child(content)
	content.scale = Vector2(factor, factor)
	var minimum := content.get_combined_minimum_size()
	content.size = minimum
	holder.custom_minimum_size = minimum * factor
	return holder


## A row of static cards (enemy teams, own team previews), front at `front_end`.
func _card_row(entries: Array, enemy: bool, reverse: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_SPACING)
	var list := entries.duplicate()
	if reverse:
		list.reverse()
	for entry in list:
		var definition: Dictionary = _db.enemies[entry["def_id"]] if enemy else _db.figures[entry["def_id"]]
		var card := UnitCard.for_definition(definition, entry["level"], enemy)
		card.tapped.connect(_detail_panel.show_card)
		row.add_child(card)
	return row


func _own_team_entries() -> Array:
	var entries: Array = []
	for figure in _run.row:
		if figure != null:
			entries.append({"def_id": figure["def_id"], "level": _run.figure_level(figure)})
	return entries


func _filled_slots() -> int:
	return _run.row.filter(func(f: Variant) -> bool: return f != null).size()


func _url_seed() -> int:
	if not OS.has_feature("web"):
		return -1
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	var match := RegEx.create_from_string("seed=(\\d+)").search(query)
	return int(match.get_string(1)) if match != null else -1


# --- Enemy choice -----------------------------------------------------------------

func _build_enemy_choice() -> void:
	var column := _column()
	column.add_child(_top_bar(_stage_title()))
	column.add_child(_info_line())
	var title := _label(tr("UI_CHOOSE_ENEMY"), 24, Palette.PARCHMENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 20)
	# Scales down when the options (3 enemies + skip) do not fit the width.
	column.add_child(_fitted(options, 1.0))
	for i in _run.enemy_options.size():
		options.add_child(_enemy_option_panel(_run.enemy_options[i], i))
	if not _run.is_boss_fight():
		options.add_child(_skip_panel())

	var own := HBoxContainer.new()
	own.alignment = BoxContainer.ALIGNMENT_CENTER
	own.add_theme_constant_override("separation", 16)
	own.add_child(_label(tr("UI_YOUR_TEAM"), 20, Palette.MUTED))
	own.add_child(_scaled(_card_row(_own_team_entries(), false, true), 0.62))
	column.add_child(own)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


## Skip the fight for the mark shown here (no gold, no experience).
func _skip_panel() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.14)
	style.border_color = Emblem.COLORS["tarot"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(220, 0)
	panel.add_child(box)
	var title := _label(tr("UI_SKIP"), 22, Emblem.COLORS["tarot"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := _label(tr("UI_SKIP_INFO"), 15, Palette.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var mark: String = _run.enemy_options[0].get("skip_mark", "")
	var mark_line := _rich_line(tr("MARK_" + mark.to_upper()), 18)
	mark_line.custom_minimum_size = Vector2(220, 0)
	box.add_child(mark_line)
	var skip := _button(tr("UI_SKIP"), Vector2(180, 56), _on_skip_fight)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(skip)
	return panel


func _on_skip_fight() -> void:
	if _run.skip_fight():
		_undo.clear()
		_show_stage()


func _enemy_option_panel(option: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.HEALTH if option["kind"] == "boss" else Color(1, 1, 1, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 12)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var heading := tr("UI_FIGHT_BOSS") if option["kind"] == "boss" else tr(DIFFICULTY_NAMES[option["difficulty"]])
	var title := _label("%s · %s" % [heading, tr("UI_BONUS_GOLD") % option["bonus"]], 22, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if option["kind"] == "boss" and option.get("boss_id", "") != "":
		var boss_key := "BOSS_" + String(option["boss_id"]).to_upper()
		var boss_name := _label(tr(boss_key), 24, Palette.HEALTH)
		boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(boss_name)
		box.add_child(_rich_line(tr("UI_BOSS_RULE") % tr(boss_key + "_RULE"), 18))
	elif option.get("theme", "") != "":
		var theme_label := _label(tr("THEME_" + String(option["theme"]).to_upper()), 18, Palette.PARCHMENT)
		theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(theme_label)
	if option["kind"] == "boss":
		var note := _label(tr("UI_BOSS_SLOT_NOTE"), 16, Palette.PARCHMENT)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
	# Cards as large as the panel allows: up to full size, never wider than ~340 px.
	var widths := 0
	for unit in option["team"]:
		widths += int(_db.enemies[unit["def_id"]].get("width", 1))
	var team_width: float = widths * (UnitCard.CARD_SIZE.x + CARD_SPACING)
	var max_width := 340.0 if _run.enemy_options.size() > 1 else 900.0
	var factor := clampf(max_width / maxf(team_width, 1.0), 0.5, 1.0)
	var cards := CenterContainer.new()
	cards.custom_minimum_size = Vector2(max_width if _run.enemy_options.size() > 1 else 0.0, 0)
	cards.add_child(_scaled(_card_row(option["team"], true, false), factor))
	box.add_child(cards)
	var choose := _button(tr("UI_CHOOSE"), Vector2(200, 60), _on_choose_enemy.bind(index))
	choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(choose)
	return panel


func _on_choose_enemy(index: int) -> void:
	if _run.choose_enemy(index):
		_undo.clear()
		_show_stage()


# --- Planning (shop + arranging) -----------------------------------------------------

var _row_slots: Array[SlotView] = []
var _shop_slots: Array[SlotView] = []
var _sell_zone: SellZone
var _undo_button: Button


func _build_planning() -> void:
	var column := _column()
	column.add_child(_top_bar(_stage_title()))
	column.add_child(_info_line())
	column.add_child(_object_strip())

	# Battle field preview: own slots (front next to the middle) and the chosen
	# enemy. Scaled up to fill the free space, so cards are as large as possible.
	var field := HBoxContainer.new()
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", ROW_GAP)
	var own_box := VBoxContainer.new()
	own_box.alignment = BoxContainer.ALIGNMENT_CENTER
	own_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	own_box.add_child(_label(tr("UI_YOUR_TEAM_FRONT"), 16, Palette.MUTED))
	own_box.add_child(_own_row_slots())
	own_box.add_child(_xp_hint_row())
	field.add_child(own_box)
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_box.add_child(_label(tr("UI_NEXT_ENEMY"), 16, Palette.MUTED))
	enemy_box.add_child(_card_row(_run.chosen_enemy["team"], true, false))
	field.add_child(enemy_box)
	column.add_child(_fitted(field, 1.7))

	# Shop and actions.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	bottom.custom_minimum_size = Vector2(0, 200)
	bottom.add_child(_label(tr("UI_SHOP"), 22, Palette.GOLD))
	_shop_slots.clear()
	for i in _run.shop.size():
		var shop_box := VBoxContainer.new()
		var slot := SlotView.new("shop", i)
		if _run.shop[i] != "":
			slot.set_card(UnitCard.for_definition(_db.figures[_run.shop[i]], 1, false))
			_add_rarity_effect(slot, _run.shop[i])
		slot.accepts_drops = false
		slot.tapped.connect(_on_slot_tapped)
		shop_box.add_child(slot)
		var price := _label(tr("UI_PRICE") % _run.price_of(_run.shop[i]) if _run.shop[i] != "" else "", 20, Palette.GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_box.add_child(price)
		bottom.add_child(shop_box)
		_shop_slots.append(slot)

	for i in _run.packs.size():
		bottom.add_child(_pack_view(i))
	bottom.add_child(_soul_pack_view())

	_sell_zone = SellZone.new()
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	bottom.add_child(_sell_zone)

	var actions := GridContainer.new()
	actions.columns = 1
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	var reroll := _button(tr("UI_REROLL") % _run.reroll_price(), Vector2(200, 56), _on_reroll)
	reroll.disabled = _run.gold < _run.reroll_price()
	actions.add_child(reroll)
	_undo_button = _button(tr("UI_UNDO"), Vector2(200, 56), _on_undo)
	_undo_button.disabled = _undo.is_empty()
	actions.add_child(_undo_button)
	bottom.add_child(actions)

	if _run.can_skip_boss():
		var skip_boss := _button(tr("UI_SKIP_BOSS"), Vector2(200, 56), _on_skip_boss)
		skip_boss.add_theme_font_size_override("font_size", 15)
		actions.add_child(skip_boss)
	var fight := _button(tr("UI_FIGHT"), Vector2(170, 124), _on_fight)
	fight.add_theme_font_size_override("font_size", 30)
	fight.disabled = _filled_slots() == 0
	bottom.add_child(fight)
	column.add_child(bottom)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


## The player's row as interactive slots (back on the left, front on the right).
func _own_row_slots() -> HBoxContainer:
	var own_row := HBoxContainer.new()
	own_row.add_theme_constant_override("separation", CARD_SPACING)
	_row_slots.clear()
	var entries := _row_entries()
	for i in range(_run.slot_count() - 1, -1, -1):
		var slot := SlotView.new("row", i)
		var figure: Variant = _run.row[i]
		if figure != null:
			slot.set_card(UnitCard.for_entry(entries[i], figure, _db))
		slot.tapped.connect(_on_slot_tapped)
		slot.dropped.connect(_on_slot_dropped)
		slot.inserted.connect(_on_slot_inserted)
		own_row.add_child(slot)
		_row_slots.append(slot)
	return own_row


## Battle entries (with equipment, boons, relics) by row index.
func _row_entries() -> Dictionary:
	var team := _run.player_battle_team()
	var result := {}
	var k := 0
	for i in _run.row.size():
		if _run.row[i] != null:
			result[i] = team[k]
			k += 1
	return result


## A holder that fills the free space and scales its content to fit
## (up to max_factor). Containers would reset the scale, so it is done by hand.
func _fitted(content: Control, max_factor: float) -> Control:
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(content)
	var fit := func() -> void:
		content.size = content.get_combined_minimum_size()
		var factor := minf(holder.size.x / maxf(content.size.x + 24.0, 1.0), holder.size.y / maxf(content.size.y, 1.0))
		factor = clampf(factor, 0.6, max_factor)
		content.scale = Vector2(factor, factor)
		content.position = (holder.size - content.size * factor) / 2
	holder.resized.connect(fit)
	fit.call_deferred()
	return holder


## Small "XP" bars under the row slots (front on the right, like the slots).
func _xp_hint_row() -> HBoxContainer:
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", CARD_SPACING)
	for i in range(_run.slot_count() - 1, -1, -1):
		var label := _label("", 13, Palette.MUTED)
		label.custom_minimum_size = Vector2(UnitCard.CARD_SIZE.x, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var figure: Variant = _run.row[i]
		if figure != null:
			label.text = _xp_text(figure)
		hints.add_child(label)
	return hints


func _xp_text(figure: Dictionary) -> String:
	var level := _run.figure_level(figure)
	if level >= 3:
		return tr("UI_MAX_LEVEL")
	var xp := int(figure["xp"])
	var needed: int = RunState.XP_FOR_LEVEL[level]
	return tr("UI_XP") % [NumberFormat.decimal(xp / 3.0), NumberFormat.decimal(needed / 3.0)]


func _slot_for(kind: String, index: int) -> SlotView:
	var slots := _row_slots if kind == "row" else _shop_slots
	for slot in slots:
		if slot.index == index:
			return slot
	return null


func _select(kind: String, index: int) -> void:
	_clear_selection()
	_selected = {"kind": kind, "index": index}
	var slot := _slot_for(kind, index)
	if slot != null:
		slot.set_selected(true)
		if slot.card != null:
			_detail_panel.show_card(slot.card)
	if kind == "row":
		var figure: Dictionary = _run.row[index]
		_sell_zone.show_text(tr("UI_SELL_FOR") % _run.sell_value(figure), true)


func _clear_selection() -> void:
	for slot in _row_slots + _shop_slots:
		slot.set_selected(false)
	for object_card in _strip_cards:
		object_card.set_selected(false)
	_selected = {}
	_sell_armed = -1
	if _sell_zone != null:
		_sell_zone.show_text(tr("UI_SELL_ZONE"), false)
	_detail_panel.hide()


func _on_skip_boss() -> void:
	_clear_selection()
	_selected = {"kind": "boss_skip", "index": -1}
	_detail_panel.show_message(tr("UI_SKIP_BOSS"), tr("UI_SKIP_BOSS_HINT"))


func _on_slot_tapped(slot: SlotView) -> void:
	if _run.stage == RunState.Stage.EVENT:
		_on_event_row_tapped(slot)
		return
	if _selected.get("kind") == "boss_skip":
		if slot.card != null and _run.skip_boss(slot.index):
			_undo.clear()
			_show_stage()
		else:
			_clear_selection()
		return
	if slot.kind == "shop":
		if slot.card == null or (_selected.get("kind") == "shop" and _selected["index"] == slot.index):
			_clear_selection()
		else:
			_select("shop", slot.index)
		return
	# Row slot: use a selected tarot card, complete a pending buy or move, otherwise select.
	if _selected.get("kind") == "tarot":
		var tarot_index: int = _selected["index"]
		var card_id: String = _run.tarots[tarot_index]
		var before_xp := int(_run.row[slot.index]["xp"]) if _run.row[slot.index] != null else 0
		var snapshot := _run.to_dict()
		if _run.use_tarot(tarot_index, slot.index):
			_undo.append(snapshot)  # tarot use can be undone (the RNG state is restored too)
			_show_stage()
			if card_id == "magician" and _run.row[slot.index] != null:
				_show_merge(_run.row[slot.index]["def_id"], before_xp, int(_run.row[slot.index]["xp"]))
		else:
			_clear_selection()
			if slot.card != null:
				_detail_panel.show_message(ItemText.tarot_name(card_id), tr("UI_OBJECT_LIMIT") % RunState.MAX_OBJECTS)
		return
	if _selected.get("kind") == "shop":
		_buy(_selected["index"], slot.index)
	elif _selected.get("kind") == "row" and _selected["index"] != slot.index:
		_move(_selected["index"], slot.index)
	elif _selected.get("kind") == "row":
		_clear_selection()
	elif slot.card != null:
		_select("row", slot.index)


func _on_slot_dropped(data: Dictionary, slot: SlotView) -> void:
	if data["kind"] == "shop":
		_buy(data["index"], slot.index)
	elif data["kind"] == "row":
		_move(data["index"], slot.index)
	elif data["kind"] == "pack":
		_pack_pick = data["index"]
		_on_pack_target(slot)
	elif data["kind"] == "market_figure":
		if _run.resolve_event("buy_figure", [slot.index]):
			_show_stage()


## Dropped between two cards: the figure is inserted there. Visually the
## front is on the right, so "left of a card" means behind it.
func _on_slot_inserted(data: Dictionary, slot: SlotView, side: String) -> void:
	var after_index := slot.index if side == "left" else slot.index - 1
	var from: int = data["index"]
	_apply_action(func() -> bool: return _run.insert_between(from, after_index))


## Moves (or swaps) row figures; dropping onto an equal figure merges them.
func _move(from_index: int, to_index: int) -> void:
	var target: Variant = _run.row[to_index] if to_index < _run.row.size() else null
	var source: Variant = _run.row[from_index] if from_index < _run.row.size() else null
	var merging: bool = target != null and source != null and target["def_id"] == source["def_id"]
	var before_xp := int(target["xp"]) if merging else -1
	_apply_action(func() -> bool: return _run.move(from_index, to_index))
	if merging and _run.row[from_index] == null:
		_show_merge(_run.row[to_index]["def_id"], before_xp, int(_run.row[to_index]["xp"]))


## Buys a shop figure; shows the merge screen when it joined an equal figure.
func _buy(shop_index: int, row_index: int) -> void:
	var before: Variant = _run.row[row_index] if row_index < _run.row.size() else null
	var before_xp := int(before["xp"]) if before != null else -1
	_apply_action(func() -> bool: return _run.buy(shop_index, row_index))
	var after: Variant = _run.row[row_index] if row_index < _run.row.size() else null
	if before != null and after != null and int(after["xp"]) > before_xp:
		_show_merge(after["def_id"], before_xp, int(after["xp"]))


## Runs an undoable shop action; rebuilds the screen if it succeeded.
func _apply_action(action: Callable) -> void:
	var snapshot := _run.to_dict()
	if action.call():
		_undo.append(snapshot)
		_show_stage()
	else:
		_clear_selection()


func _on_sell_zone_tapped() -> void:
	if _selected.get("kind") == "row":
		_request_sell(_selected["index"])
	elif _selected.get("kind") == "relic":
		if _run.sell_relic(_selected["index"]):
			_undo.clear()
			_show_stage()


## Sells a row figure. A levelled figure (stage 2+) needs a second confirmation.
func _request_sell(index: int) -> void:
	var figure: Variant = _run.row[index] if index < _run.row.size() else null
	if figure == null:
		return
	if _run.figure_level(figure) >= 2 and _sell_armed != index:
		_select("row", index)
		_sell_armed = index
		_sell_zone.show_text(tr("UI_SELL_CONFIRM") % _run.sell_value(figure), true)
		return
	_apply_action(func() -> bool: return _run.sell(index))


func _on_undo() -> void:
	if _undo.is_empty():
		return
	_run = RunState.from_dict(_db, _undo.pop_back())
	_show_stage()


func _on_reroll() -> void:
	if _run.reroll():
		_undo.clear()  # rerolls are final: no undoing into old offers
		_show_stage()


func _on_fight() -> void:
	_undo.clear()
	_detail_panel.hide()
	_battle_view = BattleScene.instantiate()
	_battle_view.sandbox = false
	add_child(_battle_view)
	_battle_view.finished.connect(_on_battle_finished)
	_battle_view.play_battle(_run.player_battle_team(), _run.enemy_battle_team(), _run.gold,
		_footer_text(), _run.battle_options(), _rule_text(), _boss_name())


func _on_battle_finished(result: Dictionary) -> void:
	_battle_view.queue_free()
	_battle_view = null
	_run.apply_battle_result(result)
	_show_stage()


# --- Relics, tarot, packs ---------------------------------------------------------------

var _strip_cards: Array[ObjectCard] = []
var _pack_pick := -1  # pack item waiting for a target figure/slot


## Relic slots (3) and tarot slots (2) under the info line.
func _object_strip() -> Control:
	_strip_cards.clear()
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 10)
	strip.add_child(_label(tr("UI_RELICS"), 18, Emblem.COLORS["relic"]))
	for i in RunState.MAX_RELICS:
		strip.add_child(_strip_slot("relic", i, _run.relics[i] if i < _run.relics.size() else ""))
	strip.add_child(_spacer(30))
	strip.add_child(_label(tr("UI_TAROTS"), 18, Emblem.COLORS["tarot"]))
	for i in RunState.MAX_TAROTS:
		strip.add_child(_strip_slot("tarot", i, _run.tarots[i] if i < _run.tarots.size() else ""))
	strip.add_child(_spacer(30))
	strip.add_child(_label(tr("UI_PACTS"), 18, Emblem.COLORS["pact"]))
	for i in RunState.MAX_PACTS:
		strip.add_child(_strip_slot("pact", i, _run.pacts[i] if i < _run.pacts.size() else ""))
	return strip


func _strip_slot(kind: String, index: int, id: String) -> Control:
	if id == "":
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(52, 52)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.03)
		style.border_color = Color(1, 1, 1, 0.15)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		empty.add_theme_stylebox_override("panel", style)
		return empty
	var card := ObjectCard.create(_db, {"kind": kind, "id": id}, Vector2(52, 52), true)
	card.tapped.connect(func(c: ObjectCard) -> void: _on_strip_tapped(kind, index, c))
	_strip_cards.append(card)
	return card


func _on_strip_tapped(kind: String, index: int, card: ObjectCard) -> void:
	var was_selected: bool = _selected.get("kind") == kind and _selected.get("index") == index
	_clear_selection()
	if was_selected:
		return
	if kind == "pact" and _run.stage == RunState.Stage.EVENT and _event_option == "return_pact":
		if _run.resolve_event("return_pact", [index]):
			_event_option = ""
			_show_stage()
		return
	_selected = {"kind": kind, "index": index}
	card.set_selected(true)
	_detail_panel.show_object(card)
	if kind == "tarot":
		_detail_panel.show_hint(tr("UI_USE_TAROT") % card.title)
	elif kind == "relic" and _sell_zone != null:
		_sell_zone.show_text(tr("UI_SELL_FOR") % (Items.relic_price(_db, _run.relics[index]) / 2), true)


## The soul pack (paid in souls): two pacts, pick one.
func _soul_pack_view() -> Control:
	var box := VBoxContainer.new()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UnitCard.CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.08)
	style.border_color = Emblem.COLORS["pact"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emblem_box := CenterContainer.new()
	emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem_box.add_child(Emblem.create("pact", 46))
	inner.add_child(emblem_box)
	var name := _label(tr("UI_SOUL_PACK"), 14, Palette.PARCHMENT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name)
	panel.add_child(inner)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _run.buy_soul_pack():
				_undo.clear()
				_pack_pick = -1
				_show_stage())
	box.add_child(panel)
	var price := _label(tr("UI_SOUL_PRICE") % _run.soul_pack_price(), 18, Emblem.COLORS["soul"])
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	if _run.pacts.size() >= RunState.MAX_PACTS:
		panel.modulate.a = 0.4
	return box


## A pack in the shop: tap to buy and open it.
func _pack_view(index: int) -> Control:
	var box := VBoxContainer.new()
	var pack: Dictionary = _run.packs[index]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UnitCard.CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.08) if not pack.is_empty() else Color(1, 1, 1, 0.03)
	style.border_color = Palette.GOLD if not pack.is_empty() else Color(1, 1, 1, 0.15)
	style.set_border_width_all(4 if pack.get("size", "") == "mega" else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	box.add_child(panel)
	var price_text := ""
	if not pack.is_empty():
		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var emblem_box := CenterContainer.new()
		emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem_box.add_child(Emblem.create("pack", 46))
		inner.add_child(emblem_box)
		var name := _label(ItemText.pack_name(pack), 13, Palette.PARCHMENT)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name)
		var content := _label(tr("UI_PACK_CONTENT") % [Items.pack_choice_count(_db, pack), Items.pack_picks(_db, pack)], 11, Palette.MUTED)
		content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(content)
		panel.add_child(inner)
		price_text = tr("UI_PRICE") % _run.pack_cost(pack)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_on_buy_pack(index))
	var price := _label(price_text, 20, Palette.GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	return box


func _on_buy_pack(index: int) -> void:
	if _run.buy_pack(index):
		_undo.clear()  # opening packs is final
		_pack_pick = -1
		_show_stage()


## Overlay while a pack is open: pick items, choose targets, discard the rest.
func _build_pack_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.01, 0.03, 0.96)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(overlay)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	overlay.add_child(column)
	var open: Dictionary = _run.open_pack
	var title := _label("%s  ·  %s" % [ItemText.pack_name(open["pack"]),
		tr("UI_OPEN_PACK") % [open["picks_left"], open["items"].size()]], 30, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 24)
	for i in open["items"].size():
		items.add_child(_pack_item_box(i))
	var items_center := CenterContainer.new()
	items_center.add_child(items)
	column.add_child(items_center)

	# Own row: choose a target, or drag to merge / swap and sell to make room.
	var hint_text := tr("UI_PACK_ROW_HINT")
	if _pack_pick >= 0:
		var entry: Dictionary = open["items"][_pack_pick]
		var name: String = ItemText.equipment_name(entry["item"]) if entry["kind"] == "equipment" else tr(ContentDb.name_key(_db.figures[entry["def_id"]]))
		hint_text = tr("UI_PICK_TARGET") % name
	var hint := _label(hint_text, 22, Palette.PARCHMENT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var targets := HBoxContainer.new()
	targets.add_theme_constant_override("separation", 16)
	targets.alignment = BoxContainer.ALIGNMENT_CENTER
	var row_slots := _own_row_slots()
	for slot in _row_slots:
		slot.tapped.disconnect(_on_slot_tapped)
		slot.tapped.connect(_on_pack_row_tapped)
	targets.add_child(row_slots)
	_sell_zone = SellZone.new()
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	targets.add_child(_sell_zone)
	var target_center := CenterContainer.new()
	target_center.add_child(targets)
	column.add_child(target_center)

	var skip := _button(tr("UI_PACK_SKIP"), Vector2(260, 60), _on_close_pack)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(skip)


func _pack_item_box(i: int) -> Control:
	var entry: Dictionary = _run.open_pack["items"][i]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var visual: Control
	if entry["kind"] == "figure":
		var card := UnitCard.for_definition(_db.figures[entry["def_id"]], 1, false)
		card.tapped.connect(_detail_panel.show_card)
		visual = _with_rarity(card, entry["def_id"])
		visual = _scaled(visual, 1.3)
	else:
		var object_card := ObjectCard.create(_db, entry)
		object_card.tapped.connect(_detail_panel.show_object)
		visual = object_card
	if entry.get("taken", false):
		visual.modulate.a = 0.3
	elif _run.pack_item_target(i) != "":
		_make_draggable(visual, {"kind": "pack", "index": i})
	box.add_child(visual)
	var text := tr("UI_PICK")
	var enabled: bool = not entry.get("taken", false)
	if entry["kind"] == "tarot" and _run.tarots.size() >= RunState.MAX_TAROTS:
		text = tr("UI_TAROT_SLOTS_FULL")
		enabled = false
	elif entry["kind"] == "pact" and _run.pacts.size() >= RunState.MAX_PACTS:
		text = tr("UI_PACT_SLOTS_FULL")
		enabled = false
	elif entry["kind"] == "relic" and _run.relics.size() >= RunState.MAX_RELICS:
		text = tr("UI_RELIC_SLOTS_FULL")
		enabled = false
	var take := _button(text, Vector2(150, 54), _on_pack_take.bind(i))
	take.disabled = not enabled
	if _pack_pick == i:
		take.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(take)
	return box


func _on_pack_take(index: int) -> void:
	if _run.pack_item_target(index) != "":
		_pack_pick = index  # needs a figure or slot: show the row
		_show_stage()
		return
	if _run.take_pack_item(index):
		_pack_pick = -1
		_show_stage()


## In the pack overlay a row tap picks the target if an item waits for one,
## otherwise it selects the figure (for selling).
func _on_pack_row_tapped(slot: SlotView) -> void:
	if _pack_pick >= 0:
		_on_pack_target(slot)
	else:
		_on_slot_tapped(slot)


func _on_pack_target(slot: SlotView) -> void:
	if _pack_pick < 0:
		return
	var entry: Dictionary = _run.open_pack["items"][_pack_pick]
	var figure: Variant = _run.row[slot.index] if slot.index < _run.row.size() else null
	# Equipment onto an equipped figure: compare first, then swap or keep.
	if entry["kind"] == "equipment" and figure != null and figure.has("equipment"):
		_show_equipment_compare(figure, entry["item"], _pack_pick, slot.index)
		return
	if _run.take_pack_item(_pack_pick, slot.index):
		_pack_pick = -1
		_show_stage()
	elif entry["kind"] == "equipment" and figure != null:
		_detail_panel.show_message(ItemText.equipment_name(entry["item"]), tr("UI_OBJECT_LIMIT") % RunState.MAX_OBJECTS)
	elif entry["kind"] == "figure":
		_detail_panel.show_message(tr(ContentDb.name_key(_db.figures[entry["def_id"]])), tr("UI_NEEDS_FREE_SLOT"))


## Old and new equipment side by side: swap or keep the old one.
func _show_equipment_compare(figure: Dictionary, new_item: Dictionary, item_index: int, row_index: int) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	overlay.add_child(column)
	var title := _label(tr("UI_COMPARE_TITLE") % tr(ContentDb.name_key(_db.figures[figure["def_id"]])), 28, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var pair := HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 40)
	for side in [[tr("UI_COMPARE_OLD"), figure["equipment"]], [tr("UI_COMPARE_NEW"), new_item]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var label := _label(side[0], 20, Palette.PARCHMENT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		box.add_child(ObjectCard.create(_db, {"kind": "equipment", "item": side[1]}, Vector2(220, 280)))
		pair.add_child(box)
	var center := CenterContainer.new()
	center.add_child(pair)
	column.add_child(center)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	buttons.add_child(_button(tr("UI_COMPARE_SWAP"), Vector2(240, 64), func() -> void:
		overlay.queue_free()
		if _run.take_pack_item(item_index, row_index):
			_pack_pick = -1
		_show_stage()))
	buttons.add_child(_button(tr("UI_COMPARE_KEEP"), Vector2(240, 64), func() -> void:
		overlay.queue_free()
		_pack_pick = -1
		_show_stage()))
	column.add_child(buttons)


## Lets a control be dragged onto row slots (pack items, market figures).
func _make_draggable(control: Control, data: Dictionary) -> void:
	control.set_drag_forwarding(func(_at: Vector2) -> Variant:
		var preview := Emblem.create("pack", 60)
		preview.position = -Vector2(30, 30)
		var holder := Control.new()
		holder.add_child(preview)
		control.set_drag_preview(holder)
		return data, Callable(), Callable())


func _on_close_pack() -> void:
	_run.close_pack()
	_pack_pick = -1
	_show_stage()


# --- Events ---------------------------------------------------------------------------

## Option layout per event: [option id, figures it needs].
const EVENT_OPTIONS := {
	"altar": [["sacrifice_one", 1], ["sacrifice_two", 2], ["leave", 0]],
	"black_market": [["buy_relic", 0], ["buy_pack", 0], ["buy_figure", 1], ["leave", 0]],
	"cursed_well": [["throw_3", 0], ["throw_6", 0], ["throw_10", 0], ["drink", 1], ["leave", 0]],
	"fortune_teller": [["tarot", 0], ["no_boss_rule", 0], ["mega_arcana", 0], ["leave", 0]],
	"grave_robber": [["rob", 0], ["small", 0]],
	"mirror": [["duplicate", 1], ["train", 1], ["leave", 0]],
	"duel": [["fight", 0], ["decline", 0]],
	"soul_trader": [["soul_to_gold", 0], ["gold_to_soul", 0], ["return_pact", 0], ["leave", 0]],
}

var _event_option := ""  # option waiting for figure targets
var _event_targets: Array = []


func _build_event() -> void:
	var event: Dictionary = _run.event
	var id: String = event["id"]
	var backdrop := RegionBackdrop.new()
	backdrop.suit = _run.region
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0.6, 0.6, 0.7)
	_screen.add_child(backdrop)
	var column := _column()
	column.add_child(_top_bar(tr("EVENT_" + id.to_upper())))
	column.add_child(_object_strip())
	var desc := _label(tr("EVENT_" + id.to_upper() + "_DESC"), 24, Palette.PARCHMENT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(desc)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	if event["resolved"]:
		var result_key: String = event.get("result", "")
		var result := _label(tr("RESULT_" + result_key.to_upper()) if result_key != "" else tr("UI_EVENT_DONE"), 24, Palette.GOLD)
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options.add_child(result)
		options.add_child(_centered(_button(tr("UI_CONTINUE"), Vector2(560, 60), _on_event_option.bind("leave", 0))))
	else:
		options.add_child(_market_coat() if id == "black_market" else _event_scene(id))
		var exit_option := "decline" if id == "duel" else ("small" if id == "grave_robber" else "leave")
		if id != "grave_robber":
			options.add_child(_centered(_button(tr("OPT_" + exit_option.to_upper()), Vector2(400, 56), _on_event_option.bind(exit_option, 0))))
	var options_center := CenterContainer.new()
	options_center.add_child(options)
	column.add_child(options_center)

	if _event_option != "":
		var needed: int = _needed_targets(_event_option)
		var hint_text := tr("UI_PICK_FIGURES") % needed
		if _event_option == "return_pact":
			hint_text = tr("UI_PICK_PACT")
		elif _event_option == "buy_figure":
			hint_text = tr("UI_MARKET_FIGURE_HINT")
		var hint := _label(hint_text, 20, Palette.GOLD)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(hint)
	var row_box := HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.add_theme_constant_override("separation", 16)
	row_box.add_child(_own_row_slots())
	_sell_zone = SellZone.new()
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	row_box.add_child(_sell_zone)
	column.add_child(_fitted(row_box, 1.2))
	for slot in _row_slots:
		if slot.index in _event_targets:
			slot.set_selected(true)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


## Look of each event scene: panel colors and the big emblem on the left.
const EVENT_SCENES := {
	"altar": {"bg": Color(0.12, 0.05, 0.05), "border": Color(0.6, 0.15, 0.15), "emblem": "skull"},
	"cursed_well": {"bg": Color(0.08, 0.05, 0.12), "border": Color(0.55, 0.3, 0.75), "emblem": "curse"},
	"fortune_teller": {"bg": Color(0.09, 0.06, 0.14), "border": Color(0.75, 0.6, 0.95), "emblem": "tarot"},
	"grave_robber": {"bg": Color(0.09, 0.08, 0.06), "border": Color(0.5, 0.45, 0.35), "emblem": "skull"},
	"mirror": {"bg": Color(0.06, 0.09, 0.13), "border": Color(0.65, 0.78, 0.95), "emblem": "star"},
	"duel": {"bg": Color(0.1, 0.08, 0.08), "border": Color(0.8, 0.8, 0.85), "emblem": "sword"},
	"soul_trader": {"bg": Color(0.05, 0.08, 0.12), "border": Color(0.5, 0.8, 1.0), "emblem": "soul"},
}
## Emblem shown on each offer.
const OFFER_EMBLEMS := {
	"sacrifice_one": "soul", "sacrifice_two": "pact", "throw_3": "pack", "throw_6": "pack",
	"throw_10": "pack", "drink": "curse", "tarot": "tarot", "no_boss_rule": "enemy",
	"mega_arcana": "pack", "rob": "relic", "small": "coin", "duplicate": "star", "train": "level",
	"fight": "sword", "soul_to_gold": "coin", "gold_to_soul": "soul", "return_pact": "pact",
}


## An event as its own scene: a themed panel with a big emblem and one
## compartment per offer (emblem, name, description, cost, choose button).
func _event_scene(id: String) -> Control:
	var look: Dictionary = EVENT_SCENES.get(id, EVENT_SCENES["altar"])
	var panel := _scene_panel(look["bg"], look["border"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# Left: the scene's emblem (for a duel: the champion's team).
	if id == "duel":
		var champion := VBoxContainer.new()
		champion.alignment = BoxContainer.ALIGNMENT_CENTER
		var heading := _label(tr("UI_CHAMPION"), 20, look["border"])
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		champion.add_child(heading)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		for unit in _run.event.get("team", []):
			var card := UnitCard.for_definition(_db.enemies[unit["def_id"]], int(unit["level"]), true)
			card.tapped.connect(_detail_panel.show_card)
			cards.add_child(card)
		champion.add_child(_scaled(cards, 0.75))
		row.add_child(champion)
	else:
		var emblem := Emblem.create(look["emblem"], 130)
		emblem.color = look["border"]
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(170, 0)
		holder.add_child(emblem)
		row.add_child(holder)
	for entry in EVENT_OPTIONS[id]:
		var option: String = entry[0]
		if option in ["leave", "decline", "small"] and id != "grave_robber":
			continue
		if option == "leave":
			continue
		var visual := Emblem.create(OFFER_EMBLEMS.get(option, "star"), 64)
		if option.begins_with("throw_"):
			visual.color = ItemText.RARITY_COLORS[Items.RARITY_MAGIC if option == "throw_3" else Items.RARITY_RARE]
		var key := "OFFER_" + option.to_upper()
		row.add_child(_compartment(tr(key), visual, _offer_cost(option), option, tr(key + "_DESC"), look["border"]))
	return panel


func _scene_panel(bg: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border.darkened(0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(14)
	style.shadow_color = Color(border, 0.25)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


## What an offer costs, as shown under it.
func _offer_cost(option: String) -> String:
	match option:
		"sacrifice_one", "drink", "train":
			return tr("COST_FIGURE") if option == "sacrifice_one" else tr("COST_FREE")
		"sacrifice_two":
			return tr("COST_FIGURES")
		"throw_3", "throw_6", "throw_10":
			return tr("COST_GOLD") % int(option.split("_")[1])
		"mega_arcana", "soul_to_gold":
			return tr("COST_SOUL")
		"duplicate":
			return tr("COST_SOULS") % 2
		"gold_to_soul":
			return tr("COST_GOLD") % 5
		"rob":
			return tr("COST_REAR_FIGURE")
		"return_pact":
			return tr("COST_PACT")
		"fight":
			return tr("COST_RISK")
	return tr("COST_FREE")


func _centered(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(control)
	return center


## The trader's coat: three compartments (relics, packs, figures) with cards,
## descriptions, prices and a buy button each.
func _market_coat() -> Control:
	var coat := _scene_panel(Color(0.13, 0.08, 0.06), Palette.GOLD)
	var compartments := HBoxContainer.new()
	compartments.add_theme_constant_override("separation", 14)
	coat.add_child(compartments)
	var event: Dictionary = _run.event
	# Relic
	if event.get("relic", "") != "":
		var relic_card := ObjectCard.create(_db, {"kind": "relic", "id": event["relic"]}, Vector2(170, 210))
		relic_card.tapped.connect(_detail_panel.show_object)
		compartments.add_child(_compartment(tr("UI_MARKET_RELICS"), relic_card, tr("UI_PRICE") % 4, "buy_relic"))
	# Pack
	var pack := {"type": event["pack_type"], "size": "mega"}
	var pack_box := VBoxContainer.new()
	pack_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pack_box.custom_minimum_size = Vector2(170, 210)
	var emblem_center := CenterContainer.new()
	emblem_center.add_child(Emblem.create("pack", 80))
	pack_box.add_child(emblem_center)
	var pack_name := _label(ItemText.pack_name(pack), 17, Palette.PARCHMENT)
	pack_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	pack_box.add_child(pack_name)
	var pack_info := _label(tr("UI_PACK_CONTENT") % [Items.pack_choice_count(_db, pack), Items.pack_picks(_db, pack)], 14, Palette.MUTED)
	pack_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_box.add_child(pack_info)
	compartments.add_child(_compartment(tr("UI_MARKET_PACKS"), pack_box, tr("UI_PRICE") % 6, "buy_pack"))
	# Figure (half price): drag onto a free slot or buy + tap a slot.
	var def_id: String = event["figure"]
	var figure_card := UnitCard.for_definition(_db.figures[def_id], 1, false)
	figure_card.tapped.connect(_detail_panel.show_card)
	var figure_visual := _scaled(_with_rarity(figure_card, def_id), 1.3)
	if not "buy_figure" in event["used"]:
		_make_draggable(figure_visual, {"kind": "market_figure"})
	compartments.add_child(_compartment(tr("UI_MARKET_FIGURES"), figure_visual, tr("UI_PRICE") % (_run.price_of(def_id) / 2), "buy_figure"))
	return coat


## One offer of an event scene (market: buy button; other events: choose).
func _compartment(title: String, visual: Control, cost_text: String, option: String,
		desc: String = "", accent: Color = Color(0.45, 0.32, 0.18)) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.05, 0.85)
	style.border_color = accent.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var market := option in ["buy_relic", "buy_pack", "buy_figure"]
	if not market:
		panel.custom_minimum_size = Vector2(230, 0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := _label(title, 20, Palette.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var center := CenterContainer.new()
	center.add_child(visual)
	box.add_child(center)
	if desc != "":
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(210, 0)
		text.add_theme_font_size_override("normal_font_size", 16)
		text.add_theme_color_override("default_color", Palette.PARCHMENT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.text = "[center]" + Keywords.colorize(desc) + "[/center]"
		box.add_child(text)
	var sold: bool = option in _run.event["used"]
	if sold:
		visual.modulate.a = 0.3
	var price_label := _label(tr("UI_SOLD") if sold else cost_text, 18, Palette.GOLD)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price_label)
	var buy := _button(tr("UI_BUY") if market else tr("UI_CHOOSE"), Vector2(150, 50),
		_on_event_option.bind(option, 1 if option == "buy_figure" else _needed_targets(option)))
	var block := _run.event_option_block(option, [])
	buy.disabled = sold or block == "cost" or block == "done"
	if _event_option == option:
		buy.add_theme_color_override("font_color", Palette.GOLD)
		style.border_color = Palette.GOLD
	box.add_child(buy)
	return panel


func _event_option_text(option: String) -> String:
	var key := "OPT_" + option.to_upper()
	match option:
		"buy_relic":
			return tr(key) % ItemText.relic_name(_run.event.get("relic", ""))
		"buy_pack":
			return tr(key) % ItemText.pack_name({"type": _run.event["pack_type"], "size": "normal"})
		"buy_figure":
			var def_id: String = _run.event["figure"]
			return tr(key) % [tr(ContentDb.name_key(_db.figures[def_id])), _run.price_of(def_id) / 2]
	return tr(key)


func _needed_targets(option: String) -> int:
	for entry in EVENT_OPTIONS.get(_run.event.get("id", ""), []):
		if entry[0] == option:
			return entry[1]
	return 0


func _on_event_option(option: String, needed: int) -> void:
	if option == "fight":
		_play_duel()
		return
	if needed > 0 or option == "return_pact":
		_event_option = option
		_event_targets.clear()
		_show_stage()
		return
	if _run.resolve_event(option):
		_event_option = ""
		_undo.clear()
		_show_stage()


## Row taps during an event pick targets for the waiting option.
func _on_event_row_tapped(slot: SlotView) -> void:
	if _event_option == "" or _event_option == "return_pact":
		if slot.card != null:
			_select("row", slot.index)
		return
	if slot.index in _event_targets:
		_event_targets.erase(slot.index)
	elif _event_option == "buy_figure" or slot.card != null:
		_event_targets.append(slot.index)
	if _event_targets.size() >= _needed_targets(_event_option):
		var targets := _event_targets.duplicate()
		var option := _event_option
		_event_targets.clear()
		if _run.resolve_event(option, targets):
			_event_option = ""
		elif option == "buy_figure":
			_show_stage()
			_detail_panel.show_message(tr("UI_MARKET_FIGURES"), tr("UI_NEEDS_FREE_SLOT"))
			return
	_show_stage()


func _play_duel() -> void:
	_detail_panel.hide()
	_battle_view = BattleScene.instantiate()
	_battle_view.sandbox = false
	add_child(_battle_view)
	_battle_view.finished.connect(func(result: Dictionary) -> void:
		_battle_view.queue_free()
		_battle_view = null
		_run.apply_duel_result(result)
		_show_stage())
	_battle_view.play_battle(_run.player_battle_team(), _run.duel_team(), _run.gold, _footer_text(),
		_run.battle_options(), "", tr("EVENT_DUEL"))


# --- Rarity effect (queens and kings) ------------------------------------------------

func _rarity(def_id: String) -> String:
	var rank: String = _db.figures[def_id]["rank"]
	return rank if rank in ["queen", "king", "legend"] else ""


## Rotating golden rays behind rare cards plus a "Rare!/Epic!" tag, popping in.
func _add_rarity_effect(host: Control, def_id: String) -> void:
	var rarity := _rarity(def_id)
	if rarity == "":
		return
	var shine := RareShine.new()
	shine.epic = rarity == "king"
	shine.legend = rarity == "legend"
	shine.size = UnitCard.CARD_SIZE + Vector2(80, 80)
	shine.position = -Vector2(40, 40)
	host.add_child(shine)
	host.move_child(shine, 0)
	var tag_text: String = {"queen": tr("UI_RARE"), "king": tr("UI_RARE_EPIC"), "legend": tr("UI_RARE_LEGEND")}[rarity]
	var tag := _label(tag_text, 18 if rarity == "legend" else 16, Palette.GOLD)

	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 6)
	tag.position = Vector2(0, -26)
	tag.size = Vector2(UnitCard.CARD_SIZE.x, 22)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(tag)
	if rarity == "legend":
		# Colors cycle like the rays (tween bound to the tag, ends with it).
		var cycle := tag.create_tween().set_loops()
		for hue in [0.0, 0.33, 0.66]:
			cycle.tween_property(tag, "modulate", Color.from_hsv(hue, 0.5, 1.0), 0.4)
	host.pivot_offset = UnitCard.CARD_SIZE / 2
	host.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(host, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Card wrapped with the rarity effect. The effect animates an inner host,
## so the returned control can still be scaled from outside.
func _with_rarity(card: UnitCard, def_id: String) -> Control:
	var outer := Control.new()
	outer.custom_minimum_size = UnitCard.CARD_SIZE
	var host := Control.new()
	host.custom_minimum_size = UnitCard.CARD_SIZE
	host.size = UnitCard.CARD_SIZE
	host.add_child(card)
	outer.add_child(host)
	_add_rarity_effect(host, def_id)
	return outer


# --- Reward ---------------------------------------------------------------------------

func _build_reward() -> void:
	var column := _column()
	column.add_child(_top_bar(tr("UI_VICTORY")))
	var income := _run.last_income
	var summary := tr("UI_INCOME") % [income.get("base", 0), income.get("bonus", 0), income.get("interest", 0)]
	if int(income.get("souls", 0)) > 0:
		summary += "  ·  " + tr("UI_INCOME_SOULS") % income["souls"]
	if income.get("slot", false):
		summary += "  ·  " + tr("UI_NEW_SLOT")
	var summary_label := _label(summary, 20, Palette.PARCHMENT)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary_label)
	var title := _label(tr("UI_CHOOSE_REWARD"), 24, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 40)
	column.add_child(_fitted(choices, 1.6))
	for i in _run.rewards.size():
		var def_id: String = _run.rewards[i]
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)
		var card := UnitCard.for_definition(_db.figures[def_id], 1, false)
		card.tapped.connect(_detail_panel.show_card)
		var holder := CenterContainer.new()
		holder.add_child(_with_rarity(card, def_id))
		box.add_child(holder)
		var target := _run.reward_target(def_id)
		var text := tr("UI_TAKE")
		if target >= 0 and _run.row[target] != null:
			text = tr("UI_TAKE_MERGE")
		elif target < 0:
			text = tr("UI_NO_ROOM")
		var take := _button(text, Vector2(180, 56), _on_take_reward.bind(i))
		take.disabled = target < 0
		box.add_child(take)
		choices.add_child(box)

	# Own row with a sell field, to make room for a better reward.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	bottom.add_child(_label(tr("UI_YOUR_TEAM"), 18, Palette.MUTED))
	bottom.add_child(_scaled(_own_row_slots(), 0.8))
	_sell_zone = SellZone.new()
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	bottom.add_child(_scaled(_sell_zone, 0.8))
	bottom.add_child(_button(tr("UI_SKIP_REWARD") % RunState.REWARD_SKIP_GOLD, Vector2(240, 60), _on_skip_reward))
	column.add_child(bottom)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


func _on_take_reward(index: int) -> void:
	var def_id: String = _run.rewards[index]
	var target := _run.reward_target(def_id)
	var before_xp := int(_run.row[target]["xp"]) if target >= 0 and _run.row[target] != null else -1
	if _run.take_reward(index):
		_show_stage()
		if before_xp >= 0:
			_show_merge(def_id, before_xp, int(_run.row[target]["xp"]))


# --- Merge screen ----------------------------------------------------------------------

## Overlay after merging a duplicate: XP counts up; on a level-up it shows the
## new stats (old → new) and the stronger ability.
func _show_merge(def_id: String, old_xp: int, new_xp: int) -> void:
	var definition: Dictionary = _db.figures[def_id]
	var old_level := RunState.level_for_xp(old_xp)
	var new_level := RunState.level_for_xp(new_xp)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1)
	style.border_color = Palette.GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var card := UnitCard.for_definition(definition, new_level, false)
	row.add_child(_scaled(card, 1.4))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.custom_minimum_size = Vector2(460, 0)
	row.add_child(info)
	var levelled := new_level > old_level
	var title := _label(tr("UI_LEVEL_UP") % new_level if levelled else tr("UI_MERGED"), 32, Palette.GOLD)
	info.add_child(title)
	info.add_child(_label(tr(ContentDb.name_key(definition)), 22, Palette.PARCHMENT))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 26)
	bar.show_percentage = false
	var threshold: int = RunState.XP_FOR_LEVEL[mini(old_level, 2)]
	var start: int = RunState.XP_FOR_LEVEL[old_level - 1]
	bar.min_value = start
	bar.max_value = maxi(threshold, start + 1)
	bar.value = old_xp
	info.add_child(bar)
	var xp_label := _label(tr("UI_XP_GAIN") % [NumberFormat.decimal(old_xp / 3.0), NumberFormat.decimal(new_xp / 3.0)], 18, Palette.MUTED)
	info.add_child(xp_label)
	var tween := create_tween()
	tween.tween_property(bar, "value", float(mini(new_xp, int(bar.max_value))), 0.8).set_trans(Tween.TRANS_QUAD)

	if levelled:
		var old_unit := BattleUnit.from_definition(definition, 0, 0, old_level)
		var new_unit := BattleUnit.from_definition(definition, 0, 0, new_level)
		var details := RichTextLabel.new()
		details.bbcode_enabled = true
		details.fit_content = true
		details.scroll_active = false
		details.custom_minimum_size = Vector2(440, 0)
		details.add_theme_font_size_override("normal_font_size", 20)
		details.add_theme_color_override("default_color", Palette.PARCHMENT)
		var ability: Dictionary = definition["ability"]
		var old_value := NumberFormat.ability_value(ability["effect"], old_unit.level_value(ability))
		var new_value := NumberFormat.ability_value(ability["effect"], new_unit.level_value(ability))
		var lines := [
			Keywords.colorize(tr("UI_STAT_CHANGE_ATTACK") % [old_unit.attack, new_unit.attack]),
			Keywords.colorize(tr("UI_STAT_CHANGE_HEALTH") % [old_unit.health, new_unit.health]),
			Keywords.colorize(tr("ABIL_" + def_id.to_upper()).replace("{v}", "%s -> [b]%s[/b]" % [old_value, new_value])),
		]
		details.text = "\n".join(lines)
		details.modulate.a = 0.0
		info.add_child(details)
		tween.tween_property(details, "modulate:a", 1.0, 0.4)
		tween.parallel().tween_property(title, "scale", Vector2(1.15, 1.15), 0.15)
		tween.tween_property(title, "scale", Vector2.ONE, 0.15)

	var close := _button(tr("UI_CONTINUE"), Vector2(200, 60), overlay.queue_free)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	info.add_child(close)


func _on_skip_reward() -> void:
	if _run.skip_reward():
		_show_stage()


# --- Run end ---------------------------------------------------------------------------

func _build_run_end() -> void:
	var column := _column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var won := _run.stage == RunState.Stage.WON
	var title := _label(tr("UI_RUN_WON") if won else tr("UI_RUN_LOST"), 48, Palette.GOLD if won else Palette.HEALTH)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for line in [
		tr("UI_RUN_REACHED") % [_run.act if not won else RunState.ACTS, _stage_name_at_end(won)],
		tr("UI_RUN_WINS") % _run.battles_won,
		tr("UI_GOLD") % _run.gold,
		tr("UI_SEED") % _run.rng.master_seed,
	]:
		var label := _label(line, 24, Palette.PARCHMENT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	var own := CenterContainer.new()
	own.add_child(_scaled(_card_row(_own_team_entries(), false, true), 0.8))
	column.add_child(own)
	var again := _button(tr("UI_NEW_RUN"), Vector2(280, 72), _new_run)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(again)


func _stage_name_at_end(won: bool) -> String:
	return tr("UI_FIGHT_BOSS") if won else tr(STAGE_NAMES[_run.fight])


func _footer_text() -> String:
	return "  v%s · %s" % [ProjectSettings.get_setting("application/config/version"), tr("UI_SEED") % _run.rng.master_seed]
