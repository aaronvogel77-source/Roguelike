class_name FigureActor
extends Node2D
## One fighter on the battle stage: a pixel figure built from parts (cutout
## rig) that breathes, walks, strikes, throws, flinches and dies. Shows its
## statuses on the body (fire, blood drops, curse veil, shield bubble) and a
## thin health bar. Lives inside the low-resolution stage viewport.

const SNAP := PI / 12.0
const ARM_REST := -0.35
const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer = 0.0;
uniform float time = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (shimmer > 0.0 && lum > 0.45) {
		vec3 hue = 0.5 + 0.5 * cos(6.2831 * (time * 0.25 + UV.y * 0.6 + vec3(0.0, 0.33, 0.67)));
		c.rgb = mix(c.rgb, hue * (lum + 0.25), 0.35 * shimmer);
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
"""

static var _shader: Shader

var uid := 0
var is_enemy := false
var definition: Dictionary = {}
var snapshot: Dictionary = {}
var suit := "coins"
var ranged := false
var home_x := 0.0
## Rig pose, read every frame.
var bob := 0.0
var step := 0.0
var arm := 0.0
var walking := false
var dead := false

var _parts: Dictionary = {}
var _sprites: Dictionary = {}
var _ghost := false
var _rig: Node2D
var _fx: Node2D
var _material: ShaderMaterial
var _time := 0.0
var _height := 40.0
var _sparkle := 0  # 0 none, 1 light (F3), 2 strong (recipes)


func setup(unit_definition: Dictionary, unit_snapshot: Dictionary, enemy: bool) -> void:
	definition = unit_definition
	snapshot = unit_snapshot
	is_enemy = enemy
	uid = int(unit_snapshot["uid"])
	suit = String(unit_snapshot.get("suit", unit_definition.get("suit", "coins")))
	ranged = FigureArt.is_ranged(String(unit_definition.get("id", "")))
	var look := FigureArt.look_for_enemy(unit_definition) if enemy else FigureArt.look_for_figure(unit_definition)
	_parts = FigureArt.build(look)
	_ghost = _parts.has("ghost")
	_height = float(_parts["dim"]["H"])
	var stage := int(unit_definition.get("fusion", {}).get("stage", 0))
	_sparkle = 2 if look.get("shimmer", false) else (1 if stage >= 3 else 0)

	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter("shimmer", 1.0 if look.get("shimmer", false) else 0.0)

	_rig = Node2D.new()
	_rig.material = _material
	add_child(_rig)
	if enemy:
		_rig.scale.x = -1  # enemies face left
	var order := ["ghost"] if _ghost else ["cape", "armB", "shield", "legB", "legF", "torso", "head", "armF", "weapon"]
	for key in order:
		if not _parts.has(key):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = _parts[key]["tex"]
		sprite.centered = false
		sprite.offset = -Vector2(_parts[key]["pivot"])
		sprite.use_parent_material = true
		_rig.add_child(sprite)
		_sprites[key] = sprite
	_fx = Node2D.new()
	_fx.z_index = 1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_pose()


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("time", _time)
	bob = -1.0 if sin(_time * 2.4 + home_x) > 0.3 and not walking and not dead else 0.0
	step = sin(_time * 22.0) if walking else 0.0
	_pose()
	_fx.queue_redraw()


func _pose() -> void:
	if _ghost:
		_sprites["ghost"].position = Vector2(0, round(sin(_time * 3.0 + home_x) * 1.5))
		return
	var d: Dictionary = _parts["dim"]
	var hip_y := -float(d["leg"]) + bob
	var neck_y := hip_y - float(_parts["torso_h"])
	var half := float(int(d["tw"]) / 2)
	var arm_len := float(_parts["arm_len"])
	if _sprites.has("cape"):
		_place("cape", Vector2(-half + 4, neck_y + 1), 0.05 + step * 0.06)
	var back_angle := 0.25 - step * 0.5
	_place("armB", Vector2(-half + 3, neck_y + 3), back_angle)
	if _sprites.has("shield"):
		var sa := _snap(back_angle)
		_place("shield", Vector2(-half + 3 - sin(sa) * (arm_len - 2), neck_y + 3 + cos(sa) * (arm_len - 2)), 0.0)
	_place("legB", Vector2(-2, hip_y), step * 0.5)
	_place("legF", Vector2(1, hip_y), -step * 0.5)
	_place("torso", Vector2(0, hip_y), 0.0)
	_place("head", Vector2(1, neck_y + 1), 0.0)
	var shoulder := Vector2(half - 2, neck_y + 3)
	var a := _snap(ARM_REST + arm + step * 0.45)
	_place("armF", shoulder, a)
	var hand := shoulder + Vector2(-sin(a) * arm_len, cos(a) * arm_len)
	_place("weapon", hand, a - ARM_REST)


func _place(key: String, at: Vector2, angle: float) -> void:
	var sprite: Sprite2D = _sprites[key]
	sprite.position = at.round()
	sprite.rotation = _snap(angle)


func _snap(angle: float) -> float:
	return round(angle / SNAP) * SNAP


## Where projectiles start (the front hand, in stage coordinates).
func hand_position() -> Vector2:
	if _ghost or not _sprites.has("weapon"):
		return position + Vector2(0, -_height * 0.6)
	var local: Vector2 = _sprites["weapon"].position
	return position + Vector2(local.x * _rig.scale.x, local.y)


func center() -> Vector2:
	return position + Vector2(0, -_height * 0.55)


func top() -> Vector2:
	return position + Vector2(0, -_height - 4)


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-12, -_height - 4), Vector2(24, _height + 8))


func apply_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot


# --- Actions (durations in seconds at speed 1, divided by the playback speed) ---

func run_to(x: float, duration: float) -> void:
	walking = true
	var tween := create_tween()
	tween.tween_property(self, "position:x", x, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: walking = false)


func wind_up(duration: float) -> void:
	create_tween().tween_property(self, "arm", 2.6, duration)


func strike(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "arm", -1.1, duration * 0.4)
	tween.tween_interval(duration * 0.3)
	tween.tween_property(self, "arm", 0.0, duration * 0.3)


func throw_motion(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "arm", 2.2, duration * 0.5)
	tween.tween_property(self, "arm", -1.3, duration * 0.2)
	tween.tween_property(self, "arm", 0.0, duration * 0.3)


func raise_weapon(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "arm", -2.6, duration * 0.3)
	tween.tween_interval(duration * 0.5)
	tween.tween_property(self, "arm", 0.0, duration * 0.2)


## Flash white and get knocked back a little.
func hit(duration: float) -> void:
	_material.set_shader_parameter("flash", 0.85)
	var back := 3.0 if is_enemy else -3.0
	var tween := create_tween()
	tween.tween_property(_rig, "position:x", back, duration * 0.3)
	tween.parallel().tween_method(func(v: float) -> void: _material.set_shader_parameter("flash", v), 0.85, 0.0, duration)
	tween.tween_property(_rig, "position:x", 0.0, duration * 0.4)


func shake(duration: float) -> void:
	var tween := create_tween()
	for offset in [-2.0, 2.0, -1.0, 0.0]:
		tween.tween_property(_rig, "position:x", offset, duration / 4.0)


## Glow in a color (abilities acting on this figure).
func glow(color: Color, duration: float) -> void:
	_rig.modulate = Color(1.0 + color.r * 0.6, 1.0 + color.g * 0.6, 1.0 + color.b * 0.6)
	create_tween().tween_property(_rig, "modulate", Color.WHITE, duration)


## Death depends on the suit: coins burst into gold, wands burn, cups melt,
## swords shatter; enemies dissolve into smoke or wisps.
func die(duration: float) -> void:
	dead = true
	_death_time = _time
	_death_duration = duration
	var tween := create_tween()
	match _death_style():
		"cups":  # melts down
			tween.tween_property(_rig, "scale:y", 0.15, duration)
			tween.parallel().tween_property(_rig, "modulate", Color(0.4, 0.6, 1.0, 0.0), duration)
		"wands":  # burns to cinders
			tween.tween_property(_rig, "modulate", Color(0.15, 0.08, 0.05, 1.0), duration * 0.6)
			tween.tween_property(_rig, "modulate:a", 0.0, duration * 0.4)
		"swords":  # shatters: parts fall apart
			for key in _sprites:
				var sprite: Sprite2D = _sprites[key]
				var dir := Vector2(randf_range(-10, 10), randf_range(-6, 2))
				tween.parallel().tween_property(sprite, "position", sprite.position + dir + Vector2(0, 14), duration)
				tween.parallel().tween_property(sprite, "rotation", sprite.rotation + randf_range(-1.5, 1.5), duration)
			tween.parallel().tween_property(_rig, "modulate:a", 0.0, duration)
		_:  # coins burst into gold, enemies fade out
			tween.tween_property(_rig, "modulate", Color(1.6, 1.3, 0.5, 0.0), duration)
	await tween.finished


func revive(duration: float) -> void:
	dead = false
	_rig.scale.y = 1.0
	_rig.modulate = Color(2.0, 2.0, 2.0, 0.0)
	create_tween().tween_property(_rig, "modulate", Color.WHITE, duration)


var _death_time := -1.0
var _death_duration := 0.5


func _death_style() -> String:
	if is_enemy:
		return "enemy"
	return suit


# --- Effects drawn on the figure (pixel rectangles in stage space) ---

func _draw_fx() -> void:
	var statuses: Dictionary = snapshot.get("statuses", {})
	var h := _height
	if not dead:
		# Thin health bar under the feet.
		var max_health: int = maxi(int(snapshot.get("max_health", 1)), 1)
		var health: int = clampi(int(snapshot.get("health", max_health)), 0, max_health)
		var width := 16.0
		_fx.draw_rect(Rect2(-width / 2 - 1, 3, width + 2, 3), PixelCanvas.OUTLINE)
		_fx.draw_rect(Rect2(-width / 2, 4, width * health / max_health, 1), Color("c0303a") if is_enemy else Color("3fbf5a"))
		if int(statuses.get("shield", 0)) > 0:  # light bowl in front
			var dir := -1.0 if is_enemy else 1.0
			for i in 12:
				var a := -PI / 2 + i / 11.0 * PI
				_fx.draw_rect(Rect2(Vector2(dir * (10 + cos(a) * 4), -h * 0.5 + sin(a) * h * 0.45).round(), Vector2(1, 2)), Color(0.75, 0.85, 1.0, 0.75))
		if int(statuses.get("curse", 0)) > 0:  # violet veil
			for i in 6:
				var ph := fmod(_time * 0.6 + i / 6.0, 1.0)
				_fx.draw_rect(Rect2(Vector2(-8 + (i * 5) % 16, -h * 0.9 + ph * h * 0.6).round(), Vector2(1, 2)), Color(0.7, 0.4, 0.9, 0.8 * (1.0 - ph)))
		if int(statuses.get("burn", 0)) > 0:
			_flames(h)
		if int(statuses.get("bleed", 0)) > 0:
			for i in 3:
				var ph := fmod(_time * 1.2 + i / 3.0, 1.0)
				_fx.draw_rect(Rect2(Vector2(-4 + i * 4, -h * 0.55 + ph * h * 0.5).round(), Vector2(1, 2)), Color(0.85, 0.1, 0.18, 1.0 - ph))
		if _sparkle > 0:
			var n := 3 if _sparkle == 1 else 7
			for i in n:
				var ph := fmod(_time * 1.1 + i * 0.37, 1.0)
				if ph > 0.45:
					continue
				var p := Vector2(-10 + (i * 53) % 21, -4 - (i * 37) % int(h))
				var col := Color("fff8d0") if _sparkle == 1 else Color.from_hsv(fmod(i * 0.13 + _time * 0.3, 1.0), 0.5, 1.0)
				_fx.draw_rect(Rect2(p, Vector2.ONE), col)
				if ph < 0.15:
					_fx.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), col)
					_fx.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), col)
	elif _death_time >= 0.0:
		var q := clampf((_time - _death_time) / maxf(_death_duration, 0.05), 0.0, 1.0)
		match _death_style():
			"coins":
				for i in 14:
					var a := i / 14.0 * TAU
					var p := Vector2(cos(a), sin(a) * 0.7 - 0.6) * q * 22 + Vector2(0, -h * 0.5 + q * q * 20)
					_fx.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color("ffd24a") if i % 2 else Color("fff4b8"))
			"wands":
				_flames(h * (1.0 - q))
			"cups":
				for i in 6:
					_fx.draw_rect(Rect2(Vector2(-8 + i * 3, -2 + q * 2).round(), Vector2(2, 1)), Color(0.3, 0.55, 0.95, 1.0 - q))
			_:
				for i in 14:
					var p := Vector2(-8 + (i * 7) % 17 + sin(q * 6 + i) * 2, -6 - (i * 5) % int(maxf(h * 0.7, 1)) - q * 26)
					_fx.draw_rect(Rect2(p.round(), Vector2(1, 2)), Color(0.62, 0.94, 1.0, 1.0 - q) if _ghost else Color(0.35, 0.3, 0.35, 1.0 - q))
	# A soul rises from fallen player figures.
	if dead and not is_enemy and _death_time >= 0.0:
		var q := clampf((_time - _death_time) / 1.2, 0.0, 1.0)
		if q < 1.0:
			_fx.draw_rect(Rect2(Vector2(-1, -h * 0.6 - q * 30).round(), Vector2(2, 3)), Color(0.6, 0.85, 1.0, 1.0 - q))


func _flames(h: float) -> void:
	for i in 9:
		var ph := fmod(_time * 1.8 + i * 0.17, 1.0)
		var p := Vector2(-6 + (i * 7) % 13 + sin(ph * 8 + i), -4 - ph * h * 0.7)
		var col := Color("fff2a0") if ph < 0.3 else (Color("ffa030") if ph < 0.6 else Color("d8401a"))
		col.a = 1.0 - ph * 0.8
		_fx.draw_rect(Rect2(p.round(), Vector2(2 if ph < 0.4 else 1, 2)), col)
