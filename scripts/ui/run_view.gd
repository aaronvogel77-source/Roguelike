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
		RunState.Stage.REWARD:
			_build_reward()
		RunState.Stage.WON, RunState.Stage.LOST:
			_build_run_end()


# --- Shared building blocks ----------------------------------------------------------

func _top_bar(title: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 60)
	bar.add_theme_constant_override("separation", 28)
	bar.add_child(_spacer(8))
	bar.add_child(_label(title, 26, Palette.GOLD))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	bar.add_child(_label(tr("UI_GOLD") % _run.gold, 26, Palette.GOLD))
	bar.add_child(_label(tr("UI_INTEREST") % _run.interest(), 18, Palette.MUTED))
	bar.add_child(_label(tr("UI_SLOTS") % [_filled_slots(), _run.slot_count()], 20, Palette.PARCHMENT))
	if _url_flag("debug"):
		bar.add_child(_button("+10 Gold", Vector2(110, 44), _debug_gold))
		bar.add_child(_button("Zum Boss", Vector2(130, 44), _debug_to_boss))
	bar.add_child(_spacer(8))
	return bar


# --- Debug tools ("?debug=1" in the address) ---------------------------------------

func _debug_gold() -> void:
	_run.gold += 10
	_show_stage()


## Wins every fight until the next boss choice (for testing bosses quickly).
func _debug_to_boss() -> void:
	var guard := 0
	while guard < 20 and not (_run.stage == RunState.Stage.ENEMY_CHOICE and _run.is_boss_fight()):
		guard += 1
		match _run.stage:
			RunState.Stage.ENEMY_CHOICE:
				_run.choose_enemy(0)
			RunState.Stage.PLANNING:
				_run.apply_battle_result({"victory": true})
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
	var options_holder := CenterContainer.new()
	options_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_holder.add_child(options)
	column.add_child(options_holder)
	for i in _run.enemy_options.size():
		options.add_child(_enemy_option_panel(_run.enemy_options[i], i))

	var own := HBoxContainer.new()
	own.alignment = BoxContainer.ALIGNMENT_CENTER
	own.add_theme_constant_override("separation", 16)
	own.add_child(_label(tr("UI_YOUR_TEAM"), 20, Palette.MUTED))
	own.add_child(_scaled(_card_row(_own_team_entries(), false, true), 0.62))
	column.add_child(own)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


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
	var team_width: float = option["team"].size() * (UnitCard.CARD_SIZE.x + CARD_SPACING)
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

	# Battle field preview: own slots (front next to the middle) and the chosen enemy.
	var field := HBoxContainer.new()
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", ROW_GAP)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var own_box := VBoxContainer.new()
	own_box.alignment = BoxContainer.ALIGNMENT_CENTER
	own_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	own_box.add_child(_label(tr("UI_YOUR_TEAM_FRONT"), 18, Palette.MUTED))
	var own_row := HBoxContainer.new()
	own_row.add_theme_constant_override("separation", CARD_SPACING)
	_row_slots.clear()
	for i in range(_run.slot_count() - 1, -1, -1):  # back on the left, front on the right
		var slot := SlotView.new("row", i)
		var figure: Variant = _run.row[i]
		if figure != null:
			slot.set_card(UnitCard.for_definition(_db.figures[figure["def_id"]], _run.figure_level(figure), false))
		slot.tapped.connect(_on_slot_tapped)
		slot.dropped.connect(_on_slot_dropped)
		own_row.add_child(slot)
		_row_slots.append(slot)
	own_box.add_child(own_row)
	own_box.add_child(_xp_hint_row())
	field.add_child(own_box)

	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_box.add_child(_label(tr("UI_NEXT_ENEMY"), 18, Palette.MUTED))
	enemy_box.add_child(_card_row(_run.chosen_enemy["team"], true, false))
	var enemy_holder := _scaled(enemy_box, 0.8)
	enemy_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_child(enemy_holder)
	column.add_child(field)

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
		slot.accepts_drops = false
		slot.tapped.connect(_on_slot_tapped)
		shop_box.add_child(slot)
		var price := _label(tr("UI_PRICE") % RunState.FIGURE_PRICE if _run.shop[i] != "" else "", 18, Palette.GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_box.add_child(price)
		bottom.add_child(shop_box)
		_shop_slots.append(slot)

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
	var slot_price := _run.slot_price()
	var buy_slot := _button(tr("UI_BUY_SLOT") % slot_price if slot_price > 0 else tr("UI_SLOTS_MAX"), Vector2(200, 56), _on_buy_slot)
	buy_slot.disabled = slot_price < 0 or _run.gold < slot_price
	actions.add_child(buy_slot)
	_undo_button = _button(tr("UI_UNDO"), Vector2(200, 56), _on_undo)
	_undo_button.disabled = _undo.is_empty()
	actions.add_child(_undo_button)
	bottom.add_child(actions)

	var fight := _button(tr("UI_FIGHT"), Vector2(170, 124), _on_fight)
	fight.add_theme_font_size_override("font_size", 30)
	fight.disabled = _filled_slots() == 0
	bottom.add_child(fight)
	column.add_child(bottom)
	column.add_child(_label(_footer_text(), 16, Palette.MUTED))


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
	_selected = {}
	_sell_armed = -1
	if _sell_zone != null:
		_sell_zone.show_text(tr("UI_SELL_ZONE"), false)
	_detail_panel.hide()


func _on_slot_tapped(slot: SlotView) -> void:
	if slot.kind == "shop":
		if slot.card == null or (_selected.get("kind") == "shop" and _selected["index"] == slot.index):
			_clear_selection()
		else:
			_select("shop", slot.index)
		return
	# Row slot: complete a pending buy or move, otherwise select.
	if _selected.get("kind") == "shop":
		_buy(_selected["index"], slot.index)
	elif _selected.get("kind") == "row" and _selected["index"] != slot.index:
		var from: int = _selected["index"]
		_apply_action(func() -> bool: return _run.move(from, slot.index))
	elif _selected.get("kind") == "row":
		_clear_selection()
	elif slot.card != null:
		_select("row", slot.index)


func _on_slot_dropped(data: Dictionary, slot: SlotView) -> void:
	if data["kind"] == "shop":
		_buy(data["index"], slot.index)
	elif data["kind"] == "row":
		_apply_action(func() -> bool: return _run.move(data["index"], slot.index))


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


func _on_buy_slot() -> void:
	_apply_action(_run.buy_slot)


func _on_fight() -> void:
	_undo.clear()
	_detail_panel.hide()
	_battle_view = BattleScene.instantiate()
	_battle_view.sandbox = false
	add_child(_battle_view)
	_battle_view.finished.connect(_on_battle_finished)
	_battle_view.play_battle(_run.player_battle_team(), _run.enemy_battle_team(), _run.battle_gold(),
		_footer_text(), _run.battle_options(), _rule_text())


func _on_battle_finished(result: Dictionary) -> void:
	_battle_view.queue_free()
	_battle_view = null
	_run.apply_battle_result(result)
	_show_stage()


# --- Reward ---------------------------------------------------------------------------

func _build_reward() -> void:
	var column := _column()
	column.add_child(_top_bar(tr("UI_VICTORY")))
	var income := _run.last_income
	var summary := tr("UI_INCOME") % [income.get("base", 0), income.get("bonus", 0), income.get("interest", 0)]
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
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(choices)
	for i in _run.rewards.size():
		var def_id: String = _run.rewards[i]
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)
		var card := UnitCard.for_definition(_db.figures[def_id], 1, false)
		card.tapped.connect(_detail_panel.show_card)
		var holder := CenterContainer.new()
		holder.add_child(_scaled(card, 1.25))
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

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	bottom.add_child(_label(tr("UI_YOUR_TEAM"), 18, Palette.MUTED))
	bottom.add_child(_scaled(_card_row(_own_team_entries(), false, true), 0.55))
	bottom.add_child(_button(tr("UI_SKIP_REWARD") % RunState.REWARD_SKIP_GOLD, Vector2(260, 60), _on_skip_reward))
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
			Keywords.colorize(tr("ABIL_" + def_id.to_upper()).replace("{v}", "%s → [b]%s[/b]" % [old_value, new_value])),
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
