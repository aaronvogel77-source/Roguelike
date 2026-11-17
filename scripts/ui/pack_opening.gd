class_name PackOpening
extends Control
## Opening a pack or vault chest: the pack shakes, tears open in a flash and
## its cards fly out face down. Each card glows in its rarity colour and turns
## over when tapped ("Alle aufdecken" turns the rest). Legendary skins get
## their own big reveal (LegendaryReveal).
##
## A card is {"face": Control, "rarity": 0..5 (5 = legendary), "skin": skin id or ""}.

signal finished

const CARD := Vector2(150, 214)
const GAP := 26.0
## Glow colours: common, magic, rare, epic, unique/legend-figure, legendary skin.
const GLOW := [Color(0.85, 0.82, 0.75), Color(0.4, 0.6, 1.0), Color(1.0, 0.78, 0.3),
	Color(0.78, 0.35, 1.0), Color(0.45, 0.95, 0.88), Color(1.0, 0.5, 0.2)]

var _cards: Array = []
var _slots: Array = []  # {"root", "back", "face", "rarity", "skin", "open"}
var _title := ""
var _pack: Control
var _flash: ColorRect
var _bursts: Array = []  # {"at", "color", "time"}
var _time := 0.0
var _button: Button
var _ready_to_flip := false
var _busy := false
## Loot of a hard band: golden pack, "Beute!" banner, coin rain, bells.
var _loot := false
var _coins: Array = []  # {"p", "v"}


static func create(cards: Array, title: String, loot := false) -> PackOpening:
	var view := PackOpening.new()
	view._cards = cards
	view._title = title
	view._loot = loot
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.02, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := Label.new()
	title.text = _title
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	add_child(title)
	_pack = _card_back(Vector2(170, 240), 2, true)
	_pack.pivot_offset = Vector2(85, 120)
	add_child(_pack)
	if _loot:
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		var style: StyleBoxFlat = _pack.get_meta("style")
		style.border_color = Palette.GOLD
		style.shadow_color = Color(1.0, 0.8, 0.3, 0.9)
		style.shadow_size = 18
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.97, 0.85, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.custom_minimum_size = Vector2(260, 60)
	_button.add_theme_font_size_override("font_size", 22)
	_button.visible = false
	_button.pressed.connect(_on_button)
	add_child(_button)
	add_child(_flash)
	_layout.call_deferred()
	if _loot:
		_loot_intro.call_deferred()
	else:
		_tear_open.call_deferred()


## Loot: a big "Beute!" stamps in, coins rain on the golden pack, then it tears open.
func _loot_intro() -> void:
	Sound.play("coins")
	Sound.play("bell_big", -2.0)
	var banner := Label.new()
	banner.text = tr("UI_LOOT_BANNER")
	banner.add_theme_font_size_override("font_size", 96)
	banner.add_theme_color_override("font_color", Palette.GOLD)
	banner.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02))
	banner.add_theme_constant_override("outline_size", 14)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(size.x, 120)
	banner.position = Vector2(0, size.y / 2 - 200)
	banner.pivot_offset = Vector2(size.x / 2, 60)
	banner.scale = Vector2(2.4, 2.4)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		_coins.append({"p": Vector2(rng.randf_range(0, size.x), rng.randf_range(-400, -20)),
			"v": Vector2(rng.randf_range(-30, 30), rng.randf_range(260, 520))})
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		banner.queue_free()
		_tear_open())


func _layout() -> void:
	_pack.position = size / 2 - _pack.size / 2
	_button.position = Vector2(size.x / 2 - 130, size.y - 84)


## The pack shakes harder and harder, then bursts in a flash.
func _tear_open() -> void:
	var best := 0
	for card in _cards:
		best = maxi(best, int(card["rarity"]))
	var tween := create_tween()
	for i in 10:
		var strength := 0.03 + i * 0.012
		tween.tween_property(_pack, "rotation", strength if i % 2 else -strength, 0.06)
	tween.tween_property(_pack, "rotation", 0.0, 0.05)
	tween.parallel().tween_property(_pack, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_callback(func() -> void:
		Sound.play("pack_open")
		if best >= 4:
			Sound.play("bell_big", -4.0)
		_flash.color = Color(GLOW[best]).lerp(Color.WHITE, 0.6)
		_flash.color.a = 0.9
		_burst(size / 2, GLOW[best], 40)
		if _loot:  # a second, golden burst for the loot
			_burst(size / 2, Palette.GOLD, 50)
		_pack.visible = false
		_deal())
	tween.tween_property(_flash, "color:a", 0.0, 0.45)


## Cards fly from the centre to their places, face down.
func _deal() -> void:
	var total := _cards.size() * CARD.x + (_cards.size() - 1) * GAP
	var start := Vector2(size.x / 2 - total / 2, size.y / 2 - CARD.y / 2 - 10)
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var root := Control.new()
		root.size = CARD
		root.pivot_offset = CARD / 2
		root.position = size / 2 - CARD / 2
		root.scale = Vector2(0.2, 0.2)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(root)
		move_child(root, _button.get_index())
		var face: Control = card["face"]
		var face_holder := CenterContainer.new()
		face_holder.size = CARD
		face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_holder.add_child(face)
		face_holder.visible = false
		root.add_child(face_holder)
		var back := _card_back(CARD, int(card["rarity"]), false)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(back)
		var slot := {"root": root, "back": back, "face": face_holder, "rarity": int(card["rarity"]),
			"skin": String(card.get("skin", "")), "open": false}
		_slots.append(slot)
		root.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_flip(slot)
			elif event is InputEventScreenTouch and event.pressed:
				_flip(slot))
		var tween := create_tween().set_parallel(true)
		var target := start + Vector2(i * (CARD.x + GAP), 0)
		tween.tween_property(root, "position", target, 0.35).set_delay(i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(root, "scale", Vector2.ONE, 0.35).set_delay(i * 0.08)
	get_tree().create_timer(0.45 + _cards.size() * 0.08).timeout.connect(func() -> void:
		_ready_to_flip = true
		_button.text = tr("UI_REVEAL_ALL")
		_button.visible = true)


func _flip(slot: Dictionary) -> void:
	if slot["open"] or not _ready_to_flip or _busy:
		return
	slot["open"] = true
	var root: Control = slot["root"]
	var rarity: int = slot["rarity"]
	if slot["skin"] != "":
		# Legendary skin: the big reveal first, the card turns afterwards.
		_busy = true
		var reveal := LegendaryReveal.create(slot["skin"])
		reveal.finished.connect(func() -> void:
			_busy = false
			_turn(slot))
		add_child(reveal)
		return
	_turn(slot)
	if rarity >= 3:  # epic and better: a flash and a short shake
		_flash.color = Color(GLOW[rarity], 0.55)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
		var shake := create_tween()
		for i in 4:
			shake.tween_property(root, "rotation", 0.06 if i % 2 else -0.06, 0.04)
		shake.tween_property(root, "rotation", 0.0, 0.04)


func _turn(slot: Dictionary) -> void:
	var root: Control = slot["root"]
	var tween := create_tween()
	tween.tween_property(root, "scale:x", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		Sound.play("card_flip", -2.0)
		if slot["rarity"] >= 4:
			Sound.play("bell")
		elif slot["rarity"] >= 2:
			Sound.play("gem", -4.0)
		slot["back"].visible = false
		slot["face"].visible = true
		if slot["rarity"] >= 1:
			_burst(root.position + CARD / 2, GLOW[slot["rarity"]], 10 + slot["rarity"] * 6))
	tween.tween_property(root, "scale:x", 1.0, 0.12)
	tween.tween_callback(_check_done)


func _check_done() -> void:
	if _slots.all(func(s: Dictionary) -> bool: return s["open"]) and not _busy:
		_button.text = tr("UI_CONTINUE")


func _on_button() -> void:
	if _slots.all(func(s: Dictionary) -> bool: return s["open"]):
		finished.emit()
		queue_free()
		return
	# Turn the rest one after another (legendary skins still get their reveal).
	for slot in _slots:
		if not slot["open"]:
			_flip(slot)
			if _busy:
				return
			await get_tree().create_timer(0.18).timeout


## A face-down card in the worn card back, glowing in its rarity colour.
func _card_back(card_size: Vector2, rarity: int, is_pack: bool) -> Panel:
	var panel := Panel.new()
	panel.size = card_size
	var colors := Cosmetics.back_colors()
	var style := StyleBoxFlat.new()
	style.bg_color = colors["bg"]
	style.border_color = colors["border"]
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	if not is_pack and rarity >= 1:
		style.shadow_color = Color(GLOW[rarity], 0.85)
		style.shadow_size = 6 + rarity * 4
	panel.add_theme_stylebox_override("panel", style)
	var emblem := Emblem.create("pack" if is_pack else "star", 56 if is_pack else 44)
	emblem.position = card_size / 2 - emblem.size / 2
	panel.add_child(emblem)
	panel.set_meta("style", style)
	panel.set_meta("rarity", rarity)
	return panel


func _burst(at: Vector2, color: Color, count: int) -> void:
	_bursts.append({"at": at, "color": color, "time": _time, "count": count})


func _process(delta: float) -> void:
	_time += delta
	for coin in _coins:
		coin["v"] += Vector2(0, 300) * delta
		coin["p"] += coin["v"] * delta
	_coins = _coins.filter(func(c: Dictionary) -> bool: return c["p"].y < size.y + 20)
	# Rarer face-down cards shimmer and tremble; legendary ones cycle colours.
	for slot in _slots:
		if slot["open"]:
			continue
		var back: Panel = slot["back"]
		var rarity: int = slot["rarity"]
		var style: StyleBoxFlat = back.get_meta("style")
		if rarity >= 4:
			style.shadow_color = Color.from_hsv(fmod(_time * 0.6, 1.0), 0.7, 1.0, 0.9)
		elif rarity >= 1:
			style.shadow_color.a = 0.55 + 0.35 * sin(_time * (3.0 + rarity))
		if rarity >= 3 and _ready_to_flip:
			slot["root"].rotation = sin(_time * 30.0) * 0.012 * (rarity - 2)
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return _time - float(b["time"]) < 0.8)
	queue_redraw()


func _draw() -> void:
	for coin in _coins:
		var spin := absf(sin(_time * 9.0 + coin["p"].x))
		draw_rect(Rect2(coin["p"] - Vector2(4 * spin, 4), Vector2(maxf(8 * spin, 2), 8)), Palette.GOLD)
		draw_rect(Rect2(coin["p"] - Vector2(2 * spin, 2), Vector2(maxf(3 * spin, 1), 3)), Color(1.0, 0.95, 0.6))
	for burst in _bursts:
		var q := (_time - float(burst["time"])) / 0.8
		var color: Color = burst["color"]
		var count: int = burst["count"]
		for i in count:
			var a := TAU * i / count + float(i % 3) * 0.2
			var r := q * (90.0 + (i % 5) * 22.0)
			var p: Vector2 = burst["at"] + Vector2(cos(a), sin(a)) * r + Vector2(0, q * q * 40.0)
			var c := color.lerp(Color.WHITE, 0.3 if i % 2 else 0.0)
			c.a = 1.0 - q
			draw_rect(Rect2(p, Vector2(6, 6) if i % 3 == 0 else Vector2(4, 4)), c)
