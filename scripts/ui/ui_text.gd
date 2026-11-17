class_name UiText
extends RefCounted
## Global text size: every label, rich text and button is scaled by one factor
## when it enters the tree (its own font size is remembered, so a new factor
## from the settings rescales everything that is on screen). Kept in
## user://text.cfg.

const SETTINGS_PATH := "user://text.cfg"
const DEFAULT_SCALE := 1.3
const CHOICES := [1.0, 1.15, 1.3, 1.5]
## Font sizes from here on are headings and stay as they are.
const BIG := 24
const FONT_KEYS := {
	"Label": ["font_size"], "Button": ["font_size"], "CheckButton": ["font_size"], "LineEdit": ["font_size"],
	"RichTextLabel": ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"],
}

static var scale := DEFAULT_SCALE
static var _tree: SceneTree


static func setup(tree: SceneTree) -> void:
	if _tree != null:
		return
	_tree = tree
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		scale = float(config.get_value("text", "scale", DEFAULT_SCALE))
	tree.node_added.connect(func(node: Node) -> void:
		if node is Control:
			# After the creating code has set its own size overrides.
			_apply.call_deferred(node))


static func set_scale(value: float) -> void:
	scale = value
	var config := ConfigFile.new()
	config.set_value("text", "scale", scale)
	config.save(SETTINGS_PATH)
	if _tree != null:
		for node in _tree.root.find_children("*", "Control", true, false):
			_apply(node)


## Card faces and areas marked "text_fixed" (the top bar) keep their sizes.
static func _inside_card(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node is UnitCard or node is ObjectCard or (node is Control and node.has_meta("text_fixed")):
			return true
		node = node.get_parent()
	return false


static func _keys(node: Control) -> Array:
	for type in FONT_KEYS:
		if node.is_class(type):
			return FONT_KEYS[type]
	return []


static func _apply(node: Variant) -> void:
	if not is_instance_valid(node) or not node is Control:
		return
	var control: Control = node
	if control.has_meta("text_fixed") or _inside_card(control):
		return  # text inside card faces has fixed room (the info panel shows it big)
	for key: String in _keys(control):
		var base_key := "base_" + key
		if not control.has_meta(base_key):
			control.set_meta(base_key, control.get_theme_font_size(key))
		var base := int(control.get_meta(base_key))
		# Small text (descriptions, info lines, buttons) grows; headings are big enough.
		var wanted := base if base >= BIG else mini(int(round(base * scale)), BIG + 2)
		if control.get_theme_font_size(key) != wanted:
			control.add_theme_font_size_override(key, wanted)
