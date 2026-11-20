class_name Cosmetics
extends RefCounted
## The cosmetics the player wears (bought in the vault mirror): card back,
## battle background, fusion aura colours and figure skins. Static, so the
## art code can read them without passing the meta state around.

static var back := "back_tarot"
static var stage := "stage_vault"
static var aura := "aura_suits"
static var skins: Dictionary = {}  # figure id -> skin id

const BACKS := {
	"back_tarot": {"bg": "2a0e3a", "border": "e0b44a"},
	"back_blood": {"bg": "3a0a10", "border": "e04050"},
	"back_gold": {"bg": "2e2008", "border": "ffe08a"},
}
## Aura colours as two four-tone ramps (dark, mid, light, highlight), shadows
## cooler and highlights warmer: the ground ring uses the first, the light
## column and sparkles the second.
const AURAS := {
	"aura_violet": [["2a1450", "5a2aa0", "a070e8", "f0d8ff"], ["2a1450", "6a34b8", "b080f0", "f4e4ff"]],
	"aura_ember": [["4a1008", "a8401a", "f09030", "fff0b0"], ["5a1a08", "b85a1a", "ffb040", "fff4c8"]],
}


static func apply(meta: MetaState) -> void:
	back = String(meta.equipped.get("back", "back_tarot"))
	stage = String(meta.equipped.get("stage", "stage_vault"))
	aura = String(meta.equipped.get("aura", "aura_suits"))
	skins = meta.equipped.get("skins", {}).duplicate()


static func back_colors() -> Dictionary:
	var entry: Dictionary = BACKS.get(back, BACKS["back_tarot"])
	return {"bg": Color(entry["bg"]), "border": Color(entry["border"])}


## The worn aura as two ramps of Colors, or [] for "suit colours" (the free
## default, which only fusions show).
static func aura_ramps() -> Array:
	var ramps: Array = []
	for ramp in AURAS.get(aura, []):
		ramps.append(ramp.map(func(hex: String) -> Color: return Color(hex)))
	return ramps


## A four-tone ramp around one colour (a suit gem): cooler shadow, warmer light.
static func ramp_from(base: Color) -> Array:
	var cool := Color(0.25, 0.15, 0.45)
	var warm := Color(1.0, 0.92, 0.6)
	return [base.darkened(0.55).lerp(cool, 0.25), base.darkened(0.15), base.lightened(0.3).lerp(warm, 0.1),
		base.lightened(0.65).lerp(warm, 0.35)]
