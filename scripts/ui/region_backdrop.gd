class_name RegionBackdrop
extends Control
## Placeholder region background (until the art pass in M8): a dark gradient in
## the region's color with faint, scattered suit emblems. The Glutmark (wands)
## glows from below instead, with embers drifting up through ash haze.

var suit := "coins"
var _time := 0.0


func _ready() -> void:
	set_process(suit == "wands")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if suit == "wands":
		_draw_embers()
		return
	var base: Color = Palette.SUIT_COLORS.get(suit, Palette.GOLD)
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var color := Palette.BACKGROUND.lerp(base.darkened(0.55), (1.0 - absf(t - 0.5) * 2.0) * 0.6)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / steps + 1), color)
	var rng := RandomNumberGenerator.new()
	rng.seed = suit.hash()
	for i in 40:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r := rng.randf_range(6, 22)
		draw_circle(p, r, Color(base, 0.06))
		draw_arc(p, r * 0.7, 0, TAU, 24, Color(base, 0.1), 2.0)


## Glutmark: soot above, a low ember glow below (in bands), ash haze and embers rising.
func _draw_embers() -> void:
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var glow := pow(t, 2.2) * 0.75
		var color := Color("0e0a0c").lerp(Color("5a1a08"), glow)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / steps + 1), color)
	for band in 3:  # slow ash haze bands
		var y := size.y * (0.35 + band * 0.18) + sin(_time * 0.3 + band) * 6.0
		draw_rect(Rect2(0, y, size.x, 10 + band * 4), Color(0.45, 0.4, 0.38, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351
	for i in 60:
		var speed := rng.randf_range(0.04, 0.12)
		var x0 := rng.randf() * size.x
		var ph := fmod(_time * speed + rng.randf(), 1.0)
		var p := Vector2(x0 + sin(_time * 0.8 + i) * 12.0, size.y * (1.0 - ph))
		var s := 3.0 if i % 4 == 0 else 2.0
		var c := Color("ffe48a") if i % 7 == 0 else (Color("f89028") if i % 2 else Color("c8480e"))
		c.a = (1.0 - ph) * 0.8
		draw_rect(Rect2(p.round(), Vector2(s, s)), c)
