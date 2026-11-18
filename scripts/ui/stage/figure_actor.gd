class_name FigureActor
extends Node2D
## One fighter on the battle stage: a pixel figure built from parts (cutout
## rig) that breathes, walks, strikes, throws, flinches and dies. Shows its
## statuses on the body (fire, blood drops, curse veil, shield bubble) and a
## thin health bar. Lives inside the low-resolution stage viewport.

const SNAP := PI / 12.0
const ARM_REST := -0.35
## Weapons lean slightly forward at rest and are drawn behind the head, so
## long ones (tridents, greatswords, axes) never cover a face.
const WEAPON_TILT := PI / 12.0
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
## Portrait on a card: only the figure, no bars, numbers or effects.
var portrait := false
## Showcase (legendary reveal): the figure with its skin effects, no bars.
var showcase := false
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
## Fusions: aura in the two main suit colours, stronger per stage; pure
## fusions (3+ of one suit on F3) carry their suit symbol above the head.
var _aura: Node2D
var _fusion_stage := 0
var _aura_colors: Array = []
var _pure_suit := ""
## Legendary skin effect theme ("hellfire", "frost", "void", "sun") or "".
var fx_theme := ""
var _strike_time := -1.0


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
	_fusion_stage = stage
	fx_theme = String(look.get("fx", "")) if not enemy else ""
	if stage > 0:
		var counts := {}
		var order: Array = []
		for s in unit_definition["fusion"].get("suits", []):
			if not counts.has(s):
				order.append(s)
			counts[s] = counts.get(s, 0) + 1
		order.sort_custom(func(x: String, y: String) -> bool: return counts[x] > counts[y])
		for s in order.slice(0, 2):
			_aura_colors.append(Color(FigureArt.GEMS.get(s, "ffffff")).lightened(0.25))
		if not Cosmetics.aura_colors().is_empty():
			_aura_colors = Cosmetics.aura_colors()
		if stage >= 3 and counts[order[0]] >= 3:
			_pure_suit = order[0]
	if stage > 0 or fx_theme != "":
		_aura = Node2D.new()
		_aura.draw.connect(_draw_aura)
		add_child(_aura)  # added before the rig, so it is drawn behind the figure

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
	var order := ["ghost"] if _ghost else ["cape", "armB", "shield", "legB", "legF", "torso", "weapon", "head", "armF"]
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
	# Faces are never covered: the head is drawn over every weapon. Small
	# things held in the hand (orb, pouch, chalice) also stay in front of the arm.
	if _sprites.has("weapon") and _sprites["weapon"].texture.get_height() <= 18:
		_rig.move_child(_sprites["weapon"], -1)
	if _sprites.has("head"):
		_rig.move_child(_sprites["head"], -1)
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
	if _aura != null:
		_aura.queue_redraw()


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
	_place("weapon", hand, a - ARM_REST + WEAPON_TILT)


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
	_strike_time = _time + duration * 0.3
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
		"skin_hellfire":  # glows like lava, then crumbles to ash
			tween.tween_property(_rig, "modulate", Color(2.2, 0.9, 0.3, 1.0), duration * 0.35)
			tween.tween_property(_rig, "modulate", Color(0.1, 0.06, 0.05, 0.0), duration * 0.65)
		"skin_frost":  # freezes solid and shatters into shards
			tween.tween_property(_rig, "modulate", Color(1.4, 1.8, 2.4, 1.0), duration * 0.35)
			for key in _sprites:
				var sprite: Sprite2D = _sprites[key]
				var dir := Vector2(randf_range(-14, 14), randf_range(-10, 0))
				tween.parallel().tween_property(sprite, "position", sprite.position + dir + Vector2(0, 16), duration * 0.65).set_delay(duration * 0.35)
			tween.tween_property(_rig, "modulate:a", 0.0, duration * 0.3)
		"skin_void":  # collapses into a point of darkness
			tween.tween_property(_rig, "modulate", Color(0.6, 0.3, 1.2, 1.0), duration * 0.3)
			tween.tween_property(_rig, "scale", Vector2(0.05 * signf(_rig.scale.x), 0.05), duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		"skin_sun":  # dissolves into light and rises
			tween.tween_property(_rig, "modulate", Color(3.0, 2.6, 1.6, 1.0), duration * 0.4)
			tween.parallel().tween_property(_rig, "position:y", -12.0, duration)
			tween.tween_property(_rig, "modulate:a", 0.0, duration * 0.6)
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
	if fx_theme != "":
		return "skin_" + fx_theme
	return suit


# --- Effects drawn on the figure (pixel rectangles in stage space) ---

func _draw_fx() -> void:
	if showcase:
		if fx_theme != "":
			_draw_skin_front()
		return
	if portrait:
		return
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
		# Values raised by positive effects (equipment, relics, abilities) glow yellow.
		var level := int(snapshot.get("level", 1))
		var base_attack := int(definition.get("attack", 0)) + level - 1
		var base_health := int(definition.get("health", 0)) + level - 1
		_draw_stats(int(snapshot.get("effective_attack", 0)), health,
			int(snapshot.get("effective_attack", 0)) > base_attack, max_health > base_health)
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
		if fx_theme != "":
			_draw_skin_front()
	elif _death_time >= 0.0:
		var q := clampf((_time - _death_time) / maxf(_death_duration, 0.05), 0.0, 1.0)
		match _death_style():
			"skin_hellfire":
				for i in 18:
					var p := Vector2(-8 + (i * 7) % 17 + sin(q * 5 + i) * 3, -4 - (i * 9) % int(maxf(h, 1)) * (1.0 - q * 0.3) - q * 30)
					_fx.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color("ffb040") if i % 3 else Color("ff4010", 1.0 - q))
			"skin_frost":
				for i in 16:
					var a := i / 16.0 * TAU
					var p := Vector2(cos(a) * q * 26, -h * 0.5 + sin(a) * q * 18 + q * q * 18)
					_fx.draw_rect(Rect2(p.round(), Vector2(2, 1) if i % 2 else Vector2(1, 2)), Color(0.75, 0.9, 1.0, 1.0 - q))
			"skin_void":
				var radius := (1.0 - q) * 24.0
				for i in 20:
					var a := i / 20.0 * TAU + q * 4.0
					_fx.draw_rect(Rect2(Vector2(cos(a) * radius, -h * 0.5 + sin(a) * radius * 0.8).round(), Vector2.ONE), Color(0.75, 0.45, 1.0, 1.0 - q * 0.5))
				if q > 0.85:
					_fx.draw_rect(Rect2(-2, -h * 0.5 - 2, 4, 4), Color(1, 1, 1, (1.0 - q) * 6.0))
			"skin_sun":
				_fx.draw_rect(Rect2(-4, -160, 8, 160), Color(1.0, 0.9, 0.5, 0.35 * (1.0 - q)))
				for i in 16:
					var p := Vector2(-8 + (i * 5) % 17, -2 - (i * 11) % int(maxf(h, 1)) - q * 40)
					_fx.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1.0, 0.95, 0.6, 1.0 - q))
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
func _draw_stats(attack: int, health: int, attack_up := false, health_up := false) -> void:
	var attack_w := 4 + _number_width(attack)
	var health_w := 4 + _number_width(health)
	var total := attack_w + 3 + health_w
	var x := -float(total) / 2.0
	_fx.draw_rect(Rect2(x - 2, 6, total + 4, 8), Color(0.03, 0.02, 0.04, 0.85))
	_draw_icon("attack", Vector2(x, 8), Color("ff6a5a"))
	_draw_number(attack, Vector2(x + 4, 7), Color("ffe84a") if attack_up else Color("ff8a7a"))
	x += attack_w + 3
	_draw_icon("health", Vector2(x, 8), Color("5fd06a"))
	_draw_number(health, Vector2(x + 4, 7), Color("ffe84a") if health_up else Color("8ef09a"))


## The battle screen draws statuses as large icons itself; then the pixel ones are off.
static var draw_status_icons := true


## Status icons with their stack count above the head.
func _draw_statuses(statuses: Dictionary, h: float) -> void:
	if not draw_status_icons:
		return
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


# --- Fusion aura and the pure suit symbol ---------------------------------------------

func _draw_aura() -> void:
	if dead:
		return
	if fx_theme != "":
		_draw_skin_back()
	if _aura_colors.is_empty():
		return
	var h := _height
	var n := 6 + _fusion_stage * 6
	# Rising motes around the body, alternating the two main colours.
	for i in n:
		var ph := fmod(_time * (0.35 + 0.08 * _fusion_stage) + i * 0.618, 1.0)
		var col: Color = _aura_colors[i % _aura_colors.size()]
		var x := -9.0 - _fusion_stage + float((i * 37) % (19 + _fusion_stage * 2))
		var p := Vector2(x + sin(_time * 2.0 + i) * 1.5, -2.0 - ph * (h + 6))
		col.a = (1.0 - ph * 0.8) * (0.6 + 0.13 * _fusion_stage)
		var mote := Vector2(2, 2) if i % 3 == 0 else Vector2(1, 2)
		_aura.draw_rect(Rect2(p.round(), mote), col)
	# A soft glow on the ground, wider per stage.
	var glow: Color = _aura_colors[0]
	glow.a = 0.3 + 0.1 * _fusion_stage
	var w := 14.0 + _fusion_stage * 4.0
	_aura.draw_rect(Rect2(-w / 2, -1, w, 2), glow)
	glow.a *= 0.5
	_aura.draw_rect(Rect2(-w / 2 - 3, -2, w + 6, 4), glow)
	if _pure_suit != "":
		_draw_suit_symbol(Vector2(0, -h - 10 + round(sin(_time * 2.2))))


## Pure fusions: a small glowing coin, flame, cup or blade above the head.
func _draw_suit_symbol(at: Vector2) -> void:
	var col := Color(FigureArt.GEMS.get(_pure_suit, "ffffff")).lightened(0.3)
	var light := col.lightened(0.6)
	var dark := col.darkened(0.45)
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	var rows: Array
	match _pure_suit:
		"coins":
			rows = ["..ooo..", ".o###o.", "o##+##o", "o#+++#o", "o##+##o", ".o###o.", "..ooo.."]
		"wands":
			rows = ["...#...", "..##...", "..#+#..", ".#+#+#.", "##+++##", "#++++##", ".#####."]
		"cups":
			rows = ["#######", "#++++#.", ".#+++#.", "..###..", "...#...", "...#...", ".#####."]
		_:
			rows = ["...#...", "..#+#..", "..#+#..", "..#+#..", "#######", "...o...", "...#..."]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c: Color
			match row[x]:
				"#":
					c = col
				"+":
					c = light.lerp(Color.WHITE, pulse * 0.4)
				"o":
					c = dark
				_:
					continue
			_aura.draw_rect(Rect2(at + Vector2(x - 3, y - 3), Vector2.ONE), c)
	# Little rays flicker around the symbol.
	var ray := col
	ray.a = 0.35 + 0.35 * pulse
	for d in [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -5)]:
		_aura.draw_rect(Rect2(at + d, Vector2.ONE), ray)


# --- Legendary skin effects --------------------------------------------------------------

## Where the top of the head is (stage space relative to the actor).
func _head_top() -> Vector2:
	var head: Sprite2D = _sprites["head"]
	var p := head.position + Vector2(1, -float(_parts["dim"]["head"]) - 2)
	return Vector2(p.x * _rig.scale.x, p.y)


## The tip of the weapon (rotates with the arm).
func _weapon_tip() -> Vector2:
	var weapon: Sprite2D = _sprites["weapon"]
	var reach := float(weapon.texture.get_height()) - float(_parts["weapon"]["pivot"].y)
	var p := weapon.position + Vector2(0, -reach).rotated(weapon.rotation)
	return Vector2(p.x * _rig.scale.x, p.y)


func _fx_color(index: int) -> Color:
	return Color(FigureArt.FX_COLORS[fx_theme][index])


## Behind the figure: heat, cold mist, a nebula, sun rays.
func _draw_skin_back() -> void:
	var h := _height
	var pulse := 0.5 + 0.5 * sin(_time * 2.6)
	match fx_theme:
		"hellfire":
			_aura.draw_rect(Rect2(-12, -2, 24, 3), Color(1.0, 0.35, 0.05, 0.25 + 0.15 * pulse))
			_aura.draw_rect(Rect2(-8, -3, 16, 1), Color(1.0, 0.6, 0.1, 0.35 * pulse))
		"frost":
			for i in 10:
				var ph := fmod(_time * 0.15 + i * 0.1, 1.0)
				_aura.draw_rect(Rect2(Vector2(-16 + ph * 32, -1 - (i % 3)).round(), Vector2(3, 1)), Color(0.8, 0.9, 1.0, 0.25 * sin(ph * PI)))
		"void":
			for i in 14:
				var a := i / 14.0 * TAU + _time * 0.4
				var r := 13.0 + 2.0 * sin(_time * 1.5 + i)
				_aura.draw_rect(Rect2(Vector2(cos(a) * r, -h * 0.55 + sin(a) * r * 1.4).round(), Vector2.ONE), Color(0.55, 0.3, 0.95, 0.35 + 0.25 * sin(_time * 3 + i)))
		"sun":
			var head := _head_top() + Vector2(0, 6)
			for i in 12:
				var a := i / 12.0 * TAU + _time * 0.3
				var length := 10.0 + 4.0 * pulse + (3.0 if i % 2 == 0 else 0.0)
				for r in range(6, int(length)):
					_aura.draw_rect(Rect2((head + Vector2(cos(a), sin(a)) * r).round(), Vector2.ONE), Color(1.0, 0.88, 0.4, 0.45 * (1.0 - float(r) / length)))


## In front: flames on the helm and axe, snowflakes and frost breath,
## orbiting runes and twinkling stars, golden sparks; plus the theme's
## weapon trail right after a strike.
func _draw_skin_front() -> void:
	var h := _height
	var head := _head_top()
	var tip := _weapon_tip()
	match fx_theme:
		"hellfire":
			for i in 7:  # flames licking up from the helm spikes and the axe
				var ph := fmod(_time * 2.2 + i * 0.37, 1.0)
				var base := head + Vector2(-5 + i * 2, -2) if i < 5 else tip + Vector2(i - 5, 0)
				var col := Color("fff0a0") if ph < 0.25 else (Color("ff9a20") if ph < 0.6 else Color("e04010"))
				col.a = 1.0 - ph
				_fx.draw_rect(Rect2((base + Vector2(sin(_time * 9 + i), -ph * 6)).round(), Vector2.ONE), col)
			for i in 5:  # embers rising from the body
				var ph := fmod(_time * 0.5 + i * 0.21, 1.0)
				_fx.draw_rect(Rect2(Vector2(-6 + (i * 5) % 13 + sin(_time * 3 + i) * 2, -4 - ph * (h + 10)).round(), Vector2.ONE), Color(1.0, 0.55, 0.1, 1.0 - ph))
		"frost":
			for i in 9:  # snowflakes drifting down around the king
				var ph := fmod(_time * 0.22 + i * 0.113, 1.0)
				var p := Vector2(-16 + (i * 37) % 33 + sin(_time * 1.3 + i) * 3, -h - 14 + ph * (h + 14))
				_fx.draw_rect(Rect2(p.round(), Vector2.ONE), Color(0.92, 0.97, 1.0, 0.9 * sin(ph * PI)))
				if i % 3 == 0:
					_fx.draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(3, 1)), Color(0.85, 0.93, 1.0, 0.5 * sin(ph * PI)))
			var breath := fmod(_time * 0.45, 1.0)  # frost breath
			if breath < 0.4:
				var dir := -1.0 if is_enemy else 1.0
				for i in 4:
					_fx.draw_rect(Rect2((head + Vector2(dir * (5 + breath * 20 + i * 2), 8 + i % 2)).round(), Vector2(2, 1)), Color(0.85, 0.95, 1.0, 0.6 * (1.0 - breath / 0.4)))
			if fmod(_time, 1.6) < 0.15:  # glint on the crown
				_fx.draw_rect(Rect2(head + Vector2(-1, -4), Vector2(3, 1)), Color.WHITE)
				_fx.draw_rect(Rect2(head + Vector2(0, -5), Vector2(1, 3)), Color.WHITE)
		"void":
			for i in 3:  # runes circling the head
				var a := _time * 1.2 + i * TAU / 3.0
				var p := (head + Vector2(cos(a) * 10, 4 + sin(a) * 3)).round()
				var col := Color(0.8, 0.55, 1.0, 0.6 + 0.4 * sin(a))
				_fx.draw_rect(Rect2(p, Vector2(1, 3)), col)
				_fx.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(3, 1)), col)
			for i in 6:  # stars twinkling around the body
				var ph := fmod(_time * 0.7 + i * 0.29, 1.0)
				if ph < 0.3:
					var p := Vector2(-14 + (i * 41) % 29, -6 - (i * 23) % int(h))
					_fx.draw_rect(Rect2(p, Vector2.ONE), Color(0.95, 0.9, 1.0))
					if ph < 0.1:
						_fx.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Color(0.85, 0.7, 1.0, 0.7))
		"sun":
			for i in 8:  # golden sparks drifting upwards
				var ph := fmod(_time * 0.4 + i * 0.125, 1.0)
				var p := Vector2(-14 + (i * 29) % 29 + sin(_time * 2 + i) * 2, -2 - ph * (h + 16))
				_fx.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1.0, 0.85 + 0.15 * (i % 2), 0.35 + 0.4 * (i % 2), 1.0 - ph))
			if fmod(_time + 0.4, 1.3) < 0.12:
				_fx.draw_rect(Rect2(tip + Vector2(-2, 0), Vector2(5, 1)), Color.WHITE)
				_fx.draw_rect(Rect2(tip + Vector2(0, -2), Vector2(1, 5)), Color.WHITE)
	# Weapon trail and impact sparks in the theme colours, right after a strike.
	var since := _time - _strike_time
	if _strike_time >= 0.0 and since >= 0.0 and since < 0.35:
		var q := since / 0.35
		var dir := -1.0 if is_enemy else 1.0
		var main := _fx_color(0)
		var light := _fx_color(1)
		for i in 14:  # a bright arc in front of the figure
			var a := -1.4 + i / 13.0 * 2.2
			var p := Vector2(dir * (6 + cos(a) * 14), -h * 0.55 + sin(a) * 16)
			var col := light if i % 3 == 0 else main
			col.a = 1.0 - q
			_fx.draw_rect(Rect2(p.round(), Vector2(2, 2) if i % 2 else Vector2.ONE), col)
		for i in 10:  # impact burst
			var a := i / 10.0 * TAU
			var p := Vector2(dir * 20, -h * 0.5) + Vector2(cos(a), sin(a)) * q * 12
			var col := light if i % 2 else main
			col.a = 1.0 - q
			_fx.draw_rect(Rect2(p.round(), Vector2.ONE), col)

