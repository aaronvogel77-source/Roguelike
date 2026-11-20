class_name CryptRoomView
extends Control
## The Krypta-Lager as a room (CryptArt.room): fills the screen at full height,
## the room is painted as wide as the screen needs. With stations on, the four
## stations (chests, altar, portraits, mirror) are tappable objects with
## dark-glass name plates edged in gold.

signal station_pressed(station: String)

const ART_H := 180
const STATIONS := ["chests", "altar", "portraits", "mirror"]
## Where each plate sits, in room pixels relative to the station's rect:
## [x fraction of the rect, y offset from the rect's bottom].
const PLATE_AT := {"chests": [0.5, 6], "altar": [0.5, 10], "portraits": [0.5, 4], "mirror": [0.5, 6]}

var interactive := true
var _art: TextureRect
var _art_w := 0
var _hotspots: Dictionary = {}  # station -> [area Button, plate Button]


static func create(with_stations: bool) -> CryptRoomView:
	var view := CryptRoomView.new()
	view.interactive = with_stations
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _ready() -> void:
	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	if interactive:
		for station in STATIONS:
			var area := Button.new()
			area.flat = true
			area.focus_mode = Control.FOCUS_NONE
			area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var glow := StyleBoxFlat.new()  # a faint gold glow when hovered or pressed
			glow.bg_color = Color(1.0, 0.85, 0.45, 0.07)
			glow.border_color = Color(Palette.GOLD, 0.35)
			glow.set_border_width_all(2)
			glow.set_corner_radius_all(8)
			for state in ["hover", "pressed"]:
				area.add_theme_stylebox_override(state, glow)
			for state in ["normal", "focus", "disabled"]:
				area.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			area.pressed.connect(func() -> void: station_pressed.emit(station))
			add_child(area)
			var plate := _plate(tr("UI_STATION_" + station.to_upper()))
			plate.pressed.connect(func() -> void: station_pressed.emit(station))
			add_child(plate)
			_hotspots[station] = [area, plate]
	resized.connect(_layout)
	_layout()


## A dark-glass name plate with a fine gold edge (at least 48 px high).
func _plate(text: String) -> Button:
	var plate := Button.new()
	plate.text = text
	plate.focus_mode = Control.FOCUS_NONE
	plate.custom_minimum_size = Vector2(150, 48)
	plate.add_theme_font_size_override("font_size", 22)
	plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.045, 0.08, 0.86 if state != "hover" else 0.94)
		style.border_color = Palette.GOLD if state != "normal" else Color(Palette.GOLD, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 4
		plate.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		plate.add_theme_color_override(key, Palette.PARCHMENT if key == "font_color" else Color("ffe08a"))
	return plate


func _layout() -> void:
	if _art == null or size.y <= 0.0:
		return
	var scale := size.y / ART_H
	var art_w := maxi(240, int(ceil(size.x / scale)))
	if art_w != _art_w:
		_art_w = art_w
		_art.texture = CryptArt.room(art_w, ART_H)
	_art.position = Vector2((size.x - art_w * scale) / 2.0, 0)
	_art.size = Vector2(art_w * scale, size.y)
	if not interactive:
		return
	var rects := CryptArt.station_rects(art_w, ART_H)
	for station in STATIONS:
		var r: Rect2 = rects[station]
		var area: Button = _hotspots[station][0]
		var plate: Button = _hotspots[station][1]
		area.position = _art.position + r.position * scale
		area.size = r.size * scale
		plate.size = plate.get_combined_minimum_size()
		var at: Array = PLATE_AT[station]
		var center := _art.position + Vector2(r.position.x + r.size.x * at[0], r.end.y + at[1]) * scale
		var p := center - Vector2(plate.size.x / 2.0, 0)
		p.x = clampf(p.x, 8.0, size.x - plate.size.x - 8.0)
		p.y = clampf(p.y, 8.0, size.y - plate.size.y - 8.0)
		plate.position = p
