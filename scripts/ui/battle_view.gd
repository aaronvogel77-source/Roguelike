extends Control
## Battle screen: replays the simulator's event list turn by turn
## (1x / 2x / 4x speed).
##
## Sandbox mode (scenes/battle.tscn on its own): random teams, "new battle".
## Run mode (embedded by the run screen): play_battle() starts a given fight,
## "continue" emits finished(result) when it is over.

signal finished(result: Dictionary)

const SPEEDS := [1.0, 2.0, 3.0]
## Chosen speed, kept between battles (and saved to the settings file).
static var saved_speed := 0.0
const SETTINGS_PATH := "user://settings.cfg"
const ROW_GAP := 56
const CARD_SPACING := 6

## Run mode sets this to false before adding the node to the tree.
var sandbox := true

var _db: ContentDb
var _rng_streams: RngStreams
var _speed := 1.0
var _stage: BattleStage
var _specials_shown: Dictionary = {}  # uid -> true (special scene once per figure and battle)
var _special_title: Label
var _special_sub: Label
## The player's battle entries; battle uid i+1 belongs to entry i.
var _player_entries: Array = []
var _skipping := false
var _battle: Dictionary = {}
var _battle_gold := 0
var _url_seed_used := false
var _playback_token := 0  # increments to cancel an older playback

var _turn_label: Label
var _gold_label: Label
var _detail_panel: DetailPanel
var _seed_label: Label
var _banner: Label
var _start_button: Button
var _new_button: Button
var _speed_buttons: Array[Button] = []
var _fx_layer: Control
## Large status icons (shield, burn, bleed, curse) above each figure.
var _status_layer: Control
var _status_boxes: Dictionary = {}  # uid -> HBoxContainer
## Pause and step-by-step: a step plays until the next turn begins.
var _paused := false
var _step_requested := false
var _stepping := false
var _pause_button: Button
var _step_button: Button
## Battle statistics for the summary: uid -> {dealt, taken, healed, blocked}.
var _stats: Dictionary = {}
var _names: Dictionary = {}  # uid -> [name, is_enemy]
var _clash_pair: Array = []  # [player_uid, enemy_uid] of the current exchange
var _last_trigger := -1
var _summary: Control


func _ready() -> void:
	TranslationServer.set_locale("de")
	theme = UiTheme.build()
	FigureActor.draw_status_icons = false  # this screen shows them big
	_db = ContentDb.load_default()
	_build_layout()
	if sandbox:
		_new_battle()


## Run mode: shows the given fight and starts it right away.
func play_battle(player_team: Array, enemy_team: Array, gold: int, info: String,
		options: Dictionary = {}, rule_text: String = "", boss_name: String = "") -> void:
	_playback_token += 1
	_battle_gold = gold
	_player_entries = player_team
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

	# The pixel battle stage fills the space between the bars.
	_stage = BattleStage.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.unit_tapped.connect(_on_unit_tapped)
	root.add_child(_stage)

	root.add_child(_build_bottom_bar())

	_status_layer = Control.new()
	_status_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_layer)

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


## Minimal top bar: the turn (and short notes) in the middle; pause, step,
## speed and skip at the right.
func _build_top_bar() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 72)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	holder.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	_pause_button = _make_button(tr("UI_PAUSE"), Vector2(120, 56))
	_pause_button.pressed.connect(_toggle_pause)
	bar.add_child(_pause_button)
	_step_button = _make_button(tr("UI_STEP"), Vector2(150, 56))
	_step_button.pressed.connect(func() -> void: _step_requested = true)
	_step_button.disabled = true
	bar.add_child(_step_button)
	for speed in SPEEDS:
		var button := _make_button("%d×" % int(speed), Vector2(64, 56))
		button.toggle_mode = true
		button.pressed.connect(_set_speed.bind(speed, true))
		_speed_buttons.append(button)
		bar.add_child(button)
	var skip := _make_button(tr("UI_SKIP_BATTLE"), Vector2(150, 56))
	skip.pressed.connect(func() -> void:
		_skipping = true
		_set_paused(false))
	bar.add_child(skip)
	_set_speed(_load_speed())
	var margin_right := Control.new()
	margin_right.custom_minimum_size = Vector2(16, 0)
	bar.add_child(margin_right)

	# Turn counter and notes (decay, result) exactly in the middle.
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label = _make_label("", 30, Palette.GOLD)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_turn_label)
	_banner = _make_label("", 20, Palette.PARCHMENT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_banner)
	holder.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.position.y = 6
	# Gold is not shown in the bar; its changes float in under the turn.
	_gold_label = _make_label("", 1, Palette.GOLD)
	_gold_label.visible = false
	holder.add_child(_gold_label)
	return holder


func _toggle_pause() -> void:
	_set_paused(not _paused)


func _set_paused(paused: bool) -> void:
	_paused = paused
	_stepping = false
	_step_requested = false
	_pause_button.text = tr("UI_RESUME") if paused else tr("UI_PAUSE")
	_step_button.disabled = not paused


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
	bar.visible = sandbox  # the run shows the summary with its own button
	return bar


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
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).contains("skins=1"):
		# Skin showcase: the four legendary skins against a strong team.
		Cosmetics.skins = {"executioner": "skin_hell_executioner", "drowned_king": "skin_frost_king",
			"the_judge": "skin_star_judge", "king_midas": "skin_sun_midas"}
		player_team = ["king_midas", "the_judge", "drowned_king", "executioner"].map(
			func(id: String) -> Dictionary: return {"def": _db.figures[id], "level": 3})
	else:
		DebugTeams.add_fusions(_db, rng, player_team)
	var enemy_team := DebugTeams.random_enemy_team(_db, rng, rng.randi_range(3, 6))
	_battle_gold = rng.randi_range(0, 30)
	_battle = BattleSimulator.simulate(player_team, enemy_team, _battle_gold)
	_player_entries = player_team

	_seed_label.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version"), tr("UI_SEED") % seed_value]
	_set_gold(_battle_gold)
	_turn_label.text = ""
	_banner.text = ""
	_banner.add_theme_color_override("font_color", Palette.PARCHMENT)
	_start_button.disabled = false
	_detail_panel.hide()
	_show_start_state(_battle["events"][0])


## Details of a tapped figure; own figures also show equipment, blessings and
## what else is affecting them.
func _on_unit_tapped(unit: FigureActor) -> void:
	var extras := {}
	var index := unit.uid - 1
	if not unit.is_enemy and index >= 0 and index < _player_entries.size():
		var entry: Dictionary = _player_entries[index]
		if entry.has("figure"):
			extras = {"figure": entry["figure"], "db": _db, "sources": entry.get("sources", [])}
	_detail_panel.show_unit(unit.definition, unit.snapshot, unit.is_enemy, extras)


func _show_start_state(start_event: Dictionary) -> void:
	_skipping = false
	_set_paused(false)
	_pause_button.disabled = false
	_specials_shown.clear()
	_stage.setup(start_event, _db)
	if is_instance_valid(_summary):
		_summary.queue_free()
	_stats.clear()
	_names.clear()
	_clash_pair = []
	_last_trigger = -1
	for box in _status_boxes.values():
		box.queue_free()
	_status_boxes.clear()
	for uid in _stage.uids():
		var unit := _stage.actor(uid)
		_names[uid] = [ContentDb.display_name(unit.definition), unit.is_enemy]
		_stats[uid] = {"dealt": 0, "taken": 0, "healed": 0, "blocked": 0}
		_refresh_status(uid)


## Web only: "?seed=123" in the address replays that battle (for bug reports).
## Used once, for the first battle after loading.
func _take_url_seed() -> int:
	if _url_seed_used or not OS.has_feature("web"):
		return -1
	_url_seed_used = true
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	var match := RegEx.create_from_string("seed=(\\d+)").search(query)
	return int(match.get_string(1)) if match != null else -1


## Animations run a bit slower than the nominal speed so each step is readable.
const PACE := 1.35


func _set_speed(speed: float, save := false) -> void:
	_speed = speed / PACE
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], speed))
	if save:
		saved_speed = speed
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		config.set_value("battle", "speed", speed)
		config.save(SETTINGS_PATH)


func _load_speed() -> float:
	if saved_speed <= 0.0:
		var config := ConfigFile.new()
		saved_speed = float(config.get_value("battle", "speed", 1.0)) if config.load(SETTINGS_PATH) == OK else 1.0
	return saved_speed if saved_speed in SPEEDS else 1.0


## Playback speed for the stage (skipping makes everything near-instant).
func _stage_speed() -> float:
	return 40.0 if _skipping else _speed


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
		# Pause: wait here; a step plays on until the next turn begins.
		if _stepping and event["type"] == "turn":
			_stepping = false
		while _paused and not _stepping and not _skipping:
			if _step_requested:
				_step_requested = false
				_stepping = true
				break
			await get_tree().process_frame
			if token != _playback_token:
				return
		_count(event)
		var next_type: String = events[i + 1]["type"] if i + 1 < events.size() else ""
		match event["type"]:
			"turn":
				if i > 1:
					await _wait(0.3)  # breathing room between turns
				_turn_label.text = tr("UI_TURN") % event["turn"]
				_banner.text = ""
			"burn_tick":
				Sound.play("burn", -8.0)
				_float_on(event["uid"], tr("UI_BURN_TICK") % [event["from"], event["to"]], Emblem.COLORS["burn"])
			"blessing":
				await _show_trigger({"uid": event["uid"], "effect": "gain_shield", "targets": [event["uid"]]})
			"trigger":
				await _show_trigger(event)
			"update":
				var unit := _stage.actor(event["unit"]["uid"])
				if unit != null:
					unit.apply_snapshot(event["unit"])
					_refresh_status(event["unit"]["uid"])
			"clash":
				Sound.play("hit" if randf() < 0.6 else "punch", -3.0)
				await _animate_clash(event)
			"shielded":
				Sound.play("shield", -6.0)
				_float_on(event["uid"], "-%d %s" % [event["amount"], tr("STATUS_SHIELD")], Emblem.COLORS["shield"], 32)
			"damage":
				_show_damage(event)
				if next_type not in ["damage", "update", "shielded"]:
					await _wait(0.25)
			"heal":
				Sound.play("heal", -8.0)
				_float_on(event["uid"], "+%d" % event["amount"], Palette.SUIT_COLORS["coins"], 40)
			"gold":
				Sound.play("coins", -6.0)
				_set_gold(event["gold"])
				_float_number("%+d Gold" % event["delta"], _turn_label.global_position + Vector2(_turn_label.size.x / 2 - 30, 70), Palette.GOLD, 30)
			"decay":
				_banner.text = tr("UI_DECAY") % event["amount"]
			"dying":
				var dying_actor := _stage.actor(event["uid"])
				Sound.play("death_player" if dying_actor != null and not dying_actor.is_enemy else "death_enemy", -2.0)
				await _animate_dying(event)
			"revive":
				Sound.play("revive")
				await _animate_revive(event)
			"removed":
				await _animate_removed(event)
			"end":
				_skipping = false
				_show_result(event)
				_show_summary(event)
		i += 1


## Sound of an ability by its emblem kind.
const TRIGGER_SOUNDS := {"burn": "burn", "bleed": "bleed", "curse": "curse", "shield": "shield", "heart": "heal",
	"coin": "coins", "skull": "hit_heavy", "sword": "hit_heavy", "soul": "magic", "star": "magic"}


func _show_trigger(event: Dictionary) -> void:
	var source := _stage.actor(event["uid"])
	if source == null:
		return
	var kind := Emblem.kind_for_effect(event["effect"])
	var color: Color = Emblem.COLORS.get(kind, Palette.GOLD)
	if not _skipping:
		Sound.play(TRIGGER_SOUNDS.get(kind, "magic"), -6.0)
	var special := _special_name(source, event["effect"])
	if special != "" and not _skipping and not _specials_shown.has(event["uid"]):
		_specials_shown[event["uid"]] = true
		_show_special_banner(special, ContentDb.display_name(source.definition),
			Color(FigureArt.FX_COLORS[source.fx_theme][0]) if source.fx_theme != "" else Palette.GOLD)
		await _stage.special(event["uid"], _stage_speed())
	source.glow(color, 0.45 / _stage_speed())
	if _skipping:
		await _wait(0.5)
		return
	# Pixel projectiles fly to every other target; on itself it bursts around
	# the figure. The emblem rises above to name the effect.
	_stage.ability_fx(event["uid"], kind, event["targets"], _stage_speed())
	_rise_emblem(kind, _stage.screen_top(event["uid"]))
	await _wait(0.55)


## Name of a special attack: kings, aces, recipe figures and bosses have one,
## F3 fusions for their master ability. "" for everything else.
func _special_name(source: FigureActor, effect: String) -> String:
	var definition := source.definition
	# Legendary skins bring their own special scene.
	var skin := String(Cosmetics.skins.get(String(definition.get("id", "")), "")) if not source.is_enemy else ""
	if skin != "" and source.fx_theme != "":
		return tr("SPECIAL_" + skin.to_upper())
	var master: String = definition.get("fusion", {}).get("master", "")
	if master != "":
		for ability in Fusion.master_by_id(_db, master).get("abilities", []):
			if ability["effect"] == effect:
				return tr("MASTER_" + master.to_upper())
	var rank := String(definition.get("rank", ""))
	if definition.get("boss", false) or rank in ["king", "legend"]:
		var key := "SPECIAL_" + String(definition.get("id", "")).to_upper()
		return tr(key) if tr(key) != key else ContentDb.display_name(definition)
	return ""


## The special attack's name in big letters over the stage.
func _show_special_banner(title: String, subtitle: String, color: Color = Palette.GOLD) -> void:
	if _special_title == null:
		_special_title = _make_label("", 54, Palette.GOLD)
		_special_sub = _make_label("", 24, Palette.PARCHMENT)
		for label in [_special_title, _special_sub]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
			label.add_theme_constant_override("outline_size", 10)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fx_layer.add_child(label)
	_special_title.text = title
	_special_title.add_theme_color_override("font_color", color)
	_special_sub.text = subtitle
	_special_title.size = Vector2(size.x, 70)
	_special_sub.size = Vector2(size.x, 30)
	_special_title.position = Vector2(0, size.y * 0.16)
	_special_sub.position = Vector2(0, size.y * 0.16 + 64)
	for label in [_special_title, _special_sub]:
		label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.15 / _stage_speed())
		tween.tween_interval(0.75 / _stage_speed())
		tween.tween_property(label, "modulate:a", 0.0, 0.25 / _stage_speed())


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
func _fly_emblem(kind: String, from: Vector2, target_uid: int, flight := 0.3, arc := true) -> void:
	var emblem := Emblem.create(kind, 40)
	_fx_layer.add_child(emblem)
	var to := _stage.screen_center(target_uid)
	var lift := (-60.0 - absf(to.x - from.x) * 0.15) if arc else -12.0
	var place := func(t: float) -> void:
		var point := from.lerp(to, t) + Vector2(0, lift * 4.0 * t * (1.0 - t))
		emblem.position = point - emblem.size / 2
		emblem.rotation = (to - from).angle() * 0.2 * (1.0 - t)
	place.call(0.0)
	var tween := create_tween()
	tween.tween_method(place, 0.0, 1.0, flight / _speed).set_ease(Tween.EASE_IN_OUT)
	if kind != "sword":  # plain attacks already flash red on impact
		tween.tween_callback(func() -> void:
			var target := _stage.actor(target_uid)
			if target != null:
				target.glow(emblem.color, 0.3 / _stage_speed()))
	tween.tween_property(emblem, "scale", Vector2(1.6, 1.6), 0.12 / _speed)
	tween.parallel().tween_property(emblem, "modulate:a", 0.0, 0.12 / _speed)
	tween.tween_callback(emblem.queue_free)


func _animate_clash(event: Dictionary) -> void:
	await _stage.clash(event["player_uid"], event["enemy_uid"], _stage_speed())


func _show_damage(event: Dictionary) -> void:
	var unit := _stage.actor(event["uid"])
	if unit == null:
		return
	unit.hit(0.3 / _stage_speed())
	if _skipping:
		return
	var color: Color = Palette.DAMAGE_FLASH
	if event["source"] in ["burn", "bleed"]:
		color = Emblem.COLORS[event["source"]]
	_float_number("-%d" % event["amount"], _stage.screen_center(event["uid"]), color, 50)


func _animate_dying(event: Dictionary) -> void:
	var unit := _stage.actor(event["uid"])
	if unit == null:
		return
	unit.shake(0.16 / _stage_speed())
	await _wait(0.16)


func _animate_revive(event: Dictionary) -> void:
	var unit := _stage.actor(event["uid"])
	if unit == null:
		return
	unit.revive(0.4 / _stage_speed())
	_float_on(event["uid"], tr("UI_REVIVED"), Palette.PARCHMENT)
	await _wait(0.3)


func _animate_removed(event: Dictionary) -> void:
	await _stage.remove(event["uid"], _stage_speed())


func _float_on(uid: int, text: String, color: Color, font_size := 28) -> void:
	if _stage.actor(uid) != null and not _skipping:
		_float_number(text, _stage.screen_top(uid), color, font_size)


## A number that pops up (grows, settles), rises and fades.
func _float_number(text: String, at: Vector2, color: Color, font_size := 28) -> void:
	var label := _make_label(text, font_size, color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 5))
	_fx_layer.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2
	label.position = at - Vector2(label.size.x / 2, label.size.y)
	label.scale = Vector2(0.4, 0.4)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2(1.2, 1.2), 0.12 / _speed)
	pop.tween_property(label, "scale", Vector2.ONE, 0.1 / _speed)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 56, 0.9 / _speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.5 / _speed).set_delay(0.45 / _speed)
	tween.chain().tween_callback(label.queue_free)


func _set_gold(value: int) -> void:
	_gold_label.text = tr("UI_GOLD") % value


func _show_result(event: Dictionary) -> void:
	Sound.play("bell" if event["outcome"] != BattleSimulator.Outcome.LOSS else "boom")
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
	if _skipping:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds / _speed).timeout



# --- Status icons -----------------------------------------------------------------

const STATUS_KINDS := ["shield", "burn", "bleed", "curse"]


## Rebuilds the status row of a figure from its latest snapshot.
func _refresh_status(uid: int) -> void:
	var unit := _stage.actor(uid)
	if unit == null:
		return
	var box: HBoxContainer = _status_boxes.get(uid)
	if box == null:
		box = HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_status_layer.add_child(box)
		_status_boxes[uid] = box
	for child in box.get_children():
		child.queue_free()
	var statuses: Dictionary = unit.snapshot.get("statuses", {})
	for kind in STATUS_KINDS:
		var amount := int(statuses.get(kind, 0))
		if amount <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 1)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var emblem := Emblem.create(kind, 34)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(emblem)
		var number := _make_label(str(amount), 28, Color.WHITE)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 6)
		chip.add_child(number)
		box.add_child(chip)
	box.reset_size()


func _process(_delta: float) -> void:
	# The status rows follow their figures (which run, jump and die).
	for uid in _status_boxes:
		var box: HBoxContainer = _status_boxes[uid]
		var unit := _stage.actor(uid)
		var shown := unit != null and not unit.dead and box.get_child_count() > 0
		box.visible = shown
		if shown:
			box.reset_size()
			box.position = _stage.screen_top(uid) - Vector2(box.size.x / 2, box.size.y + 10)


# --- Summary ----------------------------------------------------------------------

## Collects who dealt, took, blocked and healed how much.
func _count(event: Dictionary) -> void:
	match String(event["type"]):
		"turn":
			_clash_pair = []
			_last_trigger = -1
		"clash":
			_clash_pair = [event["player_uid"], event["enemy_uid"]]
		"trigger":
			_last_trigger = int(event["uid"])
		"damage":
			var uid := int(event["uid"])
			_add_stat(uid, "taken", int(event["amount"]))
			var dealer := -1
			if event["source"] in ["attack", "pierce"] and _clash_pair.size() == 2:
				dealer = _clash_pair[1] if uid == _clash_pair[0] else _clash_pair[0]
			elif not event["source"] in ["burn", "bleed", "decay"]:
				dealer = _last_trigger
			if dealer >= 0 and dealer != uid:
				_add_stat(dealer, "dealt", int(event["amount"]))
		"shielded":
			_add_stat(int(event["uid"]), "blocked", int(event["amount"]))
		"heal":
			_add_stat(int(event["uid"]), "healed", int(event["amount"]))


func _add_stat(uid: int, key: String, amount: int) -> void:
	if _stats.has(uid):
		_stats[uid][key] += amount


## End of the battle: the result and a small table for your figures.
func _show_summary(event: Dictionary) -> void:
	if is_instance_valid(_summary):
		_summary.queue_free()
	_banner.text = ""  # the summary names the result
	_pause_button.disabled = true
	_step_button.disabled = true
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_summary = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.06, 0.95)
	style.border_color = Color(Palette.GOLD, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var outcome: int = event["outcome"]
	var title_text := tr("UI_VICTORY") if outcome == BattleSimulator.Outcome.WIN else (tr("UI_DEFEAT_SHORT") if outcome == BattleSimulator.Outcome.LOSS else tr("UI_DRAW_SHORT"))
	var title := _make_label(title_text, 40, Palette.GOLD if outcome != BattleSimulator.Outcome.LOSS else Palette.HEALTH)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	grid.add_child(_make_label("", 18, Palette.MUTED))
	for header in [["sword", "UI_SUM_DEALT"], ["heart", "UI_SUM_TAKEN"], ["shield", "UI_SUM_BLOCKED"], ["heart", "UI_SUM_HEALED"]]:
		var head := _make_label(tr(header[1]), 18, Palette.MUTED)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(head)
	var best_uid := -1
	var uids := _stats.keys()
	uids.sort()
	for uid in uids:
		if _names[uid][1]:
			continue  # only your own figures
		if best_uid < 0 or _stats[uid]["dealt"] > _stats[best_uid]["dealt"]:
			best_uid = uid
	for uid in uids:
		if _names[uid][1]:
			continue
		var stats: Dictionary = _stats[uid]
		var name_label := _make_label(_names[uid][0], 20,
			Palette.GOLD if uid == best_uid else Palette.PARCHMENT)
		grid.add_child(name_label)
		for entry in [["dealt", Palette.DAMAGE_FLASH], ["taken", Palette.PARCHMENT], ["blocked", Emblem.COLORS["shield"]], ["healed", Palette.SUIT_COLORS["coins"]]]:
			var value := int(stats[entry[0]])
			var cell := _make_label(str(value) if value > 0 else "–", 22, entry[1] if value > 0 else Palette.MUTED)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(cell)
	var button := _make_button(tr("UI_CONTINUE") if not sandbox else tr("UI_NEW_BATTLE"), Vector2(260, 64))
	button.pressed.connect(_on_new_button)
	var button_center := CenterContainer.new()
	button_center.add_child(button)
	column.add_child(button_center)
