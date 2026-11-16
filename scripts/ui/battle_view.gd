extends Control
## M1 battle screen: shows two random placeholder teams and replays the
## simulator's event list turn by turn (1x / 2x / 4x speed).

const SPEEDS := [1.0, 2.0, 4.0]
const ROW_GAP := 56
const CARD_SPACING := 6

var _db: ContentDb
var _rng_streams: RngStreams
var _speed := 1.0
var _cards: Dictionary = {}  # uid -> UnitCard
var _battle: Dictionary = {}
var _playback_token := 0  # increments to cancel an older playback

var _player_row: HBoxContainer
var _enemy_row: HBoxContainer
var _turn_label: Label
var _seed_label: Label
var _banner: Label
var _start_button: Button
var _new_button: Button
var _speed_buttons: Array[Button] = []
var _fx_layer: Control


func _ready() -> void:
	TranslationServer.set_locale("de")
	_db = ContentDb.load_default()
	_build_layout()
	_new_battle()


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

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", ROW_GAP)
	root.add_child(field)

	_player_row = _make_row(BoxContainer.ALIGNMENT_END)
	field.add_child(_wrap_row(_player_row, tr("UI_YOUR_TEAM")))
	_enemy_row = _make_row(BoxContainer.ALIGNMENT_BEGIN)
	field.add_child(_wrap_row(_enemy_row, tr("UI_ENEMIES")))

	root.add_child(_build_bottom_bar())

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 72)
	bar.add_theme_constant_override("separation", 12)

	var margin := Control.new()
	margin.custom_minimum_size = Vector2(16, 0)
	bar.add_child(margin)

	_turn_label = _make_label("", 28, Palette.GOLD)
	_turn_label.custom_minimum_size = Vector2(160, 0)
	bar.add_child(_turn_label)

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
	_seed_label.custom_minimum_size = Vector2(200, 0)
	bar.add_child(_seed_label)

	_start_button = _make_button(tr("UI_START_BATTLE"), Vector2(260, 72))
	_start_button.pressed.connect(_start_battle)
	bar.add_child(_start_button)

	_new_button = _make_button(tr("UI_NEW_BATTLE"), Vector2(260, 72))
	_new_button.pressed.connect(_new_battle)
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

func _new_battle() -> void:
	_playback_token += 1
	var seed_value := randi()
	_rng_streams = RngStreams.new(seed_value)
	var rng := _rng_streams.stream("debug_teams")
	var player_team := DebugTeams.random_player_team(_db, rng, rng.randi_range(3, 6))
	var enemy_team := DebugTeams.random_enemy_team(_db, rng, rng.randi_range(3, 6))
	_battle = BattleSimulator.simulate(player_team, enemy_team)

	_seed_label.text = tr("UI_SEED") % seed_value
	_turn_label.text = ""
	_banner.text = ""
	_banner.add_theme_color_override("font_color", Palette.PARCHMENT)
	_start_button.disabled = false
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


func _make_card(snapshot: Dictionary, is_enemy: bool) -> UnitCard:
	var definition: Dictionary = _db.enemies[snapshot["def_id"]] if is_enemy else _db.figures[snapshot["def_id"]]
	var card := UnitCard.new()
	card.setup(snapshot, definition, is_enemy)
	_cards[card.uid] = card
	return card


func _set_speed(speed: float) -> void:
	_speed = speed
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == speed)


# --- Playback -----------------------------------------------------------------

func _start_battle() -> void:
	_start_button.disabled = true
	_playback_token += 1
	_play_events(_playback_token)


func _play_events(token: int) -> void:
	var events: Array = _battle["events"]
	var i := 1  # event 0 is the start state, already shown
	while i < events.size():
		if token != _playback_token:
			return
		var event: Dictionary = events[i]
		match event["type"]:
			"turn":
				_turn_label.text = tr("UI_TURN") % event["turn"]
				_banner.text = ""
			"clash":
				await _animate_clash(event)
			"damage":
				_show_damage(event)
				if i + 1 >= events.size() or events[i + 1]["type"] != "damage":
					await _wait(0.25)
			"decay":
				_banner.text = tr("UI_DECAY") % event["amount"]
			"death":
				await _animate_death(event)
			"end":
				_show_result(event)
		if event["type"] == "turn" and i > 1:
			await _wait(0.35)  # breathing room so one turn takes ~1 s at 1x
		i += 1


func _animate_clash(event: Dictionary) -> void:
	var player_card: UnitCard = _cards[event["player_uid"]]
	var enemy_card: UnitCard = _cards[event["enemy_uid"]]
	var lunge := 22.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player_card.body, "position:x", lunge, 0.15 / _speed)
	tween.tween_property(enemy_card.body, "position:x", -lunge, 0.15 / _speed)
	tween.chain().tween_property(player_card.body, "position:x", 0.0, 0.15 / _speed)
	tween.parallel().tween_property(enemy_card.body, "position:x", 0.0, 0.15 / _speed)
	await _wait(0.15)


func _show_damage(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	card.set_stats(card.attack, event["health_after"])
	card.body.modulate = Palette.DAMAGE_FLASH
	create_tween().tween_property(card.body, "modulate", Color.WHITE, 0.3 / _speed)
	_float_number("-%d" % event["amount"], card.center_position(), Palette.DAMAGE_FLASH)


func _animate_death(event: Dictionary) -> void:
	var card: UnitCard = _cards.get(event["uid"])
	if card == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card.body, "modulate:a", 0.0, 0.25 / _speed)
	tween.tween_property(card.body, "scale", Vector2(0.6, 0.6), 0.25 / _speed)
	await _wait(0.25)
	_cards.erase(event["uid"])
	card.queue_free()


func _float_number(text: String, at: Vector2, color: Color) -> void:
	var label := _make_label(text, 30, color)
	label.position = at - Vector2(20, 40)
	_fx_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.6 / _speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.6 / _speed)
	tween.chain().tween_callback(label.queue_free)


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
