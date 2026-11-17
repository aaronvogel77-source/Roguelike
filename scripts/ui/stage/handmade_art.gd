class_name HandmadeArt
extends RefCounted
## Hand-made pixel art: figures drawn pixel by pixel as character grids
## (one character per pixel, "." = transparent). Parts replace the
## procedural parts of FigureArt with the same pivots, so rigs, animations
## and effects keep working. Rules: see the pixel-art skill.

const FIGURES := {
	"executioner": {
		"palette": {
			# black hood (cool shadows, warm-grey highlight)
			"k": "0c0910", "h": "1d1724", "H": "2f2738", "L": "4a4050",
			"e": "e8dcc0", "r": "c0303a",
			# skin (warm light, cooler shadows)
			"d": "3a2014", "s": "7a4630", "m": "b8784e", "l": "e2a878",
			# leather, iron, blood
			"b": "1e120c", "B": "40281a", "n": "6a4428", "N": "94683f",
			"i": "4c5462", "I": "8e98a8", "W": "d8e0ea", "w": "3a2a1a", "o": "5c3e22",
			"x": "6a0c14", "X": "9a1820",
		},
		"head": {"pivot": [7, 16], "rows": [
			"....L..........",
			"....LH.........",
			"...LHHh........",
			"...LHHhh.......",
			"..LHHHHhh......",
			"..LHHHHhhh.....",
			".LHHHHHhhhh....",
			".LHHHHHhhhhh...",
			".LHHHHHkkkkkk..",
			".LHHHHkkekkek..",
			".LHHHHkkrkkrk..",
			".LHHHHhkkkkkk..",
			".hHHHHhhhhhhh..",
			"..hHHHhhhsmmd..",
			"..hhhhhhsmlmd..",
			"...hhhhhssmmd..",
			"......dssssd...",
		]},
		"torso": {"pivot": [9, 16], "rows": [
			"....lllmmmmmm.....",
			"...lmmmmmmmmmms...",
			"..lmmmmmmmmmmmms..",
			"..lmmlmmmmmBBmss..",
			"..lmmmllmmBBmmss..",
			"..lmmssmmBBmmsss..",
			"..lmmmmmBBmmmmss..",
			"...lmmmBBmlmmss...",
			"...lmmBBmmmmmss...",
			"...lmBBmmsmmmss...",
			"...lBBmmmmsmmss...",
			"...BBmmsmmmmsss...",
			"...bbbbbbbbbbbb...",
			"...bnnnIWInnnnb...",
			"...bbbbiIibbbbb...",
			"...BNNNNNNNNNNB...",
			"...BNnNNNNNNnNB...",
			"...BNNNNxNNNNNB...",
			"...BNNNNXxNNNNB...",
			"....BBBBBBBBBB....",
		]},
		"weapon": {"pivot": [5, 30], "rows": [
			".....oo...........",
			".....wo...IIII....",
			".....wo..IIWWWII..",
			".....woiIIIWWWWWI.",
			".....woiIIIIWWWWWI",
			".....woiIIIIIIWWWI",
			".....woiIIIIIIIWWI",
			".....woiIIIIxIIIWI",
			".....woiIIIxXIIIWI",
			".....woiIIIIxIIIWI",
			".....woiIIIIIIIWWI",
			".....woiIIIIIIWWWI",
			".....woiIIIIWWWWWI",
			".....wo..IIWWWWI..",
			".....wo...IIII....",
			".....wo...........",
			".....wo...........",
			".....wo...........",
			".....wo...........",
			".....wo...........",
			".....bB...........",
			".....wo...........",
			".....wo...........",
			".....bB...........",
			".....wo...........",
			".....wo...........",
			".....bB...........",
			".....wo...........",
			".....wo...........",
			".....wo...........",
			".....wo...........",
			".....ii...........",
		]},
	},
	"king_midas": {
		"palette": {
			# crown and gold (hue-shifted: brown-red shadows, pale yellow highlights)
			"a": "4a2a08", "c": "9a6212", "G": "dca42c", "T": "fff0a0",
			"u": "c0303a", "e": "28b060",
			# robe gold
			"q": "5a3608", "r": "8a5a12", "R": "c08a20", "S": "f0c850",
			# fur collar
			"f": "c8beb0", "F": "f6f0e6", "k": "202024",
			# face, hair, beard
			"h": "3a2414", "d": "3a2014", "s": "7a4630", "m": "c2825a", "l": "eab288",
			"y": "6a625a", "Y": "a8a096", "Z": "e2dcd2",
		},
		"head": {"pivot": [8, 17], "rows": [
			"...T....T....T...",
			"..TGT..TGT..TGT..",
			"..cGGcGGGGGcGGc..",
			"..cGuGGGeGGGGuc..",
			"..accccccccccca..",
			"..yhhhhmmmmmll...",
			".yhhhhmmmmmmlll..",
			".yhhhmmmmmmkmll..",
			".yhhhmmmmmmmmlm..",
			".yhhhmmmmmmmmmml.",
			".yhhsmmmmmmmmmm..",
			".yhYYYZmmmZZZs...",
			".yYYYZZZZZZZZY...",
			"..YYYZZZZZZZY....",
			"..YYYZZZZZZY.....",
			"...YYYZZZZY......",
			"....YYYYYY.......",
			".....ssss........",
		]},
		"torso": {"pivot": [9, 19], "rows": [
			"....FkfFFfkFfFF....",
			"...FFfFkfFFfkFfF...",
			".SSFkFFfFkfFFfkFqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTecRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTecRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRRRRTGcRRRrrqq.",
			".ccccccceeeccccccc.",
			".aaaaaaaaaaaaaaaaa.",
			".SSSRRRRTGcRRRrrqq.",
			".SSSRrRRTGcRRrrrqq.",
			".SSSRrSRTGcRRrrrqq.",
			".SSSRrRRTecRRrrrqq.",
			".SSSRrSRTGcRRrrrqq.",
			".SSSRrRRTGcRRrrrqq.",
			"SSSSRrSRTGcRRrRrrqq",
			"SSSSRrRRTGcRRrRrrqq",
			"SSSSRrSRTecRRrRrrqq",
			"SSSSRrRRTGcRRrrrrqq",
			"SSSSRrSRTGcRRrRrrqq",
			"SSSSRrRRTGcRRrRrrqq",
			"SSSSRrSRTGcRRrRrrqq",
			"SSSSRrRRTecRRrRrrqq",
			"SSSSRrSRTGcRRrRrrqq",
			"TTTTTTTTTTTTTTTTTTT",
			"ccccccccccccccccccc",
		]},
	},
}

## Hand-made enemy creatures (one sprite each): feet pivot and throwing hand.
const CREATURES := {
	"debt_collector": {
		"palette": {"0": "1a3416", "1": "35602a", "2": "5e9a3c", "3": "9ccc62", "Y": "ffd040", "t": "f0ead8", "a": "110e18", "b": "241e30", "C": "3a3250", "D": "544a70", "k": "0e0c12", "K": "2a2632", "G": "d9a530", "R": "7a1620", "r": "b02830", "p": "e8dcc0", "w": "f4f0e8"},
		"feet": [16, 39], "hand": [10, -16],
		"rows": [
			"............KKKKKKK.....w.......",
			"............KkkkkKK....ww.......",
			"............KkkkkKK...ww........",
			"............KkkkkKK..ww.........",
			"............GGGGGGGGw...........",
			"............KkkkkKK.............",
			"..........KKKKKKKKKKK...........",
			"...........0332222210...........",
			"........1.0322222222100.........",
			".......121322GGG222211..........",
			".......1213222GY0G22222211......",
			"........1222222GGG222222111.....",
			"..........122220t0t022...0......",
			"...........122222222221.........",
			"............1111111111..........",
			"........abbbCCD1111DCCba........",
			".......abCCCCDDDGDDDCCCba.......",
			"......abCCCCCCCCCCCCCCCCba......",
			"......abCCCCCCCCGCCCCCCCCba.....",
			".....abCCCCCCCCCCCCCCCCCCCba....",
			".....abCCCCCCCCGCCCCCCCCCCba....",
			".....abCCCCCCCCCCCCCCRRRRRRRR...",
			".....abCCCCCGGGGCCCCCRpppppprR..",
			".....abCCCCCCCCGCCCCCRpGGppprR..",
			".....abCCCCCCCCCCCCCCRpppppprR..",
			".....abCCCCCCCCGCCC2232ppppprR..",
			".....abbCCCCCCCCCCC222RRRRRRRR..",
			".....abbCCCCCCCGCCCC1CCCba......",
			".....aabbCCCCCCCCCCCCCCCba......",
			"......aabbCCCCCCGCCCCCCba.......",
			"......aabbCCCCCCCCCCCCba........",
			".....aaabbbbCCCCCCCCCbba........",
			"....aaaa.abbbbbbbbbbbba.........",
			"...aaa...a.bbbbbbbb.aa..........",
			"..........kKk...kKk.............",
			"..........kKk...kKk.............",
			"..........kKk...kKk.............",
			"..........kKk...kKk.............",
			".........kkKKk.kkKKkk...........",
			"........kkkKKKkkkkKKKKk.........",
		],
	},
}


static func has_creature(id: String) -> bool:
	return CREATURES.has(id)


## The creature as a canvas (outline added by CreatureArt), feet and hand.
static func creature(id: String) -> Dictionary:
	var spec: Dictionary = CREATURES[id]
	var palette := {}
	for key in spec["palette"]:
		palette[key] = Color(spec["palette"][key])
	var rows: Array = spec["rows"]
	var width := 0
	for row in rows:
		width = maxi(width, String(row).length())
	var c := PixelCanvas.new(width + 2, rows.size() + 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				c.px(palette[row[x]], x + 1, y + 1)
	return {"canvas": c, "feet": Vector2i(int(spec["feet"][0]) + 1, int(spec["feet"][1]) + 1),
		"hand": Vector2(spec["hand"][0], spec["hand"][1])}


static func has(id: String) -> bool:
	return FIGURES.has(id)


## Replaces the procedural parts of a figure with the hand-made ones.
static func apply(id: String, parts: Dictionary) -> void:
	var figure: Dictionary = FIGURES[id]
	var palette := {}
	for key in figure["palette"]:
		palette[key] = Color(figure["palette"][key])
	for part in ["head", "torso", "armF", "armB", "legF", "legB", "weapon", "cape"]:
		if figure.has(part):
			parts[part] = _build(figure[part], palette)


static func _build(spec: Dictionary, palette: Dictionary) -> Dictionary:
	var rows: Array = spec["rows"]
	var width := 0
	for row in rows:
		width = maxi(width, String(row).length())
	# One pixel of margin all round for the outline.
	var c := PixelCanvas.new(width + 2, rows.size() + 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if palette.has(key):
				c.px(palette[key], x + 1, y + 1)
	var pivot: Array = spec["pivot"]
	return c.outline().part(Vector2i(int(pivot[0]) + 1, int(pivot[1]) + 1))
