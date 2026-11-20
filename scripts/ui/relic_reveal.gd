class_name RelicReveal
extends Control
## A found relic (grave chamber): a chest opens, the relic rises in a glow,
## then flies to its place in the relic row. About two seconds; a tap skips.

signal done

const CHEST := Vector2(220, 150)

var _lid_open := 0.0  # 0 closed .. 1 open
var _glow := 0.0
var _card: Control
var _target := Vector2.ZERO


static func play(parent: Control, db: ContentDb, relic_id: String, target: Vector2) -> RelicReveal:
	var reveal := RelicReveal.new()
	reveal._target = target
	parent.add_child(reveal)
	reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reveal._card = ObjectCard.create(db, {"kind": "relic", "id": relic_id}, Vector2(150, 222))
	reveal._card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal._card.modulate.a = 0.0
	reveal.add_child(reveal._card)
	reveal._run.call_deferred()
	return reveal


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()


func _chest_rect() -> Rect2:
	return Rect2(size / 2 - CHEST / 2 + Vector2(0, 80), CHEST)


func _run() -> void:
	var chest := _chest_rect()
	_card.position = chest.get_center() - _card.size / 2
	_card.scale = Vector2(0.4, 0.4)
	_card.pivot_offset = _card.size / 2
	Sound.play("chest", -4.0)
	var tween := create_tween()
	tween.tween_method(_set_lid, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_glow, 0.0, 1.0, 0.25)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_card, "position:y", chest.position.y - _card.size.y - 10, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.6)
	tween.tween_interval(0.7)
	# Off to the relic row.
	tween.tween_property(_card, "global_position", _target - _card.size * 0.15, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_card, "scale", Vector2(0.3, 0.3), 0.45)
	tween.parallel().tween_method(_set_glow, 1.0, 0.0, 0.45)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.2)
	tween.tween_callback(_finish)


func _set_lid(value: float) -> void:
	_lid_open = value
	queue_redraw()


func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	done.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var chest := _chest_rect()
	# Glow behind the opening.
	if _glow > 0.0:
		for i in 6:
			var r := 60.0 + i * 34.0
			draw_circle(Vector2(chest.get_center().x, chest.position.y), r, Color(1.0, 0.85, 0.45, 0.07 * _glow))
	var wood := Color("5a3a22")
	var dark := Color("2e1c10")
	var band := Color("c9a14a")
	# Body.
	var body := Rect2(chest.position + Vector2(0, 50), Vector2(CHEST.x, CHEST.y - 50))
	draw_rect(body.grow(4), dark)
	draw_rect(body, wood)
	draw_rect(Rect2(body.position + Vector2(0, 30), Vector2(body.size.x, 10)), band)
	draw_rect(Rect2(body.get_center() - Vector2(14, 6), Vector2(28, 30)), band)
	# Lid: tilts back as it opens (drawn shorter and higher).
	var lid_height := 50.0 * (1.0 - 0.75 * _lid_open)
	var lid := Rect2(chest.position + Vector2(0, 50 - lid_height - 40 * _lid_open), Vector2(CHEST.x, lid_height))
	draw_rect(lid.grow(4), dark)
	draw_rect(lid, wood.lightened(0.08))
	draw_rect(Rect2(lid.position + Vector2(0, lid.size.y * 0.45), Vector2(lid.size.x, 8)), band)
