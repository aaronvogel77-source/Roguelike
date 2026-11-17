class_name Hints
extends RefCounted
## First-time hints: a parchment note with an arrow next to a new element.
## Each hint shows once (until the player resets them) and can be switched
## off completely. Kept in user://hints.cfg.

const SETTINGS_PATH := "user://hints.cfg"

static var enabled := true
static var seen: Array = []
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		enabled = bool(config.get_value("hints", "enabled", true))
		seen = config.get_value("hints", "seen", [])


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("hints", "enabled", enabled)
	config.set_value("hints", "seen", seen)
	config.save(SETTINGS_PATH)


static func wants(id: String) -> bool:
	_load()
	return enabled and not id in seen


static func mark_seen(id: String) -> void:
	_load()
	if not id in seen:
		seen.append(id)
		_save()


static func set_enabled(value: bool) -> void:
	_load()
	enabled = value
	_save()


static func reset() -> void:
	_load()
	seen.clear()
	_save()


## Shows the hint next to target (inside host) if it is still unseen.
## Returns the note, or null.
static func show(host: Control, id: String, target: Control) -> HintNote:
	if not wants(id) or target == null or not is_instance_valid(target):
		return null
	for child in host.get_children():
		if child is HintNote:
			return null  # one note at a time; the next one comes on the next screen
	var note := HintNote.create(id, target)
	host.add_child(note)
	return note
