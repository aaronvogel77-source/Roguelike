extends Control
## The run screen: enemy choice, planning/shop, battle, reward and run end.
## All rules live in RunState; this script only shows them and forwards input.

const STAGE_NAMES := ["UI_FIGHT_SMALL", "UI_FIGHT_BIG", "UI_FIGHT_BOSS"]
const DIFFICULTY_NAMES := ["UI_EASY", "UI_MEDIUM", "UI_HARD"]
const ROW_GAP := 56
const CARD_SPACING := 6
const BattleScene := preload("res://scenes/battle.tscn")
const RUN_SAVE := "user://run.save"

var _db: ContentDb
var _run: RunState
var _meta: MetaState
var _run_summary: Dictionary = {}  # Seelenglut and unlocks of the finished run
var _undo: Array = []  # RunState.to_dict() snapshots taken before shop actions
var _selected: Dictionary = {}  # {"kind": "row"/"shop", "index": int}
var _sell_armed := -1  # row index whose sale awaits a confirming second tap

var _screen: Control
var _detail_panel: DetailPanel
var _battle_view: Control


func _ready() -> void:
	TranslationServer.set_locale("de")
	Sound.setup(get_tree())
	UiText.setup(get_tree())
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
	_meta = MetaState.load_saved()
	Cosmetics.apply(_meta)  # also in the arena, so worn cosmetics show there
	# "?arena=1": random test battles with full teams (sandbox battle view).
	if _url_flag("arena"):
		add_child(BattleScene.instantiate())
		return
	# "?seed=N" starts a run directly (testing); otherwise the main menu.
	if _url_seed() >= 0:
		_new_run("novice")
	else:
		_show_menu()


func _show_menu() -> void:
	_run = null
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	_detail_panel.hide()
	for child in _screen.get_children():
		child.queue_free()
	Sound.music("menu")
	var menu := MetaView.create(_db, _meta, FileAccess.file_exists(RUN_SAVE), _url_flag("debug"))
	menu.detail_panel = _detail_panel
	menu.continue_run.connect(_continue_run)
	menu.start_run.connect(_new_run)
	_screen.add_child(menu)


func _new_run(occultist: String = "novice") -> void:
	var seed_value := _url_seed()
	if seed_value < 0:
		seed_value = randi() % 1000000
	_run = RunState.new_run(_db, seed_value, _meta.run_options(_db, occultist))
	_run_summary = {}
	_undo.clear()
	_show_stage()
	_show_region_intro()


## Loads the autosaved run (there is no manual saving or loading).
func _continue_run() -> void:
	var data = str_to_var(FileAccess.get_file_as_string(RUN_SAVE))
	if not data is Dictionary:
		DirAccess.remove_absolute(RUN_SAVE)
		_show_menu()
		return
	_run = RunState.from_dict(_db, data)
	_run_summary = {}
	_undo.clear()
	_show_stage()


## Autosave after every action; a finished run pays out its Seelenglut once.
## Music per screen and a sound when an event or the run's end appears.
var _sound_marker := ""


func _stage_sounds() -> void:
	if _run == null:
		return
	match _run.stage:
		RunState.Stage.WON, RunState.Stage.LOST:
			Sound.music("menu")
		_:
			if _battle_view == null:
				Sound.music("planning")
	var marker := "%d:%s:%d:%d" % [_run.stage, _run.event.get("id", ""), _run.act, _run.fight]
	if marker == _sound_marker:
		return
	_sound_marker = marker
	match _run.stage:
		RunState.Stage.EVENT:
			Sound.play("creak" if _run.is_negative_event() else "book")
		RunState.Stage.WON:
			Sound.play("bell_big")
		RunState.Stage.REWARD:
			Sound.play("coins", -4.0)


## Controls the first-time hints point at, filled while a screen is built.
var _hint_targets := {}
## Order in which hints are offered on a screen (one at a time).
const HINT_ORDER := ["choice", "boss", "shop", "fight", "pack", "suit", "souls", "reward", "event", "danger"]


func _show_hints() -> void:
	# First the phase card, then the note (both at once would be too much).
	var wait := _title_card_until - Time.get_ticks_msec()
	if wait > 0 or (is_instance_valid(_region_intro) and _region_intro.is_inside_tree()):
		if not _hint_retry_pending:
			_hint_retry_pending = true
			get_tree().create_timer(maxf(wait, 300) / 1000.0).timeout.connect(func() -> void:
				_hint_retry_pending = false
				_show_hints())
		return
	if _run == null or _battle_view != null or not _run.fusion_offer.is_empty() or not _run.treasure.is_empty() \
			or not _run.open_pack.is_empty():
		return
	if _run.stage == RunState.Stage.ENEMY_CHOICE and _run.is_boss_fight() and _hint_targets.has("choice"):
		_hint_targets["boss"] = _hint_targets["choice"]
	for id in HINT_ORDER:
		if id == "choice" and _run.is_boss_fight():
			continue
		if _hint_targets.has(id) and Hints.wants(id):
			Hints.show(_screen, id, _hint_targets[id])
			return


func _autosave() -> void:
	if _run.stage in [RunState.Stage.WON, RunState.Stage.LOST]:
		if not _run.flags.get("meta_done", false):
			_run.flags["meta_done"] = true
			_run_summary = _meta.finish_run(_run)
			_meta.save()
		if FileAccess.file_exists(RUN_SAVE):
			DirAccess.remove_absolute(RUN_SAVE)
		return
	var file := FileAccess.open(RUN_SAVE, FileAccess.WRITE)
	if file != null:
		file.store_string(var_to_str(_run.to_dict()))
	_meta.discover_from_run(_run)
	_meta.save()


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
	_region_intro = overlay
	# The intro names the act and fight itself: no extra phase card for it.
	_last_title_key = "fight:%d:%d" % [_run.act, _run.fight]
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	overlay.add_child(column)
	var emblem := Emblem.create("suit_" + _run.region, 110)
	var emblem_box := CenterContainer.new()
	emblem_box.add_child(emblem)
	column.add_child(emblem_box)
	var act_line := _label(tr("UI_TITLE_ACT_FIGHT") % [_run.act, _run.fight + 1, RunState.FIGHTS_PER_ACT], 26, Palette.PARCHMENT)
	act_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(act_line)
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
	_autosave()
	DetailPanel.suit_counts = TeamBuilder.suit_counts(_run.player_battle_team()) if _run != null else {}
	_stage_sounds()
	_hint_targets.clear()
	FigureArt.gold_hint = _run.gold  # gold-dependent looks (Gold-Armored)
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
			if not _run.open_pack.is_empty():
				_build_pack_overlay()
		RunState.Stage.EVENT:
			_build_event()
			if not _run.open_pack.is_empty():
				_build_pack_overlay()
		RunState.Stage.WON, RunState.Stage.LOST:
			_build_run_end()
	_show_title_card()
	_show_hints.call_deferred()
	_update_guide.call_deferred()
	# A fusion offer (altar, boss, candle, blood moon) lies over every screen.
	if not _run.fusion_offer.is_empty() and _run.stage not in [RunState.Stage.WON, RunState.Stage.LOST]:
		var fusion := FusionView.create(_run, _db, _detail_panel)
		fusion.finished.connect(_on_fusion_finished)
		_screen.add_child(fusion)
	# After a boss (and its fusion): the treasury, choose one treasure.
	elif not _run.treasure.is_empty() and _run.stage not in [RunState.Stage.WON, RunState.Stage.LOST]:
		var treasury := TreasuryView.create(_run, _db, _detail_panel)
		treasury.chosen.connect(func(index: int) -> void:
			_run.take_treasure(index)
			_undo.clear()
			_show_stage())
		_screen.add_child(treasury)


var _guide: Guide


## Guided first run: moves the guide on by what happened, then frames the
## next thing to do (see Guide).
func _update_guide() -> void:
	if is_instance_valid(_guide):
		_guide.queue_free()
	if _run == null or _url_flag("arena") or not Guide.active():
		return
	if not _run.open_pack.is_empty() or not _run.fusion_offer.is_empty() or not _run.treasure.is_empty():
		if not _run.open_pack.is_empty():
			Guide.passed("pack")
		return  # an overlay is open: no frame on the screen beneath
	if is_instance_valid(_region_intro) and _region_intro.is_inside_tree():
		if not _region_intro.tree_exited.is_connected(_update_guide):
			_region_intro.tree_exited.connect(_update_guide, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return  # the guide starts once the region is entered
	if _meta.runs > 0:
		Guide.finish()  # finished runs before: no guide
		return
	var stage := _run.stage
	if Guide.current() == "pack" and not _run.open_pack.is_empty():
		Guide.passed("pack")
	if stage in [RunState.Stage.WON, RunState.Stage.LOST]:
		Guide.finish()
		return
	if Guide.current() == "choose" and stage != RunState.Stage.ENEMY_CHOICE:
		Guide.passed("choose")
	if Guide.current() == "buy" and (stage != RunState.Stage.PLANNING or _filled_slots() >= 2):
		Guide.passed("buy")
	if Guide.current() == "fight" and stage != RunState.Stage.PLANNING:
		Guide.passed("fight")
	if Guide.current() == "reward" and stage != RunState.Stage.REWARD:
		Guide.passed("reward")
	if Guide.current() == "pack" and not _run.open_pack.is_empty():
		Guide.passed("pack")
	if not Guide.active():
		return
	var target: Control = null
	match Guide.current():
		"choose":
			target = _hint_targets.get("choice_easy") if stage == RunState.Stage.ENEMY_CHOICE else null
		"buy":
			if stage == RunState.Stage.PLANNING:
				for slot in _shop_slots:
					if slot.card != null and _run.price_of(_run.shop[slot.index]) <= _run.gold:
						target = slot
						break
		"fight":
			target = _hint_targets.get("fight") if stage == RunState.Stage.PLANNING else null
		"reward":
			target = _hint_targets.get("reward") if stage == RunState.Stage.REWARD else null
		"pack":
			if stage == RunState.Stage.PLANNING and _run.open_pack.is_empty():
				for i in _run.packs.size():
					if not _run.packs[i].is_empty() and _run.pack_cost(_run.packs[i]) <= _run.gold:
						target = _hint_targets.get("pack")
						break
	if target == null or not is_instance_valid(target):
		return
	_guide = Guide.new()
	add_child(_guide)
	_guide.show_step(Guide.TEXTS[Guide.current()], target)


## The phase last announced with a title card (each phase gets one, once).
var _last_title_key := ""
## The region intro while it is open (the title card waits for it).
var _region_intro: Control
## Until when (ticks msec) the phase card is on screen; notes wait for it.
var _title_card_until := 0
var _hint_retry_pending := false


## A short card (about a second) when a new fight or an event begins:
## "Akt 1 · Kampf 2 von 3", "Boss", the event's name. Taps go through.
func _show_title_card() -> void:
	var key := ""
	var title := ""
	var subtitle := ""
	var color := Palette.GOLD
	var emblem := "star"
	match _run.stage:
		RunState.Stage.ENEMY_CHOICE:
			key = "fight:%d:%d" % [_run.act, _run.fight]
			title = tr("UI_TITLE_ACT_FIGHT") % [_run.act, _run.fight + 1, RunState.FIGHTS_PER_ACT]
			subtitle = tr(STAGE_NAMES[_run.fight])
			emblem = "sword"
			if _run.is_boss_fight():
				title = tr("UI_TITLE_BOSS")
				subtitle = tr("UI_TITLE_ACT") % _run.act
				color = Palette.DANGER
				emblem = "skull"
		RunState.Stage.EVENT:
			key = "event:%d:%d:%s" % [_run.act, _run.fight, _run.event.get("id", "")]
			title = tr("EVENT_" + String(_run.event.get("id", "")).to_upper())
			subtitle = tr("UI_TITLE_DANGER") if _run.is_negative_event() else tr("UI_TITLE_EVENT")
			color = Palette.DANGER if _run.is_negative_event() else Palette.MYSTIC
			emblem = "curse" if _run.is_negative_event() else "tarot"
	if key == "" or key == _last_title_key:
		return
	if is_instance_valid(_region_intro) and _region_intro.is_inside_tree():
		return  # shown once the player has entered the region
	_last_title_key = key
	_title_card_until = Time.get_ticks_msec() + 1450
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.top_level = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.06, 0.95)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(26)
	style.shadow_color = Color(color, 0.35)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var symbol := Emblem.create(emblem, 72)
	symbol.color = color
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(symbol)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.set_meta("text_fixed", true)
	var big := _label(title, 48, color)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(big)
	var small := _label(subtitle, 24, Palette.PARCHMENT)
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(small)
	row.add_child(texts)
	add_child(panel)
	panel.reset_size()
	panel.position = (get_viewport_rect().size - panel.size) / 2
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.9)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)


func _on_fusion_finished(title: String, text: String) -> void:
	_undo.clear()  # a fusion is permanent
	_show_stage()
	if title != "":
		_detail_panel.show_message(title, text)


# --- Shared building blocks ----------------------------------------------------------

func _top_bar(title: String) -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 60)
	bar.set_meta("text_fixed", true)  # the bar is full: its numbers keep their size
	bar.add_theme_constant_override("separation", 18)
	bar.add_child(_spacer(8))
	# Back to the main menu; the run is autosaved and can be continued.
	var menu := _button(tr("UI_MENU_BUTTON"), Vector2(0, 48), _show_menu)
	menu.add_theme_font_size_override("font_size", 18)
	bar.add_child(menu)

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	# Resources as symbols with numbers; a tap explains each one (planning shows them as boxes).
	_add_resource_chips(bar)

	if _url_flag("debug"):
		# One "Debug" button opens the tools as a column (the bar is full).
		var toggle := _button("Debug", Vector2(0, 48), func() -> void:
			_debug_open = not _debug_open
			_show_debug_tools())
		toggle.add_theme_font_size_override("font_size", 16)
		bar.add_child(toggle)
		_show_debug_tools.call_deferred()
	bar.add_child(_spacer(8))
	# The title (event name, stage) sits exactly in the middle of the screen.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := _label(title, 28, Palette.GOLD)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(title_label)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 60)
	holder.set_meta("text_fixed", true)
	holder.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return holder


var _debug_open := false



func _add_resource_chips(bar: Control) -> void:
	bar.add_child(_resource_chip("coin", str(_run.gold), Palette.GOLD, tr("UI_RES_GOLD") % [_run.gold, _run.interest()],
		"+%d" % _run.interest() if _run.interest() > 0 else ""))
	bar.add_child(_resource_chip("soul", str(_run.souls), Emblem.COLORS["soul"], tr("UI_RES_SOULS") % _run.souls))
	bar.add_child(_resource_chip("level", "%d/%d" % [_filled_slots(), _run.slot_count()], Palette.PARCHMENT,
		tr("UI_RES_SLOTS") % [_filled_slots(), _run.slot_count()]))


## Resources as their own boxes in planning: symbol, big number, name, extra line.
func _resource_boxes(columns: int = 3) -> Control:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_gold_box = _resource_box("coin", str(_run.gold), tr("UI_BOX_GOLD"), Palette.GOLD,
		"+%d" % _run.interest() if _run.interest() > 0 else "", tr("UI_RES_GOLD") % [_run.gold, _run.interest()])
	grid.add_child(_gold_box)
	var souls_box := _resource_box("soul", str(_run.souls), tr("UI_BOX_SOULS"), Emblem.COLORS["soul"], "",
		tr("UI_RES_SOULS") % _run.souls)
	if _run.souls == 0:
		souls_box.modulate = Color(1, 1, 1, 0.55)  # nothing to spend: quiet
	grid.add_child(souls_box)
	grid.add_child(_resource_box("level", "%d/%d" % [_filled_slots(), _run.slot_count()], tr("UI_BOX_SLOTS"), Palette.PARCHMENT, "",
		tr("UI_RES_SLOTS") % [_filled_slots(), _run.slot_count()]))
	return grid


func _resource_box(kind: String, value: String, name: String, color: Color, extra: String, explanation: String) -> Control:
	var panel := _elegant_panel(0.6)
	panel.custom_minimum_size = Vector2(224, 72)
	panel.get_theme_stylebox("panel").set_content_margin_all(12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emblem := Emblem.create(kind, 42)
	emblem.color = color
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(emblem)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if value != "":
		var number := _label(value, 36, color)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(number)
	var title := _label(name, 17, Palette.PARCHMENT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	if extra != "":  # e.g. "+1" interest; the tap explains it
		var small := _label(extra, 17, Color(Palette.GOLD, 0.7))
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(small)
	texts.add_child(top)
	row.add_child(texts)
	panel.add_child(row)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			_detail_panel.show_message(name if value == "" else tr("UI_RES_TITLE"), explanation))
	return panel


## One resource in the top bar: symbol, number, a small extra (interest); tap = explanation.
func _resource_chip(kind: String, value: String, color: Color, explanation: String, extra: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 48)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var emblem := Emblem.create(kind, 28)
	emblem.color = color
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(emblem)
	if value != "":
		var number := _label(value, 28, color)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(number)
	if extra != "":
		var small := _label(extra, 18, Palette.MUTED)
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(small)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			_detail_panel.show_message(tr("UI_RES_TITLE"), explanation))
	return row


## The shop counter: figure offers and packs as two framed shelves, the
## actions (fight, enemy, reroll, undo) as a column at the right end.
func _shop_counter() -> Control:
	var panel := _elegant_panel(0.85)
	_hint_targets["shop"] = panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	# Figures shelf
	var figures := _shelf(tr("UI_SHOP_FIGURES"))
	var figure_row := HBoxContainer.new()
	figure_row.add_theme_constant_override("separation", 14)
	_shop_slots.clear()
	for i in _run.shop.size():
		var slot := SlotView.new("shop", i)
		if _run.shop[i] != "":
			slot.set_card(UnitCard.for_definition(_db.figures[_run.shop[i]], 1, false))
			_add_rarity_effect(slot, _run.shop[i])
			var merge_into := _run.reward_target(_run.shop[i])
			if merge_into >= 0 and _run.row[merge_into] != null:
				slot.add_child(_merge_badge())  # buying it levels up a figure in the row
		slot.accepts_drops = false
		slot.tapped.connect(_on_slot_tapped)
		if _run.shop[i] != "" and _run.price_of(_run.shop[i]) > _run.gold:
			slot.modulate = Color(0.78, 0.78, 0.78)  # too expensive right now: a little darker
		figure_row.add_child(_with_price(slot, _run.price_of(_run.shop[i]) if _run.shop[i] != "" else -1, false))
		_shop_slots.append(slot)
	figures.get_child(0).add_child(figure_row)
	row.add_child(figures)
	# Packs shelf
	var packs := _shelf(tr("UI_SHOP_PACKS"))
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 14)
	for i in _run.packs.size():
		var pack_view := _pack_view(i)
		pack_row.add_child(pack_view)
		if not _run.packs[i].is_empty() and not _hint_targets.has("pack"):
			_hint_targets["pack"] = pack_view
	var soul_view := _soul_pack_view()
	pack_row.add_child(soul_view)
	if _run.souls > 0:
		_hint_targets["souls"] = soul_view
	packs.get_child(0).add_child(pack_row)
	row.add_child(packs)
	# Actions: fight first, then the enemy look, reroll and undo.
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	var fight := _seal(tr("UI_FIGHT"), 132, "red", _on_fight)
	_hint_targets["fight"] = fight
	fight.add_theme_font_size_override("font_size", 28)
	fight.disabled = _filled_slots() == 0
	actions.add_child(_centered(fight))
	var peek := _button(tr("UI_SHOW_ENEMY"), Vector2(190, 48), _show_enemy_popup)
	peek.add_theme_font_size_override("font_size", 16)
	actions.add_child(peek)
	var reroll_text := tr("UI_REROLL_FREE") % _run.free_rerolls if _run.free_rerolls > 0 else tr("UI_REROLL_BUTTON") % _run.reroll_price()
	var reroll := _button(reroll_text, Vector2(190, 48), _on_reroll)
	reroll.add_theme_font_size_override("font_size", 16)
	reroll.add_theme_color_override("font_color", Palette.GOLD)
	reroll.disabled = _run.gold < _run.reroll_price() and _run.free_rerolls <= 0
	actions.add_child(reroll)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 8)
	_undo_button = _button(tr("UI_UNDO"), Vector2(0, 48), _on_undo)
	_undo_button.add_theme_font_size_override("font_size", 14)
	_undo_button.disabled = _undo.is_empty()
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small.add_child(_undo_button)
	if _run.can_skip_boss():
		var skip_boss := _button(tr("UI_SKIP_BOSS"), Vector2(0, 48), _on_skip_boss)
		skip_boss.add_theme_font_size_override("font_size", 14)
		small.add_child(skip_boss)
	actions.add_child(small)
	row.add_child(actions)
	return panel


## A framed shelf inside the shop counter with a small heading.
func _shelf(title: String) -> Control:
	var panel := _elegant_panel(0.45)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.add_child(_label(title, 16, Palette.GOLD))
	panel.add_child(column)
	return panel


## The one panel look of the planning screen: dark glass, a fine gold edge,
## soft shadow (team stage, item shelf, shop counter).
func _elegant_panel(alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.06, alpha)
	style.border_color = Color(Palette.GOLD, 0.45)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A card with its price as a tag below ("3 Gold"); -1 = sold out.
func _with_price(content: Control, price: int, soul: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(content)
	var tag := _label(("%d %s" % [price, tr("UI_SOULS_SHORT") if soul else "Gold"]) if price >= 0 else tr("UI_SOLD_OUT"), 16,
		Emblem.COLORS["soul"] if soul else Palette.GOLD)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Palette.MUTED if price < 0 or (not soul and price > _run.gold) else tag.get_theme_color("font_color"))
	box.add_child(tag)
	return box


## Relics, tarot and pacts in three tinted rows (no headings): a small
## symbol starts each row, a fine gold line separates them.
func _item_shelf() -> Control:
	var panel := _elegant_panel(0.55)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var first := true
	for group in [["relic", RunState.MAX_RELICS, _run.relics], ["tarot", RunState.MAX_TAROTS, _run.tarots],
			["pact", RunState.MAX_PACTS, _run.pacts], ["equipment", RunState.MAX_STASH, _run.stash]]:
		if not first:
			var line := ColorRect.new()
			line.color = Color(Palette.GOLD, 0.3)
			line.custom_minimum_size = Vector2(0, 1)
			column.add_child(line)
		first = false
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var symbol := Emblem.create(STASH_EMBLEM if group[0] == "equipment" else group[0], 20)
		if group[0] == "equipment":
			symbol.color = STASH_COLOR
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(symbol)
		for i in int(group[1]):
			var list: Array = group[2]
			if group[0] == "equipment":
				row.add_child(_stash_slot(i, list[i] if i < list.size() else {}, 60))
			else:
				row.add_child(_strip_slot(group[0], i, list[i] if i < list.size() else "", 60))
		column.add_child(row)
	return panel


const STASH_EMBLEM := "sword"
const STASH_COLOR := Color("b8c8dc")


## A place of the equipment stash: empty, or the waiting item (drag it onto
## a figure, or onto the sell field).
func _stash_slot(index: int, item: Dictionary, side: float) -> Control:
	if item.is_empty():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(STASH_COLOR, 0.07)
		style.border_color = Color(STASH_COLOR, 0.45)
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		empty.add_theme_stylebox_override("panel", style)
		var hint := Emblem.create(STASH_EMBLEM, side * 0.5)
		hint.color = STASH_COLOR
		hint.modulate.a = 0.3
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.position = Vector2(side * 0.25, side * 0.25)
		empty.add_child(hint)
		return empty
	var card := ObjectCard.create(_db, {"kind": "equipment", "item": item}, Vector2(side, side), true)
	card.tapped.connect(func(c: ObjectCard) -> void:
		_detail_panel.show_object(c)
		_detail_panel.show_hint(tr("UI_DRAG_STASH") % (Items.equipment_price(_db, item) / 2)))
	_make_object_draggable(card, {"kind": "stash", "index": index})
	return card


## The chosen enemy band as a window (the planning screen shows only your team).
func _show_enemy_popup() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(overlay)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	overlay.add_child(column)
	var title := _label(tr("UI_NEXT_ENEMY"), 30, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_centered(_scaled(_card_row(_run.chosen_enemy["team"], true, false), 1.3)))
	column.add_child(_centered(_button(tr("UI_CLOSE"), Vector2(240, 56), overlay.queue_free)))


var _debug_panel: Control


## The debug tools as a column at the top right (stays open across screens).
func _show_debug_tools() -> void:
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
	if not _debug_open or _run == null:
		return
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var entries := [["+10 Gold", _debug_gold], ["Boss", _debug_to_boss], [tr("UI_DEBUG_EVENT"), _debug_event], ["+5 " + tr("UI_PACTS_SOULS"), _debug_souls], ["Unikat", _debug_unique], ["Fusion", _debug_fusion], ["+50 Glut", _debug_glut], ["Schatz", _debug_treasure], ["Beute", _debug_loot]]
	if _run.stage == RunState.Stage.PLANNING:
		entries.insert(2, ["Legende", _debug_legend])
	for entry in entries:
		var button := _button(entry[0], Vector2(170, 48), entry[1])
		button.add_theme_font_size_override("font_size", 16)
		column.add_child(button)
	add_child(panel)
	panel.reset_size()
	panel.position = Vector2(get_viewport_rect().size.x - panel.size.x - 12, 64)
	_debug_panel = panel


# --- Debug tools ("?debug=1" in the address) ---------------------------------------

## Opens a hard band's loot pack right away.
func _debug_loot() -> void:
	if _run.open_pack.is_empty():
		_run.open_loot_pack()
	_show_stage()


## Opens the boss treasury right away.
func _debug_treasure() -> void:
	_run._roll_treasure()
	if _run.treasure.is_empty():  # after the last boss: still show it
		_run.treasure = [{"kind": "gold", "amount": RunState.TREASURE_GOLD}, {"kind": "legend_pack"}]
	_show_stage()


func _debug_glut() -> void:
	_meta.glut += 50
	_meta.save()
	_show_stage()


## Starts the next event in the list (cycles through all eight).
func _debug_event() -> void:
	var ids: Array = _db.items["events"]["ids"] + _db.items["events"].get("negative_ids", [])
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


## Blood Moon: two free fusions right away (plus a fuller row to fuse).
func _debug_fusion() -> void:
	# Fill empty slots so there is something to fuse (incl. a recipe pair).
	var picks := ["king_midas", "golden_scales", "executioner", "blood_drinker", "spark_bearer"]
	for i in _run.row.size():
		if _run.row[i] == null and not picks.is_empty():
			_run.row[i] = _run._new_figure(picks.pop_front())
	_run.souls += 9
	_run.start_event("blood_moon")
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


## A control with some room around it (left/right, top).
func _with_margin(content: Control, side: int, top: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_child(content)
	return margin


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


## The own team as cards with all their data (equipment, blessing, fusion,
## relic effects), back on the left and front on the right.
func _own_team_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_SPACING)
	var team := _run.player_battle_team()
	team.reverse()
	for entry in team:
		var card := UnitCard.for_entry(entry, entry["figure"], _db)
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
	if _rule_text() != "":  # a boss rule matters for the choice
		column.add_child(_rich_line(_rule_text(), 17))

	# One band at a time: take it, or risk the next (stronger, richer) one -
	# without seeing it first. No way back, no skipping.
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 28)
	column.add_child(_fitted(options, 1.3))
	var step := clampi(_run.choice_step, 0, _run.enemy_options.size() - 1)
	var option_panel := _enemy_option_panel(_run.enemy_options[step], step)
	options.add_child(option_panel)
	_hint_targets["choice"] = option_panel
	_hint_targets["choice_easy"] = option_panel
	if step < _run.enemy_options.size() - 1:
		options.add_child(_risk_panel(step + 1))

	var own := HBoxContainer.new()
	own.alignment = BoxContainer.ALIGNMENT_CENTER
	own.add_theme_constant_override("separation", 16)
	var own_stage := _elegant_panel(0.5)
	own_stage.add_child(_scaled(_own_team_row(), 0.85))
	own.add_child(own_stage)
	column.add_child(own)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)


## The face-down next band: stronger, more gold - what exactly stays hidden.
func _risk_panel(next_step: int) -> Control:
	var panel := _elegant_panel(0.7)
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := _label(tr("UI_RISK_TITLE"), 26, Palette.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var back := Emblem.create("enemy", 90)
	back.color = Palette.DANGER
	box.add_child(_centered(back))
	var next: Dictionary = _run.enemy_options[next_step]
	var text := _label(tr("UI_RISK_TEXT") % [tr(DIFFICULTY_NAMES[next["difficulty"]]), next["bonus"]], 19, Palette.PARCHMENT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(260, 0)
	box.add_child(text)
	var risk := _button(tr("UI_RISK_BUTTON"), Vector2(220, 60), func() -> void:
		if _run.risk_next_band():
			_show_stage())
	risk.add_theme_color_override("font_color", Palette.DANGER)
	risk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(risk)
	return panel


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
	var max_width := 600.0
	var factor := clampf(max_width / maxf(team_width, 1.0), 0.5, 1.0)
	var cards := CenterContainer.new()
	cards.custom_minimum_size = Vector2(0, 0)
	cards.add_child(_scaled(_card_row(option["team"], true, false), factor))
	box.add_child(cards)
	var choose := _button(tr("UI_TAKE_BAND"), Vector2(220, 60), _on_choose_enemy.bind(index))
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


## Width of the side columns in planning (items left, resources right).
const SIDE_COLUMN := 248
## The gold box of the planning screen (coins fly from it when buying).
var _gold_box: Control


## Left column of shop and events: menu, then relics/tarot/pacts/stash.
func _side_column_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(SIDE_COLUMN, 0)
	left.add_theme_constant_override("separation", 10)
	var menu := _button(tr("UI_MENU_BUTTON"), Vector2(SIDE_COLUMN, 48), _show_menu)
	menu.add_theme_font_size_override("font_size", 18)
	left.add_child(menu)
	left.add_child(_item_shelf())
	return left


## Right column of shop and events: gold, souls, places (and debug).
func _side_column_right() -> Control:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDE_COLUMN, 0)
	right.add_theme_constant_override("separation", 10)
	right.set_meta("text_fixed", true)
	var boxes := _resource_boxes(1)
	boxes.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(boxes)
	if _url_flag("debug"):
		var toggle := _button("Debug", Vector2(120, 48), func() -> void:
			_debug_open = not _debug_open
			_show_debug_tools())
		toggle.add_theme_font_size_override("font_size", 16)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(toggle)
		_show_debug_tools.call_deferred()
	return right


func _build_planning() -> void:
	_screen.add_child(_velvet())
	var column := _column()
	_strip_cards.clear()
	_suit_label = null

	# Upper half: menu and items on the left, the team in the middle, the
	# resources on the right (both side columns equally wide: the team stays centred).
	var upper := HBoxContainer.new()
	upper.add_theme_constant_override("separation", 16)
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 1.1
	upper.add_child(_with_margin(_side_column_left(), 12, 8))
	var team := VBoxContainer.new()
	team.alignment = BoxContainer.ALIGNMENT_CENTER
	team.add_theme_constant_override("separation", 6)
	var stage := _elegant_panel(0.55)
	var stage_box := VBoxContainer.new()
	stage_box.add_theme_constant_override("separation", 2)
	stage_box.add_child(_own_row_slots())
	stage_box.add_child(_xp_hint_row())
	stage.add_child(stage_box)
	team.add_child(stage)
	if _rule_text() != "":  # a boss rule matters for planning: it stays in sight
		team.add_child(_rich_line(_rule_text(), 16))
	upper.add_child(_fitted(team, 1.6))
	upper.add_child(_with_margin(_side_column_right(), 12, 8))
	column.add_child(upper)

	# Lower half: the shop counter with the actions at its right end.
	var shop := _fitted(_centered(_shop_counter()), 1.5)
	shop.size_flags_stretch_ratio = 1.0
	column.add_child(shop)
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(bottom_gap)

	# The sell zone only shows up while a figure or object is held or selected.
	_sell_zone = SellZone.new()
	_sell_zone.custom_minimum_size = Vector2(340, 120)
	_sell_zone.set_auto_hide(true)
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(_on_sell_dropped)
	_screen.add_child(_sell_zone)
	_sell_zone.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_sell_zone.position += Vector2(-24, -40)


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
		slot.drop_check = _drop_state
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
	# Text grows after the build (UiText): fit again whenever the content does.
	content.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	fit.call_deferred()
	return holder


## Small "XP" bars under the row slots (front on the right, like the slots).
func _xp_hint_row() -> HBoxContainer:
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", CARD_SPACING)
	for i in range(_run.slot_count() - 1, -1, -1):
		var figure: Variant = _run.row[i]
		if figure != null and not figure.has("fusion") and not figure.has("recipe_parts"):
			hints.add_child(LevelPips.create(figure, _run))
		else:
			var empty := Control.new()
			empty.custom_minimum_size = Vector2(UnitCard.CARD_SIZE.x, 20)
			hints.add_child(empty)
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
	# One principle everywhere: dragging acts, tapping only shows the info.
	_clear_selection()
	if slot.card != null:
		_detail_panel.show_card(slot.card)
		_detail_panel.show_hint(tr("UI_DRAG_TO_BUY") if slot.kind == "shop" else tr("UI_DRAG_TO_MOVE"))


## A tarot card dragged onto a row figure: use it there (the candle starts
## its fusion instead).
func _use_tarot_on(tarot_index: int, row_index: int) -> void:
	if tarot_index < 0 or tarot_index >= _run.tarots.size():
		return
	var card_id: String = _run.tarots[tarot_index]
	if card_id == "ritual_candle":
		if _run.start_candle_fusion():
			_event_targets.clear()
			_show_stage()
		return
	var before_xp := int(_run.row[row_index]["xp"]) if _run.row[row_index] != null else 0
	var snapshot := _run.to_dict()
	if _run.use_tarot(tarot_index, row_index):
		_undo.append(snapshot)  # tarot use can be undone (the RNG state is restored too)
		_show_stage()
		if card_id == "magician" and _run.row[row_index] != null:
			_show_merge(_run.row[row_index]["def_id"], before_xp, int(_run.row[row_index]["xp"]))
	elif _run.row[row_index] != null:
		_detail_panel.show_message(ItemText.tarot_name(card_id), tr("UI_OBJECT_LIMIT"))


func _on_slot_dropped(data: Dictionary, slot: SlotView) -> void:
	if data["kind"] == "tarot":
		_use_tarot_on(data["index"], slot.index)
	elif data["kind"] == "stash":
		var snapshot := _run.to_dict()
		if _run.equip_from_stash(data["index"], slot.index):
			_undo.append(snapshot)
			Sound.play("card_place")
			_show_stage()
		elif _run.row[slot.index] != null:
			_detail_panel.show_message(tr("UI_CAT_EQUIPMENT"), tr("UI_OBJECT_LIMIT"))
	elif data["kind"] == "shop":
		_buy(data["index"], slot.index)
	elif data["kind"] == "row":
		_move(data["index"], slot.index)
	elif data["kind"] == "pack":
		_pack_pick = data["index"]
		_on_pack_target(slot)
	elif data["kind"] == "market_figure":
		if _run.resolve_event("buy_figure", [slot.index]):
			_show_stage()
	elif data["kind"] == "reward":
		if _run.take_reward_at(data["index"], slot.index):
			_undo.clear()
			_show_stage()
		else:
			_detail_panel.show_message(tr(ContentDb.name_key(_db.figures[_run.rewards[data["index"]]])), tr("UI_NEEDS_FREE_SLOT"))


## Dropped between two cards: the figure is inserted there. Visually the
## front is on the right, so "left of a card" means behind it.
func _on_slot_inserted(data: Dictionary, slot: SlotView, side: String) -> void:
	var from: int = data["index"]
	# The edges always place the figure beside it (the glowing line shows it);
	# merging happens on the card itself, where it lights up gold.
	var after_index := slot.index if side == "left" else slot.index - 1
	_apply_action(func() -> bool: return _run.insert_between(from, after_index))


## What dropping the dragged thing on a row place would do (for the glow).
func _drop_state(data: Dictionary, index: int) -> String:
	if _run == null or index >= _run.row.size():
		return ""
	var target: Variant = _run.row[index]
	var def_id := ""
	var cost := 0
	match String(data.get("kind", "")):
		"row":
			var from: int = data.get("index", -1)
			if from == index or from < 0 or from >= _run.row.size() or _run.row[from] == null:
				return ""
			if target == null:
				return "free"
			return "merge" if merging_possible(target, _run.row[from]) else "swap"
		"shop":
			def_id = _run.shop[data["index"]] if int(data["index"]) < _run.shop.size() else ""
			cost = _run.price_of(def_id) if def_id != "" else 0
		"reward":
			def_id = _run.rewards[data["index"]] if int(data["index"]) < _run.rewards.size() else ""
		"market_figure":
			def_id = String(_run.event.get("figure", ""))
			cost = _run.price_of(def_id) / 2 if def_id != "" else 0
		"stash":
			if target == null:
				return ""
			return "free" if _run.can_add_object(target, "equipment") else "no"
		"tarot":
			if target == null:
				return ""
			var tarot: String = _run.tarots[data["index"]] if int(data["index"]) < _run.tarots.size() else ""
			if tarot == "ritual_candle":
				return "free"
			if tarot == "strength" and not _run.can_add_object(target, "strength"):
				return "no"
			if tarot in ["star", "sun"] and not _run.can_add_object(target, "blessing"):
				return "no"
			return "free"
		"pack":
			var entry: Dictionary = _run.open_pack.get("items", [])[data["index"]] if not _run.open_pack.is_empty() else {}
			if entry.get("kind", "") == "equipment":
				return "free" if target != null and _run.can_add_object(target, "equipment") else "no"
			def_id = String(entry.get("def_id", ""))
		_:
			return ""
	if def_id == "":
		return ""
	if _run.gold < cost:
		return "no"
	if target == null:
		return "free"
	return "merge" if _run.can_place(def_id, index) else "no"


func merging_possible(target: Dictionary, source: Dictionary) -> bool:
	return not source.has("fusion") and not source.has("recipe_parts") and _run.can_merge_into(target, source["def_id"])


func _merge_block_text(target: Dictionary, source: Dictionary) -> String:
	if target.has("fusion") or source.has("fusion") or target.has("recipe_parts") or source.has("recipe_parts"):
		return tr("UI_MERGE_FUSED")
	return tr("UI_MERGE_MAX")


## Moves (or swaps) row figures; dropping onto an equal figure merges them.
func _move(from_index: int, to_index: int) -> void:
	var target: Variant = _run.row[to_index] if to_index < _run.row.size() else null
	var source: Variant = _run.row[from_index] if from_index < _run.row.size() else null
	var merging: bool = target != null and source != null and target["def_id"] == source["def_id"]
	var before_xp := int(target["xp"]) if merging else -1
	Sound.play("card_slide")
	# Explain why two equal figures do not merge.
	if target != null and source != null and target["def_id"] == source["def_id"] and not merging_possible(target, source):
		_detail_panel.show_message(tr(ContentDb.name_key(_db.figures[source["def_id"]])), _merge_block_text(target, source))
	_apply_action(func() -> bool: return _run.move(from_index, to_index))
	if merging and _run.row[from_index] == null:
		_show_merge(_run.row[to_index]["def_id"], before_xp, int(_run.row[to_index]["xp"]))


## Buys a shop figure; shows the merge screen when it joined an equal figure.
func _buy(shop_index: int, row_index: int) -> void:
	var before: Variant = _run.row[row_index] if row_index < _run.row.size() else null
	var before_xp := int(before["xp"]) if before != null else -1
	var gold_before := _run.gold
	var wanted: String = _run.shop[shop_index] if shop_index < _run.shop.size() else ""
	_apply_action(func() -> bool: return _run.buy(shop_index, row_index))
	if _run.gold == gold_before and before != null and before["def_id"] == wanted and not merging_possible(before, {"def_id": wanted}):
		_detail_panel.show_message(tr(ContentDb.name_key(_db.figures[wanted])), _merge_block_text(before, {"def_id": wanted}).split("–")[0])
	if _run.gold < gold_before:
		Sound.play("card_place")
		Sound.play("coins", -8.0)
		_fly_coins(row_index, gold_before - _run.gold)
	var after: Variant = _run.row[row_index] if row_index < _run.row.size() else null
	if before != null and after != null and int(after["xp"]) > before_xp:
		_show_merge(after["def_id"], before_xp, int(after["xp"]))


## A few coins fly from the gold box to the bought figure's place (0.4 s).
func _fly_coins(row_index: int, amount: int) -> void:
	await get_tree().process_frame  # the rebuilt screen needs its layout first
	await get_tree().process_frame
	if not is_instance_valid(_gold_box):
		return
	var target: Control = null
	for slot in _row_slots:
		if is_instance_valid(slot) and slot.index == row_index:
			target = slot
	if target == null:
		return
	var from := _gold_box.get_global_rect().get_center()
	var to := target.get_global_rect().get_center()
	for i in clampi(amount, 2, 5):
		var coin := Emblem.create("coin", 26)
		coin.color = Palette.GOLD
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.top_level = true
		coin.size = Vector2(26, 26)  # free-floating: no container sets its size
		add_child(coin)
		coin.global_position = from - Vector2(13, 13)
		var tween := create_tween()
		tween.tween_interval(i * 0.05)
		tween.tween_property(coin, "global_position", to - Vector2(13, 13) + Vector2(randf_range(-12, 12), 0), 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)


## Runs an undoable shop action; rebuilds the screen if it succeeded.
func _apply_action(action: Callable) -> void:
	var snapshot := _run.to_dict()
	if action.call():
		_undo.append(snapshot)
		_show_stage()
	else:
		_clear_selection()


func _on_sell_dropped(data: Dictionary) -> void:
	if data.get("kind") == "stash":
		if _run.sell_stash(data["index"]):
			_undo.clear()
			_show_stage()
	elif data.get("kind") == "relic":
		if _run.sell_relic(data["index"]):
			_undo.clear()
			_show_stage()
	else:
		_request_sell(data["index"])


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
	Sound.play("sell")
	_apply_action(func() -> bool: return _run.sell(index))


func _on_undo() -> void:
	if _undo.is_empty():
		return
	_run = RunState.from_dict(_db, _undo.pop_back())
	_show_stage()


func _on_reroll() -> void:
	if _run.reroll():
		Sound.play("shuffle")
		_undo.clear()  # rerolls are final: no undoing into old offers
		_show_stage()


## Before a battle: a warning when places are free and gold would buy a figure.
func _on_fight() -> void:
	var cheapest := 999
	for id in _run.shop:
		if id != "":
			cheapest = mini(cheapest, _run.price_of(id))
	var free := _run.slot_count() - _filled_slots()
	if free > 0 and _run.gold >= cheapest and not _fight_confirmed:
		_confirm(tr("UI_FIGHT_WARN_TITLE"), tr("UI_FIGHT_WARN") % [free, _run.gold], tr("UI_FIGHT_ANYWAY"), func() -> void:
			_fight_confirmed = true
			_on_fight())
		return
	_fight_confirmed = false
	_start_fight()


var _fight_confirmed := false
var _suit_label: RichTextLabel


## While a new figure is dragged onto a free place, the suit line shows the
## bonuses the row would have with it.
func _notification(what: int) -> void:
	if not is_instance_valid(_suit_label) or _run == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		var def_id := ""
		if data is Dictionary:
			match String(data.get("kind", "")):
				"shop": def_id = _run.shop[data["index"]] if int(data["index"]) < _run.shop.size() else ""
				"reward": def_id = _run.rewards[data["index"]] if int(data["index"]) < _run.rewards.size() else ""
		if def_id != "" and _run.reward_target(def_id) >= 0 and _run.row[_run.reward_target(def_id)] == null:
			var preview := _suit_bonus_text(String(_db.figures[def_id]["suit"]))
			_suit_label.text = "[center]" + tr("UI_SUIT_PREVIEW") + " " + preview + "[/center]"
	elif what == NOTIFICATION_DRAG_END:
		var line := _suit_bonus_text()
		_suit_label.text = "[center]" + line + "[/center]" if line != "" else ""


## A small question window: text, a confirm button and "Zurück".
func _confirm(title_text: String, text: String, ok_text: String, on_ok: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(overlay)
	var panel := _elegant_panel(0.95)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label(title_text, 26, Palette.GOLD))
	var body := _label(text, 20, Palette.PARCHMENT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	column.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(_button(tr("UI_BACK"), Vector2(200, 54), overlay.queue_free))
	buttons.add_child(_button(ok_text, Vector2(240, 54), func() -> void:
		overlay.queue_free()
		on_ok.call()))
	column.add_child(buttons)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	overlay.add_child(center)


func _start_fight() -> void:
	_undo.clear()
	if is_instance_valid(_guide):
		_guide.queue_free()
	Sound.music("boss" if _run.is_boss_fight() else "battle")
	if _run.is_boss_fight():
		Sound.play("roar")
	_detail_panel.hide()
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()  # the debug column must not cover the battle
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


func _strip_slot(kind: String, index: int, id: String, side: float = 52.0) -> Control:
	if id == "":
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Emblem.COLORS.get(kind, Color.WHITE), 0.07)
		style.border_color = Color(Emblem.COLORS.get(kind, Color.WHITE), 0.45)
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		empty.add_theme_stylebox_override("panel", style)
		# A faint symbol shows what belongs here, without a word.
		var hint := Emblem.create(kind, side * 0.5)
		hint.modulate.a = 0.3
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.position = Vector2(side * 0.25, side * 0.25)
		empty.add_child(hint)
		return empty
	var card := ObjectCard.create(_db, {"kind": kind, "id": id}, Vector2(side, side), true)
	card.tapped.connect(func(c: ObjectCard) -> void: _on_strip_tapped(kind, index, c))
	if kind in ["tarot", "relic"]:
		_make_object_draggable(card, {"kind": kind, "index": index})
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
	# Tapping shows the info; acting is dragging (tarot onto a figure, relic
	# onto the sell field). The candle also works on the event screen.
	_detail_panel.show_object(card)
	if kind == "tarot" and (_run.stage == RunState.Stage.PLANNING or _run.tarots[index] == "ritual_candle"):
		_detail_panel.show_hint(tr("UI_DRAG_TAROT"))
	elif kind == "relic" and _run.stage == RunState.Stage.PLANNING:
		_detail_panel.show_hint(tr("UI_DRAG_RELIC") % (Items.relic_price(_db, _run.relics[index]) / 2))


## Dark velvet behind the tarot spread.
func _velvet() -> Control:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("3a0e2a"))
	gradient.set_color(1, Color("0e030a"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.6)
	texture.fill_to = Vector2(1.1, 1.2)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Green "+1" with an arrow: this shop figure would level up one in the row.
func _merge_badge() -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.45, 0.18, 0.95)
	style.border_color = Color(0.6, 1.0, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 6
	style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("text_fixed", true)
	var label := _label("+1 Stufe", 14, Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	badge.position = Vector2(UnitCard.CARD_SIZE.x / 2 - 28, 34)  # below the level seal, clear of the stats
	var tween := badge.create_tween().set_loops()
	tween.tween_property(badge, "modulate:a", 0.55, 0.6)
	tween.tween_property(badge, "modulate:a", 1.0, 0.6)
	return badge


## A price as a gold (or soul-blue) coin above a card.
func _coin_badge(text: String, soul: bool) -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if text == "":
		center.custom_minimum_size = Vector2(0, 40)
		return center
	var coin := PanelContainer.new()
	coin.custom_minimum_size = Vector2(40, 40)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("8fd8ff") if soul else Color("e8b648")
	style.border_color = Color("1e4a6a") if soul else Color("4a3208")
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	coin.add_theme_stylebox_override("panel", style)
	var label := _label(text, 20, Color("1a1208"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin.add_child(label)
	center.add_child(coin)
	return center


## A card-sized control with its price coin overlapping the top edge. The coin
## is drawn after the card inside the same holder, so overlays (detail panel,
## pack and fusion screens) still cover it.
func _with_coin(content: Control, text: String, soul: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = UnitCard.CARD_SIZE + Vector2(0, 32)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(content)
	content.position = Vector2(0, 32)
	content.size = UnitCard.CARD_SIZE
	if text != "":
		var coin := _coin_badge(text, soul)
		coin.position = Vector2(UnitCard.CARD_SIZE.x / 2.0 - 20.0, 0)
		coin.size = Vector2(40, 40)
		holder.add_child(coin)
	return holder


## A round wax-seal button.
func _seal(text: String, diameter: float, color_kind: String, callback: Callable) -> Button:
	var colors := {"gold": [Color("d8a63a"), Color("6a4a10"), Color("2a1808")],
		"grey": [Color("4a4450"), Color("2a2630"), Color("e0dae6")],
		"red": [Color("b02830"), Color("5a0c14"), Color("ffe8d0")]}
	var c: Array = colors[color_kind]
	var button := Button.new()
	button.set_meta("text_fixed", true)  # round seals have no room for bigger text
	button.text = text
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = c[0].lightened(0.12) if state == "hover" else (c[0].darkened(0.15) if state == "pressed" else c[0])
		if state == "disabled":
			style.bg_color = c[0].darkened(0.55)
		if state == "focus":
			style.draw_center = false
		style.border_color = c[1]
		style.set_border_width_all(5)
		style.set_corner_radius_all(int(diameter / 2.0))
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 4)
		button.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, c[2])
	button.add_theme_color_override("font_disabled_color", Color(c[2], 0.4))
	button.pressed.connect(callback)
	return button


## The soul pack (paid in souls): pick one of several pacts. Its own pixel
## back (violet-black velvet, bone-silver frame, soul flame in a pact sigil)
## with the name strip at the bottom, like the arcana packs.
func _soul_pack_view() -> Control:
	var box := VBoxContainer.new()
	box.set_meta("text_fixed", true)  # card-sized panel
	var full := _run.pacts.size() >= RunState.MAX_PACTS
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UnitCard.CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("150b24")
	style.set_corner_radius_all(2)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(CardBackArt.rect(Cosmetics.back, "soul", UnitCard.CARD_SIZE))
	var choices := int(_db.items["packs"]["soul_pack"]["choices"])
	var info := tr("UI_PACT_SLOTS_FULL") if full else tr("UI_PACK_CONTENT") % [choices, 1]
	panel.add_child(_pack_plate(tr("UI_SOUL_PACK"), info, Palette.DANGER if full else Color("99d9ff"), Color("99d9ff")))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var price := _run.soul_pack_price()
			_detail_panel.show_message(tr("UI_SOUL_PACK"), tr("UI_SOUL_PACK_INFO"))
			_detail_panel.show_action(tr("UI_BUY_OPEN_SOULS") % price, func() -> void:
				if _run.buy_soul_pack():
					_undo.clear()
					_pack_pick = -1
					_show_stage(), _run.souls >= price and _run.pacts.size() < RunState.MAX_PACTS))
	box.add_child(_with_price(panel, _run.soul_pack_price(), true))
	if full:  # darker, but the strip still says why
		panel.modulate = Color(0.55, 0.55, 0.6)
	elif _run.soul_pack_price() > _run.souls:
		panel.modulate = Color(0.78, 0.78, 0.78)
	return box


## The strip at the bottom of a pack back: dark glass with a fine edge,
## the pack's name and one line below it.
func _pack_plate(title: String, line: String, line_color: Color, edge: Color) -> Control:
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_END
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 0)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.04, 0.03, 0.06, 0.82)
	plate_style.border_color = Color(edge, 0.7)
	plate_style.border_width_top = 1
	plate_style.set_content_margin_all(3)
	plate_style.content_margin_bottom = 5
	plate.add_theme_stylebox_override("panel", plate_style)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 0)
	plate.add_child(texts)
	inner.add_child(plate)
	var name := _label(title, 13, Palette.PARCHMENT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name)
	var content := _label(line, 11, line_color)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(content)
	return inner


## A pack in the shop: tap to buy and open it.
func _pack_view(index: int) -> Control:
	var box := VBoxContainer.new()
	box.set_meta("text_fixed", true)  # card-sized panel
	var pack: Dictionary = _run.packs[index]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UnitCard.CARD_SIZE
	var style := StyleBoxFlat.new()
	var back := Cosmetics.back_colors()  # the card back worn from the vault mirror
	style.bg_color = back["bg"] if not pack.is_empty() else Color(1, 1, 1, 0.03)
	style.border_color = back["border"] if not pack.is_empty() else Color(1, 1, 1, 0.15)
	style.set_border_width_all(0 if not pack.is_empty() else 2)
	style.set_corner_radius_all(10 if pack.is_empty() else 2)
	style.set_content_margin_all(0)
	if pack.get("size", "") == "mega":  # big packs: a thick edge around the back
		style.set_border_width_all(3)
		style.set_expand_margin_all(3)
	if pack.get("loot", false):  # reward for a hard band: golden glow
		style.border_color = Palette.GOLD
		style.set_border_width_all(3)
		style.set_expand_margin_all(3)
		style.shadow_color = Color(Palette.GOLD, 0.6)
		style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	var forge: bool = pack.get("type", "") == "equipment"
	if not pack.is_empty():  # the pixel card back: forge for equipment, else the region's ornament
		panel.add_child(CardBackArt.rect(Cosmetics.back, "forge" if forge else _run.region, UnitCard.CARD_SIZE))
	panel.custom_minimum_size = UnitCard.CARD_SIZE
	if not pack.is_empty() and _run.pack_cost(pack) > _run.gold:
		panel.modulate = Color(0.78, 0.78, 0.78)  # too expensive right now
	box.add_child(_with_price(panel, _run.pack_cost(pack) if not pack.is_empty() else -1, false))
	var price_text := ""
	if not pack.is_empty():
		panel.add_child(_pack_plate(ItemText.pack_name(pack),
			tr("UI_PACK_CONTENT") % [Items.pack_choice_count(_db, pack), Items.pack_picks(_db, pack)], Palette.MUTED,
			Color("f08a30") if forge else Palette.GOLD))
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				# Tap = info; buying is the button in the info window.
				var cost := _run.pack_cost(pack)
				_detail_panel.show_message(ItemText.pack_name(pack),
					tr("UI_PACK_CONTENT") % [Items.pack_choice_count(_db, pack), Items.pack_picks(_db, pack)])
				_detail_panel.show_action(tr("UI_BUY_OPEN") % cost, _on_buy_pack.bind(index), _run.gold >= cost))
	return box


func _on_buy_pack(index: int) -> void:
	if _run.buy_pack(index):
		_undo.clear()  # opening packs is final
		_pack_pick = -1
		_show_stage()


var _revealed_pack := ""  # the pack whose opening animation already played


## A freshly opened pack tears open and its cards are turned one by one,
## once; afterwards the normal pick screen lies underneath.
func _play_pack_opening(open: Dictionary) -> void:
	var key := JSON.stringify(open["items"])
	if key == _revealed_pack:
		return
	_revealed_pack = key
	var cards: Array = []
	for entry in open["items"]:
		var face: Control
		var rarity := 1
		var suit := _run.region  # the card back's ornament: the figure's suit, else the region's
		match entry["kind"]:
			"figure":
				var definition: Dictionary = _db.figures[entry["def_id"]]
				face = _scaled(UnitCard.for_definition(definition, 1, false), 1.15)
				rarity = 4 if definition["rank"] == "legend" else RunState.RANKS.find(definition["rank"])
				suit = String(definition.get("suit", _run.region))
			"equipment":
				face = ObjectCard.create(_db, entry, Vector2(150, 222))
				rarity = int(entry["item"]["rarity"])
				suit = "forge"
			"relic":
				face = ObjectCard.create(_db, entry, Vector2(150, 222))
				rarity = 2
			"pact":
				face = ObjectCard.create(_db, entry, Vector2(150, 222))
				rarity = 3
				suit = "soul"
			_:
				face = ObjectCard.create(_db, entry, Vector2(150, 222))
				rarity = 3 if entry.get("id", "") == "ritual_candle" else 1
		cards.append({"face": face, "rarity": rarity, "suit": suit})
	var pack_suit: String = {"soul": "soul", "equipment": "forge"}.get(open["pack"].get("type", ""), _run.region)
	add_child(PackOpening.create(cards, ItemText.pack_name(open["pack"]), open["pack"].get("loot", false), pack_suit))


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
		tr("UI_OPEN_PACK") % [open["picks_left"], open["items"].size()]], 26, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# The cards fill the screen; equipment goes into the stash, so the own row
	# only shows up when a figure (ace, legend) waits for its place.
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 28)
	for i in open["items"].size():
		items.add_child(_pack_item_box(i))
	var items_fit := _fitted(items, 2.2)
	items_fit.size_flags_stretch_ratio = 2.0
	column.add_child(items_fit)

	var skip := _button(tr("UI_PACK_SKIP"), Vector2(260, 60), _on_close_pack)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _pack_pick < 0:
		column.add_child(skip)
		var bottom_gap := Control.new()
		bottom_gap.custom_minimum_size = Vector2(0, 16)
		column.add_child(bottom_gap)
		_play_pack_opening(open)
		return
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
	column.add_child(skip)
	_play_pack_opening(open)


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
		_make_draggable(visual, {"kind": "pack", "index": i}, entry.get("def_id", "") if entry["kind"] == "figure" else "")
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
	elif entry["kind"] == "equipment" and _run.stash.size() >= RunState.MAX_STASH:
		text = tr("UI_STASH_FULL")
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
		_detail_panel.show_message(ItemText.equipment_name(entry["item"]), tr("UI_OBJECT_LIMIT"))
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


## Lets a control be dragged onto row slots (pack items, market figures,
## rewards). Figure cards stop the mouse on their own face, so they let
## presses fall through to the draggable holder (taps still open the info).
## The preview is the card itself (figures) or the pack emblem.
func _make_draggable(control: Control, data: Dictionary, def_id: String = "") -> void:
	# Everything inside lets presses through to the holder, which starts the drag.
	for child in control.find_children("*", "Control", true, false):
		if child.mouse_filter == Control.MOUSE_FILTER_STOP:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.set_drag_forwarding(func(_at: Vector2) -> Variant:
		var holder := Control.new()
		if def_id != "":
			var preview := UnitCard.for_definition(_db.figures[def_id], 1, false)
			preview.modulate = Color(1, 1, 1, 0.85)
			preview.position = -UnitCard.CARD_SIZE / 2
			holder.add_child(preview)
		else:
			var emblem := Emblem.create("pack", 60)
			emblem.position = -Vector2(30, 30)
			holder.add_child(emblem)
		control.set_drag_preview(holder)
		return data, Callable(), Callable())


## Tarot cards and relics are dragged (onto a figure / the sell field); the
## card itself follows the finger as preview.
func _make_object_draggable(card: ObjectCard, data: Dictionary) -> void:
	card.set_drag_forwarding(func(_at: Vector2) -> Variant:
		var holder := Control.new()
		var preview := ObjectCard.create(_db, card.entry, Vector2(60, 60), true)
		preview.modulate = Color(1, 1, 1, 0.85)
		preview.position = -Vector2(30, 30)
		holder.add_child(preview)
		card.set_drag_preview(holder)
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
	"fusion_altar": [["fuse", 0], ["leave", 0]],
	"blood_moon": [["blood_fuse", 0], ["leave", 0]],
	# Negative events: no free way out, every option costs something.
	"tax_raid": [["pay_tax", 0], ["fight_tax", 0]],
	"plague": [["plague_gold", 0], ["plague_soul", 0], ["plague_accept", 0]],
	"ambush": [["fight_ambush", 0], ["flee", 0]],
	"curse_fog": [["fog_gold", 0], ["fog_tarot", 0], ["fog_accept", 0]],
}
## Events whose scene shows the enemy band and whose fight option starts a battle.
const FIGHT_EVENTS := {"duel": "fight", "tax_raid": "fight_tax", "ambush": "fight_ambush"}

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
	# Same frame as the shop: menu and items left, resources right, the event
	# in the middle, your team below.
	var column := _column()
	var upper := HBoxContainer.new()
	upper.add_theme_constant_override("separation", 16)
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 2.2
	upper.add_child(_with_margin(_side_column_left(), 12, 8))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	var name_label := _label(tr("EVENT_" + id.to_upper()), 30, Palette.DANGER if _run.is_negative_event() else Palette.MYSTIC)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(name_label)
	var desc := _label(tr("EVENT_" + id.to_upper() + "_DESC"), 18, Palette.MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	center.add_child(desc)
	upper.add_child(center)
	upper.add_child(_with_margin(_side_column_right(), 12, 8))
	column.add_child(upper)

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
		var scene := _market_coat() if id == "black_market" else _event_scene(id)
		options.add_child(scene)
		_hint_targets["danger" if _run.is_negative_event() else "event"] = scene
		var exit_option := "decline" if id == "duel" else ("small" if id == "grave_robber" else "leave")
		if id != "grave_robber" and not _run.is_negative_event():
			options.add_child(_centered(_button(tr("OPT_" + exit_option.to_upper()), Vector2(400, 56), _on_event_option.bind(exit_option, 0))))
	var scene_holder := _fitted(options, 1.0)
	center.add_child(scene_holder)

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
	# Bottom: your team on a stage.
	var stage := _elegant_panel(0.55)
	stage.add_child(_own_row_slots())
	var team_fit := _fitted(_centered(stage), 1.3)
	column.add_child(team_fit)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	for slot in _row_slots:
		if slot.index in _event_targets:
			slot.set_selected(true)
	# The sell field only appears while one of your figures is dragged.
	_sell_zone = SellZone.new()
	_sell_zone.custom_minimum_size = Vector2(300, 110)
	_sell_zone.set_auto_hide(true)
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	_screen.add_child(_sell_zone)
	_sell_zone.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_sell_zone.position += Vector2(-24, 70)


## Look of each event scene: panel colors and the big emblem on the left.
const EVENT_SCENES := {
	"altar": {"bg": Color(0.12, 0.05, 0.05), "border": Color(0.6, 0.15, 0.15), "emblem": "skull"},
	"cursed_well": {"bg": Color(0.08, 0.05, 0.12), "border": Color(0.55, 0.3, 0.75), "emblem": "curse"},
	"fortune_teller": {"bg": Color(0.09, 0.06, 0.14), "border": Color(0.75, 0.6, 0.95), "emblem": "tarot"},
	"grave_robber": {"bg": Color(0.09, 0.08, 0.06), "border": Color(0.5, 0.45, 0.35), "emblem": "skull"},
	"mirror": {"bg": Color(0.06, 0.09, 0.13), "border": Color(0.65, 0.78, 0.95), "emblem": "star"},
	"duel": {"bg": Color(0.1, 0.08, 0.08), "border": Color(0.8, 0.8, 0.85), "emblem": "sword"},
	"soul_trader": {"bg": Color(0.05, 0.08, 0.12), "border": Color(0.5, 0.8, 1.0), "emblem": "soul"},
	"fusion_altar": {"bg": Color(0.1, 0.05, 0.12), "border": Color(0.95, 0.75, 0.35), "emblem": "star"},
	"blood_moon": {"bg": Color(0.16, 0.02, 0.04), "border": Color(0.95, 0.15, 0.2), "emblem": "bleed"},
	"tax_raid": {"bg": Color(0.12, 0.09, 0.03), "border": Color(0.85, 0.6, 0.2), "emblem": "coin"},
	"plague": {"bg": Color(0.06, 0.1, 0.05), "border": Color(0.55, 0.75, 0.3), "emblem": "skull"},
	"ambush": {"bg": Color(0.12, 0.04, 0.04), "border": Color(0.85, 0.3, 0.25), "emblem": "sword"},
	"curse_fog": {"bg": Color(0.07, 0.04, 0.1), "border": Color(0.6, 0.4, 0.85), "emblem": "curse"},
}
## Emblem shown on each offer.
const OFFER_EMBLEMS := {
	"sacrifice_one": "soul", "sacrifice_two": "pact", "throw_3": "pack", "throw_6": "pack",
	"throw_10": "pack", "drink": "curse", "tarot": "tarot", "no_boss_rule": "enemy",
	"mega_arcana": "pack", "rob": "relic", "small": "coin", "duplicate": "star", "train": "level",
	"fight": "sword", "soul_to_gold": "coin", "gold_to_soul": "soul", "return_pact": "pact",
	"fuse": "star", "blood_fuse": "bleed",
	"pay_tax": "coin", "fight_tax": "sword", "plague_gold": "coin", "plague_soul": "soul", "plague_accept": "skull",
	"fight_ambush": "sword", "flee": "skull", "fog_gold": "coin", "fog_tarot": "tarot", "fog_accept": "curse",
}


## An event as its own scene: a themed panel with a big emblem and one
## compartment per offer (emblem, name, description, cost, choose button).
func _event_scene(id: String) -> Control:
	var look: Dictionary = EVENT_SCENES.get(id, EVENT_SCENES["altar"])
	var panel := _scene_panel(look["bg"], look["border"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# Left: the scene's emblem (for fights: the enemy band).
	if FIGHT_EVENTS.has(id):
		var champion := VBoxContainer.new()
		champion.alignment = BoxContainer.ALIGNMENT_CENTER
		var heading := _label(tr("UI_CHAMPION") if id == "duel" else tr("UI_ENEMY_BAND"), 20, look["border"])
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
		var emblem := Emblem.create(look["emblem"], 90)
		emblem.color = look["border"]
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(110, 0)
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
		"fuse":
			return tr("COST_ALTAR")
		"pay_tax":
			return tr("COST_GOLD") % int(_run.event.get("tax", 0))
		"fight_tax", "fight_ambush":
			return tr("COST_RISK")
		"plague_gold":
			return tr("COST_GOLD") % RunState.PLAGUE_GOLD
		"plague_soul":
			return tr("COST_SOUL")
		"plague_accept":
			return tr("COST_PLAGUE")
		"fog_gold":
			return tr("COST_GOLD") % RunState.FOG_GOLD
		"fog_tarot":
			return tr("COST_TAROT")
		"fog_accept":
			return tr("COST_FOG")
		"flee":
			return tr("COST_REAR_FIGURE")
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
	var pack_suit: String = {"soul": "soul", "equipment": "forge"}.get(pack["type"], _run.region)
	emblem_center.add_child(CardBackArt.rect(Cosmetics.back, pack_suit, UnitCard.CARD_SIZE))
	pack_box.add_child(emblem_center)
	var pack_name := _label(ItemText.pack_name(pack), 17, Palette.PARCHMENT)
	pack_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	pack_box.add_child(pack_name)
	var pack_info := _label(tr("UI_PACK_CONTENT") % [Items.pack_choice_count(_db, pack), Items.pack_picks(_db, pack)], 14, Palette.MUTED)
	pack_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_box.add_child(pack_info)
	compartments.add_child(_compartment(tr("UI_MARKET_PACKS"), pack_box, tr("UI_PRICE") % 6, "buy_pack"))
	# Ritual candle (sometimes): one free fusion.
	if event.get("candle", false):
		var candle := ObjectCard.create(_db, {"kind": "tarot", "id": "ritual_candle"}, Vector2(170, 210))
		candle.tapped.connect(_detail_panel.show_object)
		compartments.add_child(_compartment(tr("UI_MARKET_CANDLE"), candle, tr("UI_PRICE") % int(_db.fusion["market_candle_price"]), "buy_candle"))
	# Figure (half price): drag onto a free slot or buy + tap a slot.
	var def_id: String = event["figure"]
	var figure_card := UnitCard.for_definition(_db.figures[def_id], 1, false)
	figure_card.tapped.connect(_detail_panel.show_card)
	var figure_visual := _scaled(_with_rarity(figure_card, def_id), 1.3)
	if not "buy_figure" in event["used"]:
		_make_draggable(figure_visual, {"kind": "market_figure"}, def_id)
	# Room above the card for the rarity label ("Rare!").
	compartments.add_child(_compartment(tr("UI_MARKET_FIGURES"), _with_margin(figure_visual, 0, 30), tr("UI_PRICE") % (_run.price_of(def_id) / 2), "buy_figure"))
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
	var market := option in ["buy_relic", "buy_pack", "buy_figure", "buy_candle"]
	if not market:
		panel.custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := _label(title, 23, Palette.GOLD)
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
		text.custom_minimum_size = Vector2(300, 0)
		text.add_theme_font_size_override("normal_font_size", 19)
		text.add_theme_color_override("default_color", Palette.PARCHMENT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.text = "[center]" + Keywords.colorize(desc) + "[/center]"
		box.add_child(text)
	var sold: bool = option in _run.event["used"]
	if sold:
		visual.modulate.a = 0.3
	var price_label := _label(tr("UI_SOLD") if sold else cost_text, 21, Palette.GOLD)
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
	if option in FIGHT_EVENTS.values():
		_play_duel()
		return
	if needed > 0 or option == "return_pact":
		_event_option = option
		_event_targets.clear()
		_show_stage()
		return
	var relics_before := _run.relics.size()
	if _run.resolve_event(option):
		_event_option = ""
		_undo.clear()
		_show_stage()
		if option in ["rob", "buy_relic"] and _run.relics.size() > relics_before:
			_reveal_relic.call_deferred(_run.relics[-1])


## A new relic from an event: the chest animation, ending in the relic row.
func _reveal_relic(relic_id: String) -> void:
	await get_tree().process_frame  # the rebuilt screen needs its layout
	var target := get_viewport_rect().size / 2
	for card in _strip_cards:
		if is_instance_valid(card) and card.entry.get("kind", "") == "relic" and card.entry.get("id", "") == relic_id:
			target = card.get_global_rect().get_center()
	RelicReveal.play(self, _db, relic_id, target)


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
	if is_instance_valid(_debug_panel):
		_debug_panel.queue_free()  # the debug column must not cover the battle
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
	column.add_theme_constant_override("separation", 6)
	# A big, centred "Victory!" - no resource bar on this screen.
	var title := _label(tr("UI_VICTORY"), 60, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.75, 0.2, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 14)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02))
	title.set_meta("text_fixed", true)
	column.add_child(title)

	# Middle: the reward ledger on the left, the rewards to drag in the middle.
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 48)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 36)
	_hint_targets["reward"] = choices
	for i in _run.rewards.size():
		var def_id: String = _run.rewards[i]
		var card := UnitCard.for_definition(_db.figures[def_id], 1, false)
		card.tapped.connect(_detail_panel.show_card)
		var holder := Control.new()
		holder.custom_minimum_size = UnitCard.CARD_SIZE + Vector2(0, 30)
		var reward_visual := _with_rarity(card, def_id)
		holder.add_child(reward_visual)
		var target := _run.reward_target(def_id)
		if target >= 0 and _run.row[target] != null:
			var badge := _merge_badge()
			badge.position.y = UnitCard.CARD_SIZE.y + 2
			holder.add_child(badge)
		elif target < 0:
			card.modulate = Color(1, 1, 1, 0.5)  # no room: sell a figure first
		# Taking a reward = dragging it onto a place in the team.
		_make_draggable(reward_visual, {"kind": "reward", "index": i}, def_id)
		choices.add_child(holder)
	middle.add_child(choices)
	column.add_child(_fitted(middle, 1.5))
	# The ledger floats at the left edge, so the three rewards stay exactly centred.
	var ledger := _scaled(_reward_ledger(), 1.35)
	_screen.add_child(ledger)
	ledger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	ledger.position.y -= 60

	# Bottom: your team (drop target), the skip button at the right.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 40)
	var arrow := _label(tr("UI_DRAG_INTO_TEAM"), 18, Palette.MUTED)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(arrow)
	var stage := _elegant_panel(0.55)
	stage.add_child(_own_row_slots())
	bottom.add_child(stage)
	var skip := _button(tr("UI_SKIP_REWARD") % RunState.REWARD_SKIP_GOLD, Vector2(220, 64), _on_skip_reward)
	skip.add_theme_font_size_override("font_size", 18)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(skip)
	column.add_child(_fitted(bottom, 1.2))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	# The sell field only appears while one of your figures is dragged.
	_sell_zone = SellZone.new()
	_sell_zone.custom_minimum_size = Vector2(300, 110)
	_sell_zone.set_auto_hide(true)
	_sell_zone.tapped.connect(_on_sell_zone_tapped)
	_sell_zone.dropped.connect(func(data: Dictionary) -> void: _request_sell(data["index"]))
	_screen.add_child(_sell_zone)
	_sell_zone.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_sell_zone.position += Vector2(-24, 24)


## What the battle paid, as a small ledger: one line per income with its
## symbol and amount, then the total.
func _reward_ledger() -> Control:
	var income := _run.last_income
	var panel := _elegant_panel(0.75)
	panel.custom_minimum_size = Vector2(220, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	var gold := 0
	for entry in [["UI_LEDGER_WIN", int(income.get("base", 0))], ["UI_LEDGER_BONUS", int(income.get("bonus", 0))],
			["UI_LEDGER_INTEREST", int(income.get("interest", 0))], ["UI_LEDGER_EXTRA", int(income.get("extra", 0))]]:
		if int(entry[1]) == 0:
			continue
		gold += int(entry[1])
		_ledger_line(grid, "coin", Palette.GOLD, tr(entry[0]), "%+d" % int(entry[1]))
	if int(income.get("souls", 0)) > 0:
		_ledger_line(grid, "soul", Emblem.COLORS["soul"], tr("UI_BOX_SOULS"), "+%d" % int(income["souls"]))
	if income.get("slot", false):
		_ledger_line(grid, "level", Palette.PARCHMENT, tr("UI_LEDGER_SLOT"), "+1")
	if income.get("loot", false):
		_ledger_line(grid, "pack", Emblem.COLORS["pack"], tr("UI_LEDGER_LOOT"), "")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.add_child(grid)
	column.add_child(HSeparator.new())
	var total := HBoxContainer.new()
	total.add_child(_label(tr("UI_LEDGER_TOTAL"), 18, Palette.PARCHMENT))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(fill)
	total.add_child(_label("%+d Gold" % gold, 22, Palette.GOLD))
	column.add_child(total)
	panel.add_child(column)
	return panel


func _ledger_line(grid: GridContainer, kind: String, color: Color, text: String, value: String) -> void:
	var emblem := Emblem.create(kind, 24)
	emblem.color = color
	grid.add_child(emblem)
	var label := _label(text, 16, Palette.PARCHMENT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var amount := _label(value, 18, color)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(amount)


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
	Sound.play("level_up" if levelled else "card_place")
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
	own.add_child(_scaled(_own_team_row(), 0.8))
	column.add_child(own)
	# What the run leaves behind: Seelenglut and newly won occultists.
	if not _run_summary.is_empty():
		var glut_text := tr("UI_RUN_GLUT") % [_run.souls, int(_run_summary["glut"]), _meta.glut]
		for id in _run_summary.get("occultists", []):
			glut_text += "\n" + tr("UI_RUN_NEW_OCCULTIST") % tr("OCC_" + String(id).to_upper())
		column.add_child(_rich_line(glut_text, 24))
	var again := _button(tr("UI_TO_MENU"), Vector2(280, 72), _show_menu)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(again)


func _stage_name_at_end(won: bool) -> String:
	return tr("UI_FIGHT_BOSS") if won else tr(STAGE_NAMES[_run.fight])


## Active suit bonuses of the row, e.g. "Münzen: Zins-Grenze +2 · Stäbe: 3 Brennen".
func _suit_bonus_text(extra_suit: String = "") -> String:
	var parts: Array = []
	for suit in ["coins", "cups", "swords", "wands"]:
		var count := _run.suit_count(suit) + (1 if suit == extra_suit else 0)
		var amount := 0
		match suit:
			"coins": amount = count if _run.interest_cap() > 0 else 0
			"cups": amount = count * TeamBuilder.SUIT_CUP_HEALTH
			"swords": amount = count / TeamBuilder.SUIT_SWORDS_PER_BLEED
			"wands": amount = count
		if amount > 0:
			parts.append("[color=#%s]%s[/color]" % [Emblem.COLORS["suit_" + suit].to_html(false),
				tr("SUITB_SHORT_" + suit.to_upper()) % amount])
	if parts.is_empty():
		return ""
	return tr("UI_SUIT_BONUS_LINE") % " · ".join(parts)


func _footer_text() -> String:
	return "  v%s · %s" % [ProjectSettings.get_setting("application/config/version"), tr("UI_SEED") % _run.rng.master_seed]
