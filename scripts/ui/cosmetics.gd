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
const AURAS := {
	"aura_violet": ["c080ff", "8a50e0"],
	"aura_ember": ["ff9030", "ffd060"],
}


static func apply(meta: MetaState) -> void:
	back = String(meta.equipped.get("back", "back_tarot"))
	stage = String(meta.equipped.get("stage", "stage_vault"))
	aura = String(meta.equipped.get("aura", "aura_suits"))
	skins = meta.equipped.get("skins", {}).duplicate()


static func back_colors() -> Dictionary:
	var entry: Dictionary = BACKS.get(back, BACKS["back_tarot"])
	return {"bg": Color(entry["bg"]), "border": Color(entry["border"])}


## Aura colours for a fusion, or [] to use its suit colours.
static func aura_colors() -> Array:
	return AURAS.get(aura, []).map(func(hex: String) -> Color: return Color(hex))
