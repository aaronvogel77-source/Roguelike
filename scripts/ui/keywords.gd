class_name Keywords
extends RefCounted
## Colors game keywords in texts (BBCode for RichTextLabel):
## triggers gold, statuses in their emblem color, attack red, health green.

static var _regex: RegEx
static var _colors: Dictionary = {}


## Words shown as a small symbol instead of text (the info window explains
## each symbol on tap). Triggers stay words.
const ICON_WORDS := {
	"Schildpunkt": "shield", "Schilde": "shield", "Schild": "shield", "shields": "shield", "shield": "shield",
	"Brennen": "burn", "burn": "burn", "Blutung": "bleed", "bleed": "bleed", "Fluch": "curse", "curse": "curse",
	"Angriffs": "attack", "Angriff": "attack", "attack": "attack", "Leben": "health", "health": "health",
	"Gold": "gold", "gold": "gold",
}
const ICON_PATH := "res://assets/icons/keywords/%s.png"


static func colorize(text: String, icons := true, size := -1) -> String:
	_ensure_built()
	var result := ""
	var last := 0
	for match in _regex.search_all(text):
		result += text.substr(last, match.get_start() - last)
		var word := match.get_string()
		if icons and ICON_WORDS.has(word):
			result += icon(ICON_WORDS[word], size)
		else:
			result += "[color=#%s]%s[/color]" % [_color_for(word).to_html(false), word]
		last = match.get_end()
	return result + text.substr(last)


## BBCode of one inline symbol.
static func icon(kind: String, size := -1) -> String:
	var side := int(round(20 * UiText.scale)) if size < 0 else size
	return "[img=%dx%d]%s[/img]" % [side, side, ICON_PATH % kind]


## The symbol kinds a text would show, in order of first appearance.
static func icon_kinds(text: String) -> Array:
	_ensure_built()
	var kinds: Array = []
	for match in _regex.search_all(text):
		var kind: String = ICON_WORDS.get(match.get_string(), "")
		if kind != "" and not kind in kinds:
			kinds.append(kind)
	return kinds


static func _color_for(word: String) -> Color:
	if _colors.has(word):
		return _colors[word]
	if word.begins_with("×"):
		return Palette.TRIGGER
	return Palette.PARCHMENT


static func _ensure_built() -> void:
	if _regex != null:
		return
	var groups := {
		Palette.TRIGGER: ["Kampfbeginn (zuletzt)", "Kampfbeginn", "Zugbeginn", "Nach dem Angriff",
			"Wenn getroffen", "Wenn eine eigene Figur stirbt", "Wenn ein Gegner stirbt",
			"Wenn eine deiner Figuren stirbt", "Dauerhaft", "Einmal pro Kampf",
			"Battle start (last)", "Battle start", "Turn start", "After attacking", "When hit",
			"When an ally dies", "When an enemy dies", "When one of your figures dies", "Always",
			"once per battle"],
		Emblem.COLORS["shield"]: ["Schildpunkt", "Schilde", "Schild", "shields", "shield"],
		Emblem.COLORS["burn"]: ["Brennen-Schaden", "Brennen", "burn damage", "burn"],
		Emblem.COLORS["bleed"]: ["Blutung", "bleed"],
		Emblem.COLORS["curse"]: ["Fluch", "curse"],
		Palette.ATTACK: ["Angriffs", "Angriff", "attack"],
		Palette.LIFE: ["Leben", "health", "heilt", "Heilt", "heals"],
		Palette.GOLD: ["Gold", "gold"],
	}
	var words: Array = []
	for color in groups:
		for word in groups[color]:
			_colors[word] = color
			words.append(word)
	# Longest first so "Kampfbeginn (zuletzt)" wins over "Kampfbeginn".
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var escaped := words.map(func(w: String) -> String: return _escape(w))
	# Whole words only: "Gold" must not light up inside "Goldene".
	_regex = RegEx.create_from_string("(?<![\\p{L}])(" + "|".join(escaped) + "|×\\d+(?:[,.]\\d+)?)(?![\\p{L}])")


static func _escape(word: String) -> String:
	var out := ""
	for c in word:
		out += ("\\" + c) if c in "()[]{}.*+?^$|\\" else c
	return out
