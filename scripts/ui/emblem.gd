class_name Emblem
extends Control
## Small vector emblems drawn in code (placeholder art until M8):
## shield, burn (flame), bleed (drop), curse (eye), sword, heart, coin,
## star (buff / multiplier) and skull (execute).

const COLORS := {
	"shield": Color(0.62, 0.72, 0.85),
	"burn": Color(0.98, 0.5, 0.15),
	"bleed": Color(0.85, 0.1, 0.18),
	"curse": Color(0.68, 0.4, 0.9),
	"sword": Color(0.9, 0.9, 0.95),
	"heart": Color(0.35, 0.85, 0.45),
	"coin": Color(0.95, 0.78, 0.3),
	"star": Color(1.0, 0.85, 0.35),
	"skull": Color(0.92, 0.9, 0.85),
	"attack": Color(0.85, 0.2, 0.22),
	"life": Color(0.25, 0.68, 0.3),
	"suit_coins": Color(0.45, 0.78, 0.4),
	"suit_wands": Color(0.95, 0.45, 0.2),
	"suit_cups": Color(0.3, 0.75, 0.85),
	"suit_swords": Color(0.7, 0.6, 0.95),
	"rank_page": Color(0.75, 0.7, 0.6),
	"rank_knight": Color(0.75, 0.78, 0.85),
	"rank_queen": Color(0.95, 0.78, 0.35),
	"rank_king": Color(1.0, 0.85, 0.3),
	"level": Color(0.95, 0.78, 0.35),
	"enemy": Color(0.75, 0.25, 0.28),
	"tarot": Color(0.8, 0.65, 0.95),
	"relic": Color(0.4, 0.85, 0.8),
	"pack": Color(0.95, 0.78, 0.35),
	"blessing_star": Color(0.62, 0.72, 0.85),
	"blessing_sun": Color(1.0, 0.75, 0.25),
}

## Emblem of an equipment base.
const EQUIPMENT_KINDS := {
	"blade": "sword", "buckler": "shield", "amulet": "life",
	"torch": "burn", "dagger": "bleed", "purse": "coin",
}

## Which emblem represents an ability effect.
const EFFECT_KINDS := {
	"gain_shield": "shield", "warden_shield": "shield", "eat_shield": "shield",
	"apply_burn": "burn", "burn_mult": "burn",
	"apply_bleed": "bleed", "shields_to_bleed": "bleed", "detonate_bleed": "bleed",
	"apply_curse": "curse",
	"damage": "sword",
	"heal": "heart", "lifesteal": "heart", "revive": "heart",
	"steal_gold": "coin", "health_per_gold": "coin", "attack_per_ten_gold": "coin", "midas": "coin",
	"execute": "skull",
}

var kind := "star"
var color := Color.WHITE
## For "level": number of chevrons.
var count := 1


static func create(emblem_kind: String, emblem_size: float) -> Emblem:
	var emblem := Emblem.new()
	emblem.kind = emblem_kind
	emblem.color = COLORS.get(emblem_kind, Color.WHITE)
	emblem.custom_minimum_size = Vector2(emblem_size, emblem_size)
	emblem.size = emblem.custom_minimum_size
	emblem.pivot_offset = emblem.size / 2
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return emblem


static func kind_for_effect(effect: String) -> String:
	return EFFECT_KINDS.get(effect, "star")


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var outline := Color(0, 0, 0, 0.85)
	match kind:
		"shield":
			var pts := _pts(s, [Vector2(0.15, 0.12), Vector2(0.5, 0.02), Vector2(0.85, 0.12),
				Vector2(0.82, 0.55), Vector2(0.5, 0.97), Vector2(0.18, 0.55)])
			_filled(pts, color, outline, s)
			draw_line(c + Vector2(0, -0.32 * s), c + Vector2(0, 0.35 * s), color.darkened(0.35), maxf(1.0, s * 0.07))
		"burn":
			var flame := _pts(s, [Vector2(0.5, 0.0), Vector2(0.72, 0.3), Vector2(0.86, 0.6), Vector2(0.78, 0.86),
				Vector2(0.5, 1.0), Vector2(0.22, 0.86), Vector2(0.14, 0.6), Vector2(0.3, 0.42), Vector2(0.38, 0.22)])
			_filled(flame, color, outline, s)
			var inner := _pts(s, [Vector2(0.5, 0.4), Vector2(0.66, 0.66), Vector2(0.5, 0.9), Vector2(0.34, 0.66)])
			draw_colored_polygon(inner, Color(1, 0.9, 0.4))
		"bleed":
			var drop := _pts(s, [Vector2(0.5, 0.0), Vector2(0.72, 0.38), Vector2(0.8, 0.62), Vector2(0.72, 0.84),
				Vector2(0.5, 0.97), Vector2(0.28, 0.84), Vector2(0.2, 0.62), Vector2(0.28, 0.38)])
			_filled(drop, color, outline, s)
			draw_circle(c + Vector2(-0.12, 0.12) * s, s * 0.08, Color(1, 1, 1, 0.6))
		"curse":
			var eye := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				eye.append(c + Vector2(cos(a) * 0.46, sin(a) * 0.28) * s)
			_filled(eye, color, outline, s)
			draw_circle(c, s * 0.17, Color(0.12, 0.02, 0.18))
			draw_circle(c, s * 0.06, color.lightened(0.6))
		"sword":
			var blade := _pts(s, [Vector2(0.82, 0.08), Vector2(0.92, 0.18), Vector2(0.38, 0.72), Vector2(0.28, 0.62)])
			_filled(blade, color, outline, s)
			draw_line(c + Vector2(-0.32, 0.04) * s, c + Vector2(-0.04, 0.32) * s, Color(0.8, 0.6, 0.3), maxf(2.0, s * 0.12))
			draw_line(c + Vector2(-0.2, 0.2) * s, c + Vector2(-0.38, 0.38) * s, Color(0.55, 0.35, 0.2), maxf(2.0, s * 0.12))
		"heart":
			var heart := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				heart.append(c + Vector2(x, y + 2.0) * s / 36.0)
			_filled(heart, color, outline, s)
		"coin":
			draw_circle(c, s * 0.46, outline)
			draw_circle(c, s * 0.42, color)
			draw_circle(c, s * 0.28, color.darkened(0.25))
		"skull":
			draw_circle(c + Vector2(0, -0.08) * s, s * 0.4, outline)
			draw_circle(c + Vector2(0, -0.08) * s, s * 0.36, color)
			draw_rect(Rect2(c + Vector2(-0.2, 0.1) * s, Vector2(0.4, 0.3) * s), color)
			draw_circle(c + Vector2(-0.15, -0.08) * s, s * 0.1, Color(0.1, 0.05, 0.05))
			draw_circle(c + Vector2(0.15, -0.08) * s, s * 0.1, Color(0.1, 0.05, 0.05))
		"attack":
			# Spiky burst: the attack value is printed in its middle.
			var burst := PackedVector2Array()
			for i in 24:
				var r := 0.5 if i % 2 == 0 else 0.4
				var a := -PI / 2 + TAU * i / 24.0
				burst.append(c + Vector2(cos(a), sin(a)) * r * s)
			_filled(burst, color, outline, s)
		"life":
			var life := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				life.append(c + Vector2(x, y + 1.5) * s / 33.0)
			_filled(life, color, outline, s)
		"suit_coins":
			draw_circle(c, s * 0.44, outline)
			draw_circle(c, s * 0.4, color)
			_filled(_pts(s, [Vector2(0.5, 0.25), Vector2(0.75, 0.5), Vector2(0.5, 0.75), Vector2(0.25, 0.5)]), color.darkened(0.3), outline, s)
		"suit_wands":
			draw_line(c + Vector2(-0.3, 0.38) * s, c + Vector2(0.28, -0.32) * s, outline, maxf(3.0, s * 0.2))
			draw_line(c + Vector2(-0.3, 0.38) * s, c + Vector2(0.28, -0.32) * s, Color(0.6, 0.38, 0.2), maxf(2.0, s * 0.13))
			draw_circle(c + Vector2(0.3, -0.36) * s, s * 0.13, color)
			draw_circle(c + Vector2(0.12, -0.38) * s, s * 0.08, color.lightened(0.2))
		"suit_cups":
			var bowl := _pts(s, [Vector2(0.18, 0.12), Vector2(0.82, 0.12), Vector2(0.74, 0.4), Vector2(0.5, 0.55), Vector2(0.26, 0.4)])
			_filled(bowl, color, outline, s)
			draw_rect(Rect2(c + Vector2(-0.06, 0.04) * s, Vector2(0.12, 0.3) * s), color)
			_filled(_pts(s, [Vector2(0.28, 0.82), Vector2(0.72, 0.82), Vector2(0.66, 0.92), Vector2(0.34, 0.92)]), color, outline, s)
		"suit_swords":
			_filled(_pts(s, [Vector2(0.45, 0.04), Vector2(0.55, 0.04), Vector2(0.55, 0.66), Vector2(0.45, 0.66)]), color, outline, s)
			draw_line(c + Vector2(-0.24, 0.17) * s, c + Vector2(0.24, 0.17) * s, Color(0.8, 0.6, 0.3), maxf(2.0, s * 0.1))
			draw_line(c + Vector2(0, 0.2) * s, c + Vector2(0, 0.44) * s, Color(0.55, 0.35, 0.2), maxf(2.0, s * 0.1))
		"rank_page":
			draw_circle(c + Vector2(0, -0.2) * s, s * 0.17, color)
			_filled(_pts(s, [Vector2(0.32, 0.52), Vector2(0.68, 0.52), Vector2(0.78, 0.92), Vector2(0.22, 0.92)]), color, outline, s)
		"rank_knight":
			var helm := _pts(s, [Vector2(0.24, 0.9), Vector2(0.24, 0.35), Vector2(0.38, 0.12), Vector2(0.62, 0.12),
				Vector2(0.76, 0.35), Vector2(0.76, 0.9)])
			_filled(helm, color, outline, s)
			draw_line(c + Vector2(-0.18, 0.0) * s, c + Vector2(0.18, 0.0) * s, Color(0.1, 0.1, 0.12), maxf(2.0, s * 0.08))
		"rank_queen", "rank_king":
			var points := 3 if kind == "rank_queen" else 5
			var crown := PackedVector2Array()
			crown.append(Vector2(0.12, 0.8))
			for i in points * 2 + 1:
				var x := 0.12 + 0.76 * i / float(points * 2)
				crown.append(Vector2(x, 0.22 if i % 2 == 0 else 0.5))
			crown.append(Vector2(0.88, 0.8))
			_filled(_pts(s, crown), color, outline, s)
			if kind == "rank_king":
				draw_circle(c + Vector2(0, -0.3) * s, s * 0.07, Color(0.85, 0.2, 0.25))
		"level":
			# Stacked chevrons, one per level.
			for i in count:
				var y := 0.62 - i * 0.24
				var chevron := _pts(s, [Vector2(0.2, y + 0.16), Vector2(0.5, y - 0.06), Vector2(0.8, y + 0.16),
					Vector2(0.8, y + 0.28), Vector2(0.5, y + 0.06), Vector2(0.2, y + 0.28)])
				_filled(chevron, color, outline, s)
		"tarot":
			_filled(_pts(s, [Vector2(0.22, 0.06), Vector2(0.78, 0.06), Vector2(0.78, 0.94), Vector2(0.22, 0.94)]), Color(0.18, 0.12, 0.25), outline, s)
			draw_rect(Rect2(c + Vector2(-0.22, -0.38) * s, Vector2(0.44, 0.76) * s), color, false, maxf(1.5, s * 0.05))
			var tstar := PackedVector2Array()
			for i in 10:
				var r := 0.18 if i % 2 == 0 else 0.08
				var a := -PI / 2 + PI * i / 5.0
				tstar.append(c + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(tstar, color)
		"relic":
			_filled(_pts(s, [Vector2(0.5, 0.05), Vector2(0.85, 0.35), Vector2(0.5, 0.95), Vector2(0.15, 0.35)]), color, outline, s)
			draw_line(c + Vector2(-0.35, -0.15) * s, c + Vector2(0.35, -0.15) * s, color.lightened(0.4), maxf(1.0, s * 0.04))
			draw_line(c + Vector2(0, -0.45) * s, c + Vector2(0, 0.45) * s, color.darkened(0.3), maxf(1.0, s * 0.04))
		"pack":
			_filled(_pts(s, [Vector2(0.12, 0.3), Vector2(0.88, 0.3), Vector2(0.88, 0.92), Vector2(0.12, 0.92)]), color.darkened(0.2), outline, s)
			_filled(_pts(s, [Vector2(0.06, 0.18), Vector2(0.94, 0.18), Vector2(0.94, 0.36), Vector2(0.06, 0.36)]), color, outline, s)
			draw_line(c + Vector2(0, -0.32) * s, c + Vector2(0, 0.42) * s, Color(0.75, 0.15, 0.2), maxf(2.0, s * 0.1))
		"blessing_star":
			var bstar := PackedVector2Array()
			for i in 16:
				var r := 0.48 if i % 2 == 0 else 0.16
				var a := -PI / 2 + PI * i / 8.0
				bstar.append(c + Vector2(cos(a), sin(a)) * r * s)
			_filled(bstar, color, outline, s)
		"blessing_sun":
			for i in 12:
				var a := TAU * i / 12.0
				draw_line(c + Vector2(cos(a), sin(a)) * 0.28 * s, c + Vector2(cos(a), sin(a)) * 0.48 * s, color, maxf(1.5, s * 0.07))
			draw_circle(c, s * 0.26, outline)
			draw_circle(c, s * 0.23, color)
		"enemy":
			_filled(_pts(s, [Vector2(0.15, 0.2), Vector2(0.35, 0.35), Vector2(0.5, 0.15), Vector2(0.65, 0.35),
				Vector2(0.85, 0.2), Vector2(0.75, 0.85), Vector2(0.25, 0.85)]), color, outline, s)
		_:  # star
			var star := PackedVector2Array()
			for i in 10:
				var r := 0.48 if i % 2 == 0 else 0.2
				var a := -PI / 2 + PI * i / 5.0
				star.append(c + Vector2(cos(a), sin(a)) * r * s)
			_filled(star, color, outline, s)


func _pts(s: float, normalized: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	var origin := (size - Vector2(s, s)) / 2
	for p: Vector2 in normalized:
		result.append(origin + p * s)
	return result


func _filled(points: PackedVector2Array, fill: Color, outline: Color, s: float) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, maxf(1.0, s * 0.06), true)
