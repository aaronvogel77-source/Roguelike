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


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var background := Sprite2D.new()
	background.texture = FigureArt.vault(VIEW.x, VIEW.y, FLOOR - 4)
	background.centered = false
	_viewport.add_child(background)
	_ambient = Node2D.new()
	_ambient.draw.connect(_draw_ambient)
	_viewport.add_child(_ambient)
	_actors_layer = Node2D.new()
	_actors_layer.y_sort_enabled = false
	_viewport.add_child(_actors_layer)
	_shots_layer = Node2D.new()
	_viewport.add_child(_shots_layer)

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


# --- Setup and layout -----------------------------------------------------------------

func setup(start_event: Dictionary, db: ContentDb) -> void:
	_db = db
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
