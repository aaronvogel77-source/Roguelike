class_name BattleStage
extends Control
## The side-view battle stage: a low-resolution pixel world (SubViewport)
## scaled up sharply. Holds the figures (FigureActor), lays out both rows
## (front units next to the middle), plays clashes (melee figures run in,
## ranged ones throw) and reports taps on figures.

signal unit_tapped(actor: FigureActor)

const VIEW := Vector2i(300, 130)
const FLOOR := 110
const SLOT := 24.0
const PLAYER_FRONT := 134.0
const ENEMY_FRONT := 166.0

var _db: ContentDb
var _viewport: SubViewport
var _display: TextureRect
var _actors_layer: Node2D
var _shots_layer: Node2D
var _ambient: Node2D
var _actors: Dictionary = {}  # uid -> FigureActor
var _player_order: Array = []  # uids, front first
var _enemy_order: Array = []
var _time := 0.0
var _shot_textures: Dictionary = {}
var _camera: Camera2D
var _dim: Node2D
var _dim_amount := 0.0
var _particles: Node2D
var _sparks: Array = []  # {pos, vel, color, life, max}

## Colors of ability effects (by emblem kind).
const FX_COLORS := {
	"burn": Color("ff8a2a"), "bleed": Color("e0263a"), "curse": Color("b06ae8"), "shield": Color("a8c4ea"),
	"heart": Color("5fd06a"), "coin": Color("ffd24a"), "skull": Color("d8d0c4"), "sword": Color("e8ecf4"),
	"star": Color("ffe08a"),
}


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var background := Sprite2D.new()
	background.texture = FigureArt.background(Cosmetics.stage, VIEW.x, VIEW.y, FLOOR - 4)
	background.centered = false
	_viewport.add_child(background)
	_ambient = Node2D.new()
	_ambient.draw.connect(_draw_ambient)
	_viewport.add_child(_ambient)
	# Darkens the scene behind a figure during its special attack.
	_dim = Node2D.new()
	_dim.draw.connect(func() -> void:
		if _dim_amount > 0.0:
			_dim.draw_rect(Rect2(-40, -40, VIEW.x + 80, VIEW.y + 80), Color(0, 0, 0, _dim_amount)))
	_viewport.add_child(_dim)
	_actors_layer = Node2D.new()
	_actors_layer.y_sort_enabled = false
	_viewport.add_child(_actors_layer)
	_shots_layer = Node2D.new()
	_viewport.add_child(_shots_layer)
	_particles = Node2D.new()
	_particles.draw.connect(_draw_particles)
	_viewport.add_child(_particles)
	_camera = Camera2D.new()
	_camera.position = Vector2(VIEW) / 2.0
	_viewport.add_child(_camera)

	_display = TextureRect.new()
	_display.texture = _viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.gui_input.connect(_on_display_input)
	add_child(_display)


func _process(delta: float) -> void:
	_time += delta
	_ambient.queue_redraw()
	_dim.queue_redraw()
	for spark in _sparks:
		spark["pos"] += spark["vel"] * delta
		spark["vel"].y += spark.get("gravity", 0.0) * delta
		spark["life"] -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["life"] > 0.0)
	_particles.queue_redraw()


# --- Setup and layout -----------------------------------------------------------------

func setup(start_event: Dictionary, db: ContentDb) -> void:
	_db = db
	FigureArt.gold_hint = int(start_event.get("gold", 0))
	for child in _actors_layer.get_children():
		child.queue_free()
	for child in _shots_layer.get_children():
		child.queue_free()
	_actors.clear()
	_player_order.clear()
	_enemy_order.clear()
	for snapshot in start_event["player"]:
		_add_actor(snapshot, false)
	for snapshot in start_event["enemy"]:
		_add_actor(snapshot, true)
	_layout(0.0)


func _add_actor(snapshot: Dictionary, enemy: bool) -> void:
	var definition: Dictionary = _db.enemies[snapshot["def_id"]] if enemy else _db.figures[snapshot["def_id"]]
	if not snapshot.get("display", {}).is_empty():
		definition = snapshot["display"]  # fusions: their built definition
	var actor := FigureActor.new()
	actor.setup(definition, snapshot, enemy)
	_actors_layer.add_child(actor)
	_actors[actor.uid] = actor
	(_enemy_order if enemy else _player_order).append(actor.uid)


## Slot positions: front units stand next to the middle; boss figures take
## 2-3 slots. duration 0 places instantly, otherwise the figures walk.
func _layout(duration: float) -> void:
	for i in _player_order.size():
		_move(_actors[_player_order[i]], PLAYER_FRONT - i * SLOT, duration)
	# Enemies: wide creatures take more room; squeeze if the row gets too long.
	var widths: Array = []
	var total := 0.0
	for uid in _enemy_order:
		var unit: FigureActor = _actors[uid]
		var w := maxf(unit.footprint(), float(unit.definition.get("width", 1)) * SLOT)
		widths.append(w)
		total += w
	var room := float(VIEW.x) - ENEMY_FRONT + SLOT / 2.0 - 6.0
	var squeeze := minf(1.0, room / maxf(total, 1.0))
	var cursor := ENEMY_FRONT - SLOT / 2.0
	for i in _enemy_order.size():
		var w: float = widths[i] * squeeze
		_move(_actors[_enemy_order[i]], cursor + w / 2.0, duration)
		cursor += w


func _move(actor: FigureActor, x: float, duration: float) -> void:
	actor.home_x = x
	if duration <= 0.0:
		actor.position = Vector2(x, FLOOR)
	elif absf(actor.position.x - x) > 0.5:
		actor.run_to(x, duration)


func actor(uid: int) -> FigureActor:
	return _actors.get(uid)


## Screen position (canvas coordinates) of a point in the stage.
func to_screen(point: Vector2) -> Vector2:
	var scale := minf(_display.size.x / VIEW.x, _display.size.y / VIEW.y)
	var offset := (_display.size - Vector2(VIEW) * scale) / 2.0
	return _display.global_position + offset + point * scale


func screen_center(uid: int) -> Vector2:
	var a := actor(uid)
	return to_screen(a.center()) if a != null else Vector2.ZERO


func screen_top(uid: int) -> Vector2:
	var a := actor(uid)
	return to_screen(a.top()) if a != null else Vector2.ZERO


func pixel_scale() -> float:
	return minf(_display.size.x / VIEW.x, _display.size.y / VIEW.y)


# --- Battle actions ---------------------------------------------------------------------

## Both front figures attack at once. Melee figures run to the middle and
## strike, ranged ones throw from their place. Returns at the moment of impact
## (the walk back continues in the background).
func clash(player_uid: int, enemy_uid: int, speed: float) -> void:
	var p := actor(player_uid)
	var e := actor(enemy_uid)
	if p == null or e == null:
		return
	var approach := 0.22 / speed
	var strike := 0.12 / speed
	var mid := (p.home_x + e.home_x) / 2.0
	var reach := 8.0 + float(e.definition.get("width", 1)) * 4.0
	for pair in [[p, e, mid - reach], [e, p, mid + reach]]:
		var attacker: FigureActor = pair[0]
		var target: FigureActor = pair[1]
		if attacker.ranged:
			attacker.throw_motion(approach + strike)
			_fire_shot(attacker, target, approach * 0.6, approach + strike - approach * 0.6)
		else:
			attacker.run_to(pair[2], approach)
			attacker.wind_up(approach)
			_after(approach, attacker.strike.bind(strike * 2.0))
	await get_tree().create_timer(approach + strike).timeout
	for attacker: FigureActor in [p, e]:
		if not attacker.ranged and is_instance_valid(attacker):
			_after(0.08 / speed, func() -> void:
				if is_instance_valid(attacker) and not attacker.dead:
					attacker.run_to(attacker.home_x, 0.2 / speed))


func _after(seconds: float, callback: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(callback)


## A small projectile from the attacker's hand to the target (coin, fire,
## dagger, water or a dark orb for enemies).
func _fire_shot(attacker: FigureActor, target: FigureActor, delay: float, flight: float) -> void:
	var kind := "orb" if attacker.is_enemy else attacker.suit
	var shot := Sprite2D.new()
	shot.texture = _shot_texture(kind)
	shot.visible = false
	_shots_layer.add_child(shot)
	var from := attacker.hand_position() + Vector2(0, -4)
	var to := target.center()
	var fly := func(t: float) -> void:
		shot.visible = true
		shot.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * 16.0)
		shot.rotation = 0.0 if kind == "coins" else (to - from).angle()
		shot.scale.x = 1.0 if kind != "coins" else (1.0 if fmod(t * 6.0, 1.0) < 0.5 else 0.35)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(fly, 0.0, 1.0, flight)
	tween.tween_callback(shot.queue_free)


func _shot_texture(kind: String) -> Texture2D:
	if _shot_textures.has(kind):
		return _shot_textures[kind]
	var c := PixelCanvas.new(7, 7)
	match kind:
		"coins":
			c.blob(3, 3, 2, 2, FigureArt.ramp("gold"))
		"wands":
			c.px(Color("d8401a"), 1, 2, 5, 3)
			c.px(Color("ffa030"), 2, 2, 4, 3)
			c.px(Color("fff2a0"), 4, 3, 2, 1)
		"swords":
			c.px(Color("c8d6e6"), 1, 3, 5, 1)
			c.px(Color("ffffff"), 4, 3, 2, 1)
			c.px(Color("d9a530"), 0, 2, 1, 3)
		"cups":
			c.blob(3, 3, 2, 2, FigureArt.ramp("cups"))
		_:
			c.blob(3, 3, 2, 2, FigureArt.ramp("blood"))
	_shot_textures[kind] = c.outline().texture()
	return _shot_textures[kind]


## A figure dies (style by suit) and the rows close up.
func remove(uid: int, speed: float) -> void:
	var a := actor(uid)
	if a == null:
		return
	_player_order.erase(uid)
	_enemy_order.erase(uid)
	await a.die(0.5 / speed)
	_actors.erase(uid)
	a.queue_free()
	_layout(0.3 / speed)


# --- Ability effects and special attacks ----------------------------------------------

## An ability fires: a projectile in the ability's color flies to every other
## target and bursts there; an ability on the figure itself bursts around it.
func ability_fx(source_uid: int, kind: String, targets: Array, speed: float) -> void:
	var source := actor(source_uid)
	if source == null:
		return
	var color: Color = FX_COLORS.get(kind, Color("ffe08a"))
	var others: Array = targets.filter(func(uid: int) -> bool: return uid != source_uid and actor(uid) != null)
	if others.is_empty():
		burst(source.center(), color, 14, 26.0, -30.0)
		return
	for uid in others:
		var target := actor(uid)
		var from := source.center()
		var to := target.center()
		var orb := Node2D.new()
		orb.draw.connect(func() -> void:
			orb.draw_rect(Rect2(-2, -2, 4, 4), color.darkened(0.4))
			orb.draw_rect(Rect2(-1, -1, 3, 3), color)
			orb.draw_rect(Rect2(0, -1, 1, 1), Color.WHITE))
		_shots_layer.add_child(orb)
		var fly := func(t: float) -> void:
			orb.position = (from.lerp(to, t) + Vector2(0, -sin(t * PI) * 14.0)).round()
			if randf() < 0.6:
				_sparks.append({"pos": orb.position, "vel": Vector2(randf_range(-6, 6), randf_range(-6, 6)), "color": color, "life": 0.25, "max": 0.25})
		var tween := create_tween()
		tween.tween_method(fly, 0.0, 1.0, 0.3 / speed)
		tween.tween_callback(func() -> void:
			orb.queue_free()
			if is_instance_valid(target):
				burst(target.center(), color, 10, 22.0, 0.0))


## A small burst of pixel sparks.
func burst(at: Vector2, color: Color, count: int, spread: float, rise: float) -> void:
	for i in count:
		var angle := randf() * TAU
		_sparks.append({"pos": at, "vel": Vector2(cos(angle), sin(angle)) * randf_range(spread * 0.4, spread) + Vector2(0, rise),
			"color": color.lightened(randf() * 0.4), "life": randf_range(0.3, 0.6), "max": 0.6, "gravity": 40.0})


func _draw_particles() -> void:
	for spark in _sparks:
		var c: Color = spark["color"]
		c.a = clampf(spark["life"] / spark["max"], 0.0, 1.0)
		_particles.draw_rect(Rect2((spark["pos"] as Vector2).round(), Vector2.ONE), c)


## Special attack: the scene darkens, the camera closes in on the figure and a
## golden burst marks the moment (the battle view shows the ability's name).
func special(uid: int, speed: float) -> void:
	var a := actor(uid)
	if a == null:
		return
	var duration := 1.1 / speed
	for other in _actors.values():
		if other != a:
			(other as FigureActor).modulate = Color(0.35, 0.35, 0.4)
	a.z_index = 2
	var focus := a.center()
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(v: float) -> void: _dim_amount = v, 0.0, 0.55, duration * 0.25)
	tween.tween_property(_camera, "zoom", Vector2(1.45, 1.45), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_camera, "position", focus, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	a.raise_weapon(duration)
	await get_tree().create_timer(duration * 0.35).timeout
	burst(a.center() + Vector2(0, -6), Color("ffe08a"), 40, 40.0, -20.0)
	a.glow(Color("ffe08a"), duration * 0.5)
	await get_tree().create_timer(duration * 0.45).timeout
	var back := create_tween().set_parallel(true)
	back.tween_method(func(v: float) -> void: _dim_amount = v, 0.55, 0.0, duration * 0.2)
	back.tween_property(_camera, "zoom", Vector2.ONE, duration * 0.2)
	back.tween_property(_camera, "position", Vector2(VIEW) / 2.0, duration * 0.2)
	for other in _actors.values():
		back.tween_property(other, "modulate", Color.WHITE, duration * 0.2)
	await back.finished
	if is_instance_valid(a):
		a.z_index = 0


# --- Input ---------------------------------------------------------------------------

func _on_display_input(event: InputEvent) -> void:
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	if not released:
		return
	var scale := pixel_scale()
	var offset := (_display.size - Vector2(VIEW) * scale) / 2.0
	var point: Vector2 = (event.position - offset) / scale
	for uid in _actors:
		var a: FigureActor = _actors[uid]
		if not a.dead and a.hit_rect().has_point(point):
			unit_tapped.emit(a)
			return


# --- Ambient: flickering candles and dust ----------------------------------------------

func _draw_ambient() -> void:
	for spot in [Vector2(VIEW.x * 0.31, FLOOR - 66), Vector2(VIEW.x * 0.69, FLOOR - 66), Vector2(12, FLOOR - 26), Vector2(VIEW.x - 12, FLOOR - 26)]:
		var flicker := 1.0 if sin(_time * 9.0 + spot.x) > 0.0 else 0.0
		for r in [14.0, 9.0, 5.0]:
			_ambient.draw_circle(spot + Vector2(0, -3), r, Color(1.0, 0.66, 0.24, 0.05))
		_ambient.draw_rect(Rect2(spot + Vector2(-1, 0), Vector2(3, 6)), Color("e8dcc0"))
		_ambient.draw_rect(Rect2(spot + Vector2(0, -3 - flicker), Vector2(1, 3 + flicker)), Color("ffb43a"))
		_ambient.draw_rect(Rect2(spot + Vector2(0, -2), Vector2(1, 1)), Color("fff2b0"))
	for i in 26:
		var ph := fmod(_time * 0.03 + i * 0.113, 1.0)
		var p := Vector2(fmod(i * 41.0 + _time * 4.0, VIEW.x), 14 + (i * 53) % 70 - ph * 10)
		_ambient.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1.0, 0.86, 0.6, 0.15 + 0.25 * sin(_time + i)))
