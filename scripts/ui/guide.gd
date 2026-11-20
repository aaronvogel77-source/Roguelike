class_name Guide
extends Control
## Guided first run: a pulsing frame around the one thing to do next, with a
## short line ("Zieh eine Figur ins Team"), step by step. Never blocks input;
## "Führung beenden" ends it for good. Progress lives in user://guide.cfg.

const SAVE_PATH := "user://guide.cfg"
## Steps in order: choose the easy band, buy a figure, fight, take a reward,
## open a pack.
const STEPS := ["choose", "buy", "fight", "reward", "pack"]
const TEXTS := {"choose": "GUIDE_CHOOSE", "buy": "GUIDE_BUY", "fight": "GUIDE_FIGHT",
	"reward": "GUIDE_REWARD", "pack": "GUIDE_PACK"}

static var step := -2  # -2 = not loaded yet, -1 = finished

var target: Control
var _label: Label
var _end: Button
var _time := 0.0


static func load_state() -> void:
	if step != -2:
		return
	var config := ConfigFile.new()
	step = int(config.get_value("guide", "step", 0)) if config.load(SAVE_PATH) == OK else 0


static func save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("guide", "step", step)
	config.save(SAVE_PATH)


static func active() -> bool:
	load_state()
	return step >= 0 and step < STEPS.size()


static func current() -> String:
	return STEPS[step] if active() else ""


## Moves on to the step after `name` (if that is the current one).
static func passed(name: String) -> void:
	if current() == name:
		step += 1
		if step >= STEPS.size():
			step = -1
		save_state()


static func finish() -> void:
	step = -1
	save_state()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_meta("text_fixed", true)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Palette.MONEY)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_end = Button.new()
	_end.text = tr("GUIDE_END")
	_end.add_theme_font_size_override("font_size", 16)
	_end.custom_minimum_size = Vector2(0, 48)
	_end.pressed.connect(func() -> void:
		Guide.finish()
		queue_free())
	add_child(_end)


func show_step(text_key: String, at: Control) -> void:
	target = at
	_label.text = tr(text_key)


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		visible = false
		return
	visible = true
	var rect := target.get_global_rect()
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_label.reset_size()
	var above := rect.position.y > _label.size.y + 24
	_label.position = Vector2(clampf(rect.get_center().x - _label.size.x / 2, 8, size.x - _label.size.x - 8),
		rect.position.y - _label.size.y - 14 if above else rect.end.y + 14)
	_end.reset_size()
	_end.position = Vector2(size.x - _end.size.x - 16, size.y - _end.size.y - 16)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(target):
		return
	var rect := target.get_global_rect().grow(8)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_rect(rect.grow(4 + pulse * 6), Color(Palette.MONEY, 0.25 * (1.0 - pulse)), false, 6.0)
	draw_rect(rect, Color(Palette.MONEY, 0.6 + 0.4 * pulse), false, 4.0)
