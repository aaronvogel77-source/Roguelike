class_name UiTheme
extends RefCounted
## Shared placeholder theme (buttons with clear frames) until the art pass in M8.


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _box(Color(0.16, 0.13, 0.19), Palette.GOLD.darkened(0.35)))
	theme.set_stylebox("hover", "Button", _box(Color(0.22, 0.18, 0.26), Palette.GOLD))
	theme.set_stylebox("pressed", "Button", _box(Color(0.3, 0.24, 0.14), Palette.GOLD))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _box(Color(0.1, 0.09, 0.11), Color(1, 1, 1, 0.08)))
	theme.set_color("font_color", "Button", Palette.PARCHMENT)
	theme.set_color("font_hover_color", "Button", Palette.GOLD)
	theme.set_color("font_pressed_color", "Button", Palette.GOLD)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.25))
	return theme


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box
