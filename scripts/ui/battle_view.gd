extends Control
## Battle screen: replays the simulator's event list turn by turn
## (1x / 2x / 4x speed).
##
## Sandbox mode (scenes/battle.tscn on its own): random teams, "new battle".
## Run mode (embedded by the run screen): play_battle() starts a given fight,
## "continue" emits finished(result) when it is over.

signal finished(result: Dictionary)

const SPEEDS := [1.0, 2.0, 4.0]
const ROW_GAP := 56
const CARD_SPACING := 6

## Run mode sets this to false before adding the node to the tree.
var sandbox := true

var _db: ContentDb
var _rng_streams: RngStreams
var _speed := 1.0
var _cards: Dictionary = {}  # uid -> UnitCard
var _battle: Dictionary = {}
var _battle_gold := 0
var _url_seed_used := false
var _playback_token := 0  # increments to cancel an older playback

var _player_row: HBoxContainer
var _enemy_row: HBoxContainer
var _turn_label: Label
var _gold_label: Label
var _detail_panel: DetailPanel
var _seed_label: Label
var _banner: Label
var _start_button: Button
var _new_button: Button
var _speed_buttons: Array[Button] = []
var _fx_layer: Control
var _field: HBoxContainer
var _field_holder: Control


func _ready() -> void:
	TranslationServer.set_locale("de")
	theme = UiTheme.build()
	_db = ContentDb.load_default()
	_build_layout()
	if sandbox:
		_new_battle()
	_fit_field.call_deferred()


## Run mode: shows the given fight and starts it right away.
func play_battle(player_team: Array, enemy_team: Array, gold: int, info: String,
		options: Dictionary = {}, rule_text: String = "", boss_name: String = "") -> void:
	_playback_token += 1
	_battle_gold = gold
	_battle = BattleSimulator.simulate(player_team, enemy_team, gold, options)
	_seed_label.text = info
	_set_gold(gold)
	_turn_label.text = ""
	_banner.text = ""
	_start_button.hide()
	_new_button.text = tr("UI_CONTINUE")
	_new_button.hide()
	_show_start_state(_battle["events"][0])
	_banner.text = rule_text
	if boss_name != "":
		await _announce_boss(boss_name, rule_text)
	else:
		await get_tree().create_timer(0.6).timeout
	_start_battle()


## Full-width stripe with the boss name and rule, before the first turn.
func _announce_boss(boss_name: String, rule_text: String) -> void:
	var stripe := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.04, 0.07, 0.94)
	style.border_color = Palette.GOLD
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	stripe.add_theme_stylebox_override("panel", style)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)
	stripe.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	stripe.add_child(column)
	for line in [[tr("UI_BOSS_APPEARS"), 26, Palette.PARCHMENT], [boss_name, 64, Palette.GOLD], [rule_text, 24, Palette.PARCHMENT]]:
		var label := _make_label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 8)
		column.add_child(label)
	await get_tree().process_frame
	var height := stripe.size.y
	stripe.position = Vector2(-size.x, (size.y - height) / 2)
	stripe.size.x = size.x
	var tween := create_tween()
	tween.tween_property(stripe, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(stripe, "position:x", size.x, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(stripe.queue_free)
	await tween.finished


## On wide screens (most phones in landscape) the battle field is scaled up so
## cards use the extra width; never shrinks below the 1280×720 design size.
func _fit_field() -> void:
	if _field == null:
		return
	_field.size = _field.get_combined_minimum_size()
	var needed := _field.size.x + 40
	var factor := clampf(_field_holder.size.x / needed, 1.0, 1.3)
	factor = minf(factor, _field_holder.size.y / maxf(_field.size.y, 1.0))
	_field.scale = Vector2(factor, factor)
	_field.position = (_field_holder.size - _field.size * factor) / 2


# --- Layout -----------------------------------------------------------------

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(_build_top_bar())

	# Containers reset the scale of their children, so the field sits in a plain
	# Control and is positioned and scaled by _fit_field().
	_field_holder = Control.new()
	_field_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_holder.resized.connect(_fit_field)
	root.add_child(_field_holder)
	var field := HBoxContainer.new()
	_field = field
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", ROW_GAP)
	_field_holder.add_child(field)

	_player_row = _make_row(BoxContainer.ALIGNMENT_END)
	field.add_child(_wrap_row(_player_row, tr("UI_YOUR_TEAM")))
	_enemy_row = _make_row(BoxContainer.ALIGNMENT_BEGIN)
	field.add_child(_wrap_row(_enemy_row, tr("UI_ENEMIES")))

	root.add_child(_build_bottom_bar())

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_detail_panel = DetailPanel.new()
	_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_detail_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_detail_panel.position.y -= 110
	add_child(_detail_panel)


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 72)
	bar.add_theme_constant_override("separation", 12)

	var margin := Control.new()
	margin.custom_minimum_size = Vector2(16, 0)
	bar.add_child(margin)

	_turn_label = _make_label("", 28, Palette.GOLD)
	_turn_label.custom_minimum_size = Vector2(140, 0)
	bar.add_child(_turn_label)

	_gold_label = _make_label("", 24, Palette.GOLD)
	_gold_label.custom_minimum_size = Vector2(140, 0)
	bar.add_child(_gold_label)

	_banner = _make_label("", 30, Palette.PARCHMENT)
	_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_banner)

	for speed in SPEEDS:
		var button := _make_button("%d×" % int(speed), Vector2(72, 56))
		button.toggle_mode = true
		button.pressed.connect(_set_speed.bind(speed))
		_speed_buttons.append(button)
		bar.add_child(button)
	_set_speed(1.0)

	var margin_right := Control.new()
	margin_right.custom_minimum_size = Vector2(16, 0)
	bar.add_child(margin_right)
	return bar


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 96)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)

	_seed_label = _make_label("", 18, Palette.MUTED)
	_seed_label.custom_minimum_size = Vector2(240, 0)
	bar.add_child(_seed_label)

	_start_button = _make_button(tr("UI_START_BATTLE"), Vector2(260, 72))
	_start_button.pressed.connect(_start_battle)
	bar.add_child(_start_button)

	_new_button = _make_button(tr("UI_NEW_BATTLE"), Vector2(260, 72))
	_new_button.pressed.connect(_on_new_button)
	bar.add_child(_new_button)

	var balance := Control.new()
	balance.custom_minimum_size = Vector2(200, 0)
	bar.add_child(balance)
	return bar


func _make_row(alignment: BoxContainer.AlignmentMode) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = alignment
	row.add_theme_constant_override("separation", CARD_SPACING)
	row.custom_minimum_size = Vector2(6 * (UnitCard.CARD_SIZE.x + CARD_SPACING), UnitCard.CARD_SIZE.y)
	return row


func _wrap_row(row: HBoxContainer, title: String) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	var label := _make_label(title, 20, Palette.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	column.add_child(row)
	return column


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 24)
	return button


# --- Battle setup -------------------------------------------------------------

func _on_new_button() -> void:
	if sandbox:
		_new_battle()
	else:
		finished.emit(_battle)


func _new_battle() -> void:
	_playback_token += 1
	var seed_value := _take_url_seed()
	if seed_value < 0:
		seed_value = randi()
	_rng_streams = RngStreams.new(seed_value)
	var rng := _rng_streams.stream("debug_teams")
	var player_team := DebugTeams.random_player_team(_db, rng, rng.randi_range(3, 6))
	var enemy_team := DebugTeams.random_enemy_team(_db, rng, rng.randi_range(3, 6))
	_battle_gold = rng.randi_range(0, 30)
	_battle = BattleSimulator.simulate(player_team, enemy_team, _battle_gold)

	_seed_label.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version"), tr("UI_SEED") % seed_value]
	_set_gold(_battle_gold)
	_turn_label.text = ""
	_banner.text = ""
	_banner.add_theme_color_override("font_color", Palette.PARCHMENT)
	_start_button.disabled = false
	_detail_panel.hide()
	_show_start_state(_battle["events"][0])


func _show_start_state(start_event: Dictionary) -> void:
	for row in [_player_row, _enemy_row]:
		for child in row.get_children():
			child.queue_free()
	_cards.clear()
	# Player row is drawn back-to-front so the front unit sits next to the middle.
	var player_units: Array = start_event["player"].duplicate()
	player_units.reverse()
	for snapshot in player_units:
		_player_row.add_child(_make_card(snapshot, false))
	for snapshot in start_event["enemy"]:
		_enemy_row.add_child(_make_card(snapshot, true))
	# Rule bosses can field more than 6 card widths (boss figures are 2-3 wide).
	var enemy_slots := 0
	for snapshot in start_event["enemy"]:
		enemy_slots += int(_db.enemies[snapshot["def_id"]].get("width", 1))
	enemy_slots = maxi(6, enemy_slots)
	_enemy_row.custom_minimum_size.x = enemy_slots * (UnitCard.CARD_SIZE.x + CARD_SPACING)
	_fit_field.call_deferred()


## Web only: "?seed=123" in the address replays that battle (for bug reports).
## Used once, for the first battle after loading.
func _take_url_seed() -> int:
	if _url_seed_used or not OS.has_feature("web"):
		return -1
	_url_seed_used = true
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	var match := RegEx.create_from_string("seed=(\\d+)").search(query)
	return int(match.get_string(1)) if match != null else -1


func _make_card(snapshot: Dictionary, is_enemy: bool) -> UnitCard:
	var definition: Dictionary = _db.enemies[snapshot["def_id"]] if is_enemy else _db.figures[snapshot["def_id"]]
	var card := UnitCard.new()
	card.setup(snapshot, definition, is_enemy)
	card.tapped.connect(_detail_panel.show_card)
	_cards[card.uid] = card
	return card


func _set_speed(speed: float) -> void:
	_speed = speed
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == speed)


# --- Playback -----------------------------------------------------------------

func _start_battle() -> void:
	_start_button.disabled = true
	_detail_panel.hide()
	_playback_token += 1
	_play_events(_playback_token)


func _play_events(token: int) -> void:
	var events: Array = _battle["events"]
	var i := 1  # event 0 is the start state, already shown
	while i < events.size():
		if token != _playback_token:
			return
		var event: Dictionary = events[i]
		var next_type: String = events[i + 1]["type"] if i + 1 < events.size() else ""
		match event["type"]:
			"turn":
				if i > 1:
					await _wait(0.3)  # breathing room between turns
				_turn_label.text = tr("UI_TURN") % event["turn"]
				_banner.text = ""
			"blessing":
				await _show_trigger({"uid": event["uid"], "effect": "gain_shield", "targets": [event["uid"]]})
			"trigger":
				await _show_trigger(event)
			"update":
				var card: UnitCard = _cards.get(event["unit"]["uid"])
				if card != null:
					card.apply_snapshot(event["unit"])
			"clash":
				await _animate_clash(event)
			"shielded":
				_float_on(event["uid"], "-%d %s" % [event["amount"], tr("STATUS_SHIELD")], Emblem.COLORS["shield"])
			"damage":
				_show_damage(event)
				if next_type not in ["damage", "update", "shielded"]:
					await _wait(0.25)
			"heal":
				_float_on(event["uid"], "+%d" % event["amount"], Palette.SUIT_COLORS["coins"])
			"gold":
				_set_gold(event["gold"])
				_float_number("%+d Gold" % event["delta"], _gold_label.global_position + Vector2(40, 30), Palette.GOLD)
			"decay":
				_banner.text = tr("UI_DECAY") % event["amount"]
			"dying":
				await _animate_dying(event)
			"revive":
				await _animate_revive(event)
			"removed":
				await _animate_removed(event)
			"end":
				_show_result(event)
				if not sandbox:
					_new_button.show()
		i += 1


func _show_trigger(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	var kind := Emblem.kind_for_effect(event["effect"])
	var color: Color = Emblem.COLORS.get(kind, Palette.GOLD)
	card.flash_trigger(0.4 / _speed)
	var other_targets: Array = event["targets"].filter(func(uid: int) -> bool: return uid != event["uid"])
	if other_targets.is_empty():
		# Ability on itself: halo pulse plus the emblem rising out of the card.
		card.pulse_glow(color, 0.45 / _speed)
		_rise_emblem(kind, card.center_position())
		await _wait(0.35)
		return
	# Ability on others: the emblem flies from the source to every target.
	for uid in other_targets:
		var target: UnitCard = _cards.get(uid)
		if target != null:
			_fly_emblem(kind, card.center_position(), target)
	await _wait(0.4)


func _rise_emblem(kind: String, at: Vector2) -> void:
	var emblem := Emblem.create(kind, 44)
	emblem.position = at - emblem.size / 2
	emblem.scale = Vector2(0.4, 0.4)
	_fx_layer.add_child(emblem)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(emblem, "scale", Vector2(1.2, 1.2), 0.2 / _speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(emblem, "position:y", emblem.position.y - 46, 0.5 / _speed)
	tween.tween_property(emblem, "modulate:a", 0.0, 0.25 / _speed).set_delay(0.35 / _speed)
	tween.chain().tween_callback(emblem.queue_free)


## Emblem flies on an arc from a point to a target card, then bursts on it.
func _fly_emblem(kind: String, from: Vector2, target: UnitCard, flight := 0.3, arc := true) -> void:
	var emblem := Emblem.create(kind, 40)
	_fx_layer.add_child(emblem)
	var to := target.center_position()
	var lift := (-60.0 - absf(to.x - from.x) * 0.15) if arc else -12.0
	var place := func(t: float) -> void:
		var point := from.lerp(to, t) + Vector2(0, lift * 4.0 * t * (1.0 - t))
		emblem.position = point - emblem.size / 2
		emblem.rotation = (to - from).angle() * 0.2 * (1.0 - t)
	place.call(0.0)
	var tween := create_tween()
	tween.tween_method(place, 0.0, 1.0, flight / _speed).set_ease(Tween.EASE_IN_OUT)
	if kind != "sword":  # plain attacks already flash red on impact
		tween.tween_callback(func() -> void: target.pulse_glow(emblem.color, 0.3 / _speed))
	tween.tween_property(emblem, "scale", Vector2(1.6, 1.6), 0.12 / _speed)
	tween.parallel().tween_property(emblem, "modulate:a", 0.0, 0.12 / _speed)
	tween.tween_callback(emblem.queue_free)


func _animate_clash(event: Dictionary) -> void:
	var player_card: UnitCard = _cards[event["player_uid"]]
	var enemy_card: UnitCard = _cards[event["enemy_uid"]]
	var lunge := 22.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player_card.body, "position:x", lunge, 0.15 / _speed)
	tween.tween_property(enemy_card.body, "position:x", -lunge, 0.15 / _speed)
	tween.chain().tween_property(player_card.body, "position:x", 0.0, 0.15 / _speed)
	tween.parallel().tween_property(enemy_card.body, "position:x", 0.0, 0.15 / _speed)
	# Crossing swords show who strikes whom.
	_fly_emblem("sword", player_card.center_position(), enemy_card, 0.2, false)
	_fly_emblem("sword", enemy_card.center_position(), player_card, 0.2, false)
	await _wait(0.2)


func _show_damage(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	card.body.modulate = Palette.DAMAGE_FLASH
	create_tween().tween_property(card.body, "modulate", Color.WHITE, 0.3 / _speed)
	var color: Color = Palette.DAMAGE_FLASH
	if event["source"] in ["burn", "bleed"]:
		color = Emblem.COLORS[event["source"]]
	_float_number("-%d" % event["amount"], card.center_position(), color)


func _animate_dying(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	var tween := create_tween()
	for offset in [-6.0, 6.0, -4.0, 0.0]:
		tween.tween_property(card.body, "position:x", offset, 0.04 / _speed)
	await _wait(0.16)


func _animate_revive(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	card.body.modulate = Color(2, 2, 2)
	create_tween().tween_property(card.body, "modulate", Color.WHITE, 0.4 / _speed)
	_float_on(event["uid"], tr("UI_REVIVED"), Palette.PARCHMENT)
	await _wait(0.3)


func _animate_removed(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card.body, "modulate:a", 0.0, 0.25 / _speed)
	tween.tween_property(card.body, "scale", Vector2(0.6, 0.6), 0.25 / _speed)
	await _wait(0.25)
	_cards.erase(event["uid"])
	card.queue_free()


func _float_on(uid: int, text: String, color: Color) -> void:
	var card: UnitCard = _cards.get(uid)
	if card != null:
		_float_number(text, card.center_position() + Vector2(0, -24), color)


func _float_number(text: String, at: Vector2, color: Color) -> void:
	var label := _make_label(text, 26, color)
	label.position = at - Vector2(20, 40)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_fx_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.7 / _speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.7 / _speed).set_delay(0.2 / _speed)
	tween.chain().tween_callback(label.queue_free)


func _set_gold(value: int) -> void:
	_gold_label.text = tr("UI_GOLD") % value


func _show_result(event: Dictionary) -> void:
	match event["outcome"]:
		BattleSimulator.Outcome.WIN:
			_banner.text = tr("UI_VICTORY")
			_banner.add_theme_color_override("font_color", Palette.GOLD)
		BattleSimulator.Outcome.LOSS:
			_banner.text = tr("UI_DEFEAT")
			_banner.add_theme_color_override("font_color", Palette.HEALTH)
		BattleSimulator.Outcome.DRAW:
			_banner.text = tr("UI_DRAW")
			_banner.add_theme_color_override("font_color", Palette.PARCHMENT)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed).timeout
