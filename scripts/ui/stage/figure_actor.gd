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
## Creatures (enemies) are one sprite: where they throw from, whether they hover.
var _creature_hand := Vector2(8, -20)
var _floating := false
var _wispy := false
var _revive_time := -1.0


func setup(unit_definition: Dictionary, unit_snapshot: Dictionary, enemy: bool) -> void:
	definition = unit_definition
	snapshot = unit_snapshot
	is_enemy = enemy
	uid = int(unit_snapshot["uid"])
	suit = String(unit_snapshot.get("suit", unit_definition.get("suit", "coins")))
	ranged = FigureArt.is_ranged(String(unit_definition.get("id", "")))
	var id := String(unit_definition.get("id", ""))
	var look := {}
	if enemy and CreatureArt.has_art(id):
		var art := CreatureArt.build(id)
		_parts = {"ghost": art["body"], "dim": {"H": art["H"], "tw": art["W"], "leg": 0}}
		_creature_hand = art["hand"]
		_floating = art["float"]
		_wispy = id in ["beggar_ghost", "the_changer", "mirror_coin"]
	else:
		look = FigureArt.look_for_enemy(unit_definition) if enemy else FigureArt.look_for_figure(unit_definition)
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
		# One-sprite creatures: hover or hop, lean into attacks.
		var sprite: Sprite2D = _sprites["ghost"]
		var y: float = round(sin(_time * 3.0 + home_x) * 1.5) - 2.0 if _floating else bob
		if walking:
			y -= absf(step) * 2.0
		sprite.position = Vector2(0, y)
		sprite.rotation = _snap(clampf(-arm * 0.2, -0.35, 0.35))
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
		return position + Vector2(_creature_hand.x * _rig.scale.x, _creature_hand.y)
	var local: Vector2 = _sprites["weapon"].position
	return position + Vector2(local.x * _rig.scale.x, local.y)


## How much room the figure needs in its row (wide creatures need more).
func footprint() -> float:
	return maxf(24.0, float(_parts["dim"]["tw"]) * 0.62) if _ghost else 24.0


func center() -> Vector2:
	return position + Vector2(0, -_height * 0.55)


func top() -> Vector2:
	return position + Vector2(0, -_height - 4)


func hit_rect() -> Rect2:
	var half := clampf(float(_parts["dim"]["tw"]) * 0.5, 10.0, 40.0) if _ghost else 12.0
	return Rect2(position + Vector2(-half, -_height - 12), Vector2(half * 2.0, _height + 26))


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


## Collapses, then a beam of light lifts the figure back up.
func revive(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rig, "rotation", -1.3 if not is_enemy else 1.3, duration * 0.25)
	tween.parallel().tween_property(_rig, "modulate", Color(0.35, 0.35, 0.4), duration * 0.25)
	tween.tween_callback(func() -> void:
		_revive_time = _time
		_revive_duration = duration * 0.75)
	tween.tween_property(_rig, "rotation", 0.0, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_rig, "modulate", Color(2.0, 2.0, 1.8), duration * 0.3)
	tween.tween_property(_rig, "modulate", Color.WHITE, duration * 0.3)
	await tween.finished
	dead = false


var _revive_duration := 0.5


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
	if _revive_time >= 0.0:
		var q := (_time - _revive_time) / maxf(_revive_duration, 0.05)
		if q < 1.0:  # beam of light and a soul sinking back in
			var a := 1.0 - q
			_fx.draw_rect(Rect2(-3, -140, 6, 140), Color(1.0, 0.95, 0.75, 0.35 * a))
			_fx.draw_rect(Rect2(-1, -140, 2, 140), Color(1.0, 1.0, 0.9, 0.7 * a))
			_fx.draw_rect(Rect2(Vector2(-1, -h - 30 + q * (h + 10)).round(), Vector2(2, 3)), Color(0.6, 0.85, 1.0, a))
	if not dead:
		# Thin health bar, then attack and health as numbers under the feet.
		var max_health: int = maxi(int(snapshot.get("max_health", 1)), 1)
		var health: int = clampi(int(snapshot.get("health", max_health)), 0, max_health)
		var width := 18.0
		_fx.draw_rect(Rect2(-width / 2 - 1, 2, width + 2, 3), PixelCanvas.OUTLINE)
		_fx.draw_rect(Rect2(-width / 2, 3, width * health / max_health, 1), Color("c0303a") if is_enemy else Color("3fbf5a"))
		_draw_stats(int(snapshot.get("effective_attack", 0)), health)
		_draw_statuses(statuses, h)
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
					_fx.draw_rect(Rect2(p.round(), Vector2(1, 2)), Color(0.62, 0.94, 1.0, 1.0 - q) if _wispy else Color(0.35, 0.3, 0.35, 1.0 - q))
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


# --- Pixel numbers and status icons ---------------------------------------------------

const DIGITS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
	"8": "111101111101111", "9": "111101111001111",
}
## 5x5 icons for statuses (rows top to bottom).
const ICONS := {
	"burn": ["00100", "01100", "01110", "11111", "01110"],
	"bleed": ["00100", "00100", "01110", "01110", "00100"],
	"curse": ["01110", "10001", "10101", "10001", "01110"],
	"shield": ["11111", "10101", "11111", "01110", "00100"],
	"attack": ["001", "010", "100"],
	"health": ["101", "111", "010"],
}
const STATUS_COLORS := {"burn": Color("ff8a2a"), "bleed": Color("e0263a"), "curse": Color("b06ae8"), "shield": Color("a8c4ea")}


func _number_width(value: int) -> int:
	return str(value).length() * 4 - 1


func _draw_number(value: int, at: Vector2, color: Color) -> void:
	var x := at.x
	for ch in str(value):
		var pattern: String = DIGITS.get(ch, "")
		for i in pattern.length():
			if pattern[i] == "1":
				_fx.draw_rect(Rect2(x + i % 3, at.y + i / 3, 1, 1), color)
		x += 4


func _draw_icon(kind: String, at: Vector2, color: Color) -> void:
	var rows: Array = ICONS[kind]
	for y in rows.size():
		for x in String(rows[y]).length():
			if rows[y][x] == "1":
				_fx.draw_rect(Rect2(at.x + x, at.y + y, 1, 1), color)


## Attack (red) and health (green) under the feet, each with a tiny icon.
func _draw_stats(attack: int, health: int) -> void:
	var attack_w := 4 + _number_width(attack)
	var health_w := 4 + _number_width(health)
	var total := attack_w + 3 + health_w
	var x := -float(total) / 2.0
	_fx.draw_rect(Rect2(x - 2, 6, total + 4, 8), Color(0.03, 0.02, 0.04, 0.85))
	_draw_icon("attack", Vector2(x, 8), Color("ff6a5a"))
	_draw_number(attack, Vector2(x + 4, 7), Color("ff8a7a"))
	x += attack_w + 3
	_draw_icon("health", Vector2(x, 8), Color("5fd06a"))
	_draw_number(health, Vector2(x + 4, 7), Color("8ef09a"))


## Status icons with their stack count above the head.
func _draw_statuses(statuses: Dictionary, h: float) -> void:
	var entries: Array = []
	for kind in ["shield", "burn", "bleed", "curse"]:
		if int(statuses.get(kind, 0)) > 0:
			entries.append([kind, int(statuses[kind])])
	if entries.is_empty():
		return
	var widths: Array = entries.map(func(e: Array) -> int: return 6 + _number_width(e[1]))
	var total := 0
	for w in widths:
		total += w + 2
	total -= 2
	var x := -float(total) / 2.0
	var y := -h - 11.0
	_fx.draw_rect(Rect2(x - 2, y - 1, total + 4, 8), Color(0.03, 0.02, 0.04, 0.8))
	for i in entries.size():
		var kind: String = entries[i][0]
		_draw_icon(kind, Vector2(x, y + 0), STATUS_COLORS[kind])
		_draw_number(entries[i][1], Vector2(x + 6, y + 0), Color.WHITE)
		x += widths[i] + 2
