class_name TreasuryView
extends Control
## Boss treasury: a heavy chest shakes, bursts open in a shower of gold and
## three treasures rise from it - a relic (or souls), an ace pack with a
## guaranteed legend, or gold. The player takes one.

signal chosen(index: int)

const CARD := Vector2(190, 270)
const CHEST := Vector2(200, 130)

var _run: RunState
var _db: ContentDb
var _detail: Control
var _time := 0.0
var _opened_at := -1.0
var _shake := 0.0
var _coins: Array = []  # {"p", "v", "c"}
var _cards: Array = []
var _title: Label


static func create(run: RunState, db: ContentDb, detail: Control) -> TreasuryView:
	var view := TreasuryView.new()
	view._run = run
	view._db = db
	view._detail = detail
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _ready() -> void:
	_title = Label.new()
	_title.text = tr("UI_TREASURY")
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 22
	add_child(_title)
	var hint := Label.new()
	hint.text = tr("UI_TREASURY_HINT")
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Palette.PARCHMENT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 72
	add_child(hint)
	# The chest shakes harder and harder, then bursts open.
	var tween := create_tween()
	tween.tween_property(self, "_shake", 1.0, 0.9)
	tween.tween_callback(_burst_open)
	tween.tween_property(self, "_shake", 0.0, 0.1)


func _chest_rect() -> Rect2:
	return Rect2(Vector2(size.x / 2 - CHEST.x / 2, size.y - CHEST.y - 40), CHEST)


func _burst_open() -> void:
	_opened_at = _time
	var mouth := _chest_rect().position + Vector2(CHEST.x / 2, 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
		var speed := rng.randf_range(260, 620)
		_coins.append({"p": mouth, "v": Vector2(cos(angle), sin(angle)) * speed,
			"c": Palette.GOLD.lerp(Color.WHITE, rng.randf() * 0.4)})
	_deal_cards()


func _deal_cards() -> void:
	var count := _run.treasure.size()
	var total := count * CARD.x + (count - 1) * 40.0
	var top := 120.0
	for i in count:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var face := _treasure_face(_run.treasure[i])
		box.add_child(face)
		var take := Button.new()
		take.text = tr("UI_CHOOSE")
		take.custom_minimum_size = Vector2(CARD.x, 54)
		take.add_theme_font_size_override("font_size", 22)
		take.pressed.connect(_on_choose.bind(i))
		box.add_child(take)
		add_child(box)
		var target := Vector2(size.x / 2 - total / 2 + i * (CARD.x + 40.0), top)
		box.position = _chest_rect().get_center() - CARD / 2
		box.scale = Vector2(0.2, 0.2)
		box.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(box, "position", target, 0.5).set_delay(0.15 + i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(box, "scale", Vector2.ONE, 0.5).set_delay(0.15 + i * 0.12)
		tween.tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.15 + i * 0.12)
		_cards.append(box)


## One treasure as a card: the relic itself, or a framed panel with emblem and text.
func _treasure_face(entry: Dictionary) -> Control:
	if entry["kind"] == "relic":
		var card := ObjectCard.create(_db, {"kind": "relic", "id": entry["id"]}, CARD)
		if _detail != null and _detail.has_method("show_object"):
			card.tapped.connect(_detail.show_object)
		# A fixed holder keeps the card in line with the other treasures.
		var holder := Control.new()
		holder.custom_minimum_size = CARD
		holder.add_child(card)
		card.position = Vector2.ZERO
		card.size = CARD
		return holder
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(4)
	style.shadow_size = 10
	var emblem_kind := "coin"
	var color := Palette.GOLD
	var title := ""
	var text := ""
	match entry["kind"]:
		"legend_pack":
			emblem_kind = "pack"
			color = Color(0.45, 0.95, 0.88)
			title = tr("PACK_LEGEND")
			text = tr("UI_TREASURE_LEGEND_PACK")
		"gold":
			title = tr("UI_PLUS_GOLD") % int(entry["amount"])
			text = tr("UI_TREASURE_GOLD")
		"souls":
			emblem_kind = "soul"
			color = Emblem.COLORS["soul"]
			title = tr("UI_INCOME_SOULS") % int(entry["amount"])
			text = tr("UI_TREASURE_SOULS")
	style.bg_color = Color(0.07, 0.05, 0.09)
	style.border_color = color
	style.shadow_color = Color(color, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("glow", entry["kind"] == "legend_pack")
	panel.set_meta("style", style)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var emblem := Emblem.create(emblem_kind, 72)
	emblem.color = color
	var center := CenterContainer.new()
	center.add_child(emblem)
	column.add_child(center)
	for line in [[title, 26, color], [text, 17, Palette.PARCHMENT]]:
		var label := Label.new()
		label.text = line[0]
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CARD.x - 24, 0)
		column.add_child(label)
	return panel


func _on_choose(index: int) -> void:
	for box in _cards:
		for child in box.get_children():
			if child is Button:
				child.disabled = true
	var picked: Control = _cards[index]
	var tween := create_tween()
	tween.tween_property(picked, "scale", Vector2(1.12, 1.12), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		chosen.emit(index)
		queue_free())


func _process(delta: float) -> void:
	_time += delta
	for coin in _coins:
		coin["v"] += Vector2(0, 900) * delta
		coin["p"] += coin["v"] * delta
	_coins = _coins.filter(func(c: Dictionary) -> bool: return c["p"].y < size.y + 20)
	# The ace pack shimmers in shifting colours.
	for box in _cards:
		var face: Control = box.get_child(0)
		if face.get_meta("glow", false):
			var style: StyleBoxFlat = face.get_meta("style")
			style.border_color = Color.from_hsv(fmod(_time * 0.4, 1.0), 0.55, 1.0)
			style.shadow_color = Color(style.border_color, 0.6)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.008, 0.02, 0.95))
	var rect := _chest_rect()
	var jitter := Vector2(sin(_time * 55.0), cos(_time * 47.0)) * 6.0 * _shake
	rect.position += jitter
	var open := 0.0 if _opened_at < 0 else clampf((_time - _opened_at) / 0.25, 0.0, 1.0)
	# Light pouring out of the open chest.
	if open > 0.0:
		var glow := Color(1.0, 0.82, 0.35, 0.18 * open)
		for i in 4:
			var w := CHEST.x * (0.5 + i * 0.35)
			draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(CHEST.x / 2 - 60, 30), rect.position + Vector2(CHEST.x / 2 + 60, 30),
				rect.position + Vector2(CHEST.x / 2 + w, -360), rect.position + Vector2(CHEST.x / 2 - w, -360)]), glow)
	var wood := Color(0.36, 0.2, 0.1)
	var dark := Color(0.2, 0.1, 0.05)
	var band := Color(0.85, 0.66, 0.25)
	# Body
	var body := Rect2(rect.position + Vector2(0, 40), Vector2(CHEST.x, CHEST.y - 40))
	draw_rect(body, wood)
	draw_rect(body, dark, false, 4)
	for x in [24.0, CHEST.x - 36.0]:
		draw_rect(Rect2(body.position + Vector2(x, 0), Vector2(12, body.size.y)), band)
	draw_rect(Rect2(body.position + Vector2(CHEST.x / 2 - 14, 6), Vector2(28, 30)), band)
	draw_rect(Rect2(body.position + Vector2(CHEST.x / 2 - 4, 16), Vector2(8, 12)), dark)
	# Lid: closed it sits on the body, open it tips back.
	var lid_h := 44.0 - 30.0 * open
	var lid := Rect2(rect.position + Vector2(-6, 40 - lid_h - 14.0 * open), Vector2(CHEST.x + 12, lid_h))
	draw_rect(lid, wood.lightened(0.08))
	draw_rect(lid, dark, false, 4)
	for x in [24.0, CHEST.x - 30.0]:
		draw_rect(Rect2(lid.position + Vector2(x, 0), Vector2(12, lid.size.y)), band)
	if open > 0.0:
		draw_rect(Rect2(body.position + Vector2(10, -6), Vector2(CHEST.x - 20, 12)), Palette.GOLD)
	for coin in _coins:
		draw_rect(Rect2(coin["p"], Vector2(7, 7)), coin["c"])
