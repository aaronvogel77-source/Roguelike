class_name Keywords
extends RefCounted
## Colors game keywords in texts (BBCode for RichTextLabel):
## triggers gold, statuses in their emblem color, attack red, health green.

static var _regex: RegEx
static var _colors: Dictionary = {}


static func colorize(text: String) -> String:
	_ensure_built()
	var result := ""
	var last := 0
	for match in _regex.search_all(text):
		result += text.substr(last, match.get_start() - last)
		var word := match.get_string()
		result += "[color=#%s]%s[/color]" % [_color_for(word).to_html(false), word]
		last = match.get_end()
	return result + text.substr(last)


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
	_regex = RegEx.create_from_string("(" + "|".join(escaped) + "|×\\d+(?:[,.]\\d+)?)")


static func _escape(word: String) -> String:
	var out := ""
	for c in word:
		out += ("\\" + c) if c in "()[]{}.*+?^$|\\" else c
	return out
