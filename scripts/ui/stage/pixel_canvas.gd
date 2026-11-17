class_name PixelCanvas
extends RefCounted
## A tiny pixel painter on an Image: rectangles, shaded boxes, shaded blobs and
## an automatic dark outline. All figure art is drawn with it (placeholder art
## that can later be replaced by hand-made sprites).

const OUTLINE := Color("120a0e")

var image: Image
var w: int
var h: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)


## A filled rectangle (clipped to the canvas).
func px(color: Color, x: int, y: int, rw := 1, rh := 1) -> void:
	var rect := Rect2i(x, y, rw, rh).intersection(Rect2i(0, 0, w, h))
	if rect.size.x > 0 and rect.size.y > 0:
		image.fill_rect(rect, color)


## A box lit from the top left: light left/top edge, dark right/bottom edge.
## ramp: [dark, mid, light, highlight].
func shade(x: int, y: int, rw: int, rh: int, ramp: Array) -> void:
	if rw <= 0 or rh <= 0:
		return
	px(ramp[1], x, y, rw, rh)
	if rw > 1:
		px(ramp[0], x + rw - 1, y, 1, rh)
	if rh > 2:
		px(ramp[0], x, y + rh - 1, rw, 1)
	px(ramp[2], x, y, 1, rh - 1)
	px(ramp[2], x, y, rw - 1, 1)
	px(ramp[3], x, y, 1, 1)


## A filled ellipse shaded like a sphere lit from the top left.
func blob(cx: int, cy: int, rx: int, ry: int, ramp: Array) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var d := float(x * x) / (rx * rx + 0.5) + float(y * y) / (ry * ry + 0.5)
			if d > 1.0:
				continue
			var v := -x / (rx + 0.5) - y / (ry + 0.5) + (1.0 - d) * 0.6
			var tone := 3 if v > 1.0 else (2 if v > 0.25 else (1 if v > -0.55 else 0))
			px(ramp[tone], cx + x, cy + y)


## Draws a dark outline around everything painted so far.
func outline(color := OUTLINE) -> PixelCanvas:
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _solid(x, y):
				continue
			if _solid(x - 1, y) or _solid(x + 1, y) or _solid(x, y - 1) or _solid(x, y + 1):
				marks.append(Vector2i(x, y))
	for m in marks:
		image.set_pixel(m.x, m.y, color)
	return self


func _solid(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and image.get_pixel(x, y).a > 0.15


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


## A part of a rigged figure: its texture and the pivot (in texture pixels).
func part(pivot: Vector2i) -> Dictionary:
	return {"tex": texture(), "pivot": pivot}
