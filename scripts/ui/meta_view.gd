class_name MetaView
extends Control
## Everything outside a run: the main menu, the occultist choice, the vault
## (crypt with chests, altar, portraits and mirror) and the grimoire.
## Purchases change the MetaState and save it at once.

signal continue_run
signal start_run(occultist: String)

const PAGES_IN_VAULT := ["chests", "altar", "portraits", "mirror"]
const GRIMOIRE_TABS := ["figures", "relics", "tarot", "pacts", "masters", "recipes", "enemies"]
const COSMETIC_KINDS := ["back", "stage", "aura", "skin"]
const OCCULTIST_EMBLEMS := {"novice": "skull", "usurer": "coin", "fencer": "sword"}
## Rarity (glow) of chest finds; legendary skins get their big reveal.
const FIND_RARITY := {"tarot": 1, "relics": 2, "events": 2, "pacts": 3, "figures": 4, "skins": 5}

var _db: ContentDb
var _meta: MetaState
var _has_save := false
var _debug := false
var _page := "menu"
var _tab := "figures"
var _rng := RandomNumberGenerator.new()
var _last_chest: Array = []
var _info: RichTextLabel
## The run screen's detail panel, for the grimoire's full descriptions.
var detail_panel: DetailPanel


static func create(db: ContentDb, meta: MetaState, has_save: bool, debug: bool) -> MetaView:
	var view := MetaView.new()
	view._db = db
	view._meta = meta
	view._has_save = has_save
	view._debug = debug
	view._rng.randomize()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return view


func _ready() -> void:
	_show("menu")


func _show(page: String) -> void:
	_page = page
	Sound.music("menu" if page in ["menu", "occultists"] else "vault")
	for child in get_children():
		child.queue_free()
	# The crypt: the pixel vault of the battle stage, dimmed behind the pages.
	var backdrop := TextureRect.new()
	backdrop.texture = FigureArt.background(Cosmetics.stage, 300, 130, 106)
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.55, 0.5, 0.55) if page == "menu" else Color(0.32, 0.3, 0.34)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	match page:
		"menu":
			_build_menu(column)
		"occultists":
			_build_occultists(column)
		"vault":
			_build_vault(column)
		"chests", "altar", "portraits", "mirror":
			_build_station(column)
		"grimoire":
			_build_grimoire(column)
		"settings":
			_build_settings(column)


# --- Main menu ------------------------------------------------------------------------

func _build_menu(column: VBoxContainer) -> void:
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label("ARCANA", 92, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := _label(tr("UI_MENU_SUBTITLE"), 24, Palette.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	column.add_child(_centered(_glut_badge()))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	if _has_save:
		buttons.add_child(_button(tr("UI_MENU_CONTINUE"), Vector2(360, 66), func() -> void: continue_run.emit()))
	buttons.add_child(_button(tr("UI_MENU_NEW_RUN"), Vector2(360, 66), _show.bind("occultists")))
	buttons.add_child(_button(tr("UI_MENU_VAULT"), Vector2(360, 66), _show.bind("vault")))
	buttons.add_child(_button(tr("UI_MENU_GRIMOIRE"), Vector2(360, 66), _show.bind("grimoire")))
	buttons.add_child(_button(tr("UI_MENU_SETTINGS"), Vector2(360, 52), _show.bind("settings")))
	if _debug:
		buttons.add_child(_button("+50 Seelenglut", Vector2(360, 44), func() -> void:
			_meta.glut += 50
			_meta.save()
			_show("menu")))
	column.add_child(_centered(buttons))
	var stats := _label(tr("UI_MENU_STATS") % [_meta.runs, _meta.wins], 18, Palette.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)


# --- Settings: sound and first-time hints -----------------------------------------------

func _build_settings(column: VBoxContainer) -> void:
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label(tr("UI_MENU_SETTINGS"), 44, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	var music := _slider(Sound.music_volume)
	var effects := _slider(Sound.sfx_volume)
	var mute := CheckButton.new()
	mute.button_pressed = Sound.muted
	mute.add_theme_font_size_override("font_size", 24)
	var apply := func(_value: Variant = null) -> void:
		Sound.set_volumes(music.value, effects.value, mute.button_pressed)
	music.value_changed.connect(apply)
	effects.value_changed.connect(func(value: float) -> void:
		apply.call()
		Sound.play("coins"))  # a sample at the new volume
	mute.toggled.connect(apply)
	for row in [[tr("UI_SET_MUSIC"), music], [tr("UI_SET_SFX"), effects], [tr("UI_SET_MUTE"), mute]]:
		grid.add_child(_label(row[0], 26, Palette.PARCHMENT))
		grid.add_child(row[1])
	_settings_extra(grid)
	column.add_child(_centered(grid))
	column.add_child(_centered(_button(tr("UI_BACK"), Vector2(260, 60), _show.bind("menu"))))


## Room for more settings rows (first-time hints).
func _settings_extra(_grid: GridContainer) -> void:
	pass


func _slider(value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 40)
	return slider


# --- Occultist choice ------------------------------------------------------------------

func _build_occultists(column: VBoxContainer) -> void:
	column.add_child(_header(tr("UI_CHOOSE_OCCULTIST")))
	if _has_save:
		var warn := _label(tr("UI_NEW_RUN_WARNING"), 18, Palette.HEALTH)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(warn)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	for entry in _db.meta["occultists"]:
		var id: String = entry["id"]
		var owned := id in _meta.occultists
		var card := _panel(Vector2(330, 360), Palette.GOLD if owned else Color(1, 1, 1, 0.2))
		var box := _box(card)
		box.add_child(_centered(Emblem.create("skull" if id == "novice" else ("coin" if id == "usurer" else "sword"), 56)))
		box.add_child(_text_label(tr("OCC_" + id.to_upper()), 28, Palette.GOLD if owned else Palette.MUTED))
		box.add_child(_rich(tr("OCC_" + id.to_upper() + "_RULE"), 17))
		var start := String(entry.get("start", ""))
		var start_text := tr("UI_OCC_START_RANDOM") if start == "" else tr("UI_OCC_START") % ContentDb.display_name(_db.figures[start])
		box.add_child(_rich(start_text + " · " + tr("UI_GOLD") % int(entry["start_gold"]), 16))
		if owned:
			box.add_child(_button(tr("UI_CHOOSE"), Vector2(220, 56), func() -> void: start_run.emit(id)))
		else:
			box.add_child(_rich("[color=#%s]%s[/color]" % [Palette.MUTED.to_html(false),
				tr("UI_OCC_LOCKED") % [tr("CHALLENGE_" + String(entry["challenge"]).to_upper()), int(entry["price"])]], 16))
		row.add_child(card)
	column.add_child(_back_button("menu"))


# --- Vault (crypt) ---------------------------------------------------------------------

func _build_vault(column: VBoxContainer) -> void:
	column.add_child(_header(tr("UI_VAULT_TITLE")))
	column.add_child(_centered(_glut_badge()))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var icons := {"chests": "pack", "altar": "star", "portraits": "skull", "mirror": "soul"}
	for station in PAGES_IN_VAULT:
		var card := _panel(Vector2(250, 300), Palette.GOLD)
		var box := _box(card)
		box.add_child(_centered(Emblem.create(icons[station], 72)))
		box.add_child(_text_label(tr("UI_STATION_" + station.to_upper()), 28, Palette.GOLD))
		box.add_child(_rich(tr("UI_STATION_" + station.to_upper() + "_DESC"), 16))
		box.add_child(_button(tr("UI_OPEN"), Vector2(170, 52), _show.bind(station)))
		row.add_child(card)
	column.add_child(_back_button("menu"))


func _build_station(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	top.add_child(_label(tr("UI_STATION_" + _page.to_upper()), 40, Palette.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_glut_badge())
	column.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	match _page:
		"chests":
			for chest in _db.meta["chests"]:
				grid.add_child(_chest_card(chest))
		"altar":
			for entry in _db.meta["upgrades"]:
				grid.add_child(_upgrade_card(entry))
		"portraits":
			for entry in _db.meta["occultists"]:
				if entry.has("price"):
					grid.add_child(_portrait_card(entry))
		"mirror":
			for kind in COSMETIC_KINDS:
				for entry in _db.meta["cosmetics"]:
					if entry["kind"] == kind:
						grid.add_child(_cosmetic_card(entry))
	_info = _rich("", 18)
	column.add_child(_info)
	if _page == "chests" and not _last_chest.is_empty():
		_info.text = "[center]" + _chest_result_text() + "[/center]"
	column.add_child(_back_button("vault"))


func _chest_card(chest: Dictionary) -> Control:
	var id: String = chest["id"]
	var price := int(chest["price"])
	var pool := MetaState.chest_pool(_db, id)
	var missing := pool.filter(func(p: Array) -> bool: return not _owns(p[0], p[1])).size()
	var card := _panel(Vector2(300, 260), Cosmetics.back_colors()["border"])
	var box := _box(card)
	box.add_child(_centered(Emblem.create("pack", 56)))
	box.add_child(_text_label(tr("CHEST_" + id.to_upper()), 24, Palette.GOLD))
	box.add_child(_rich(tr("CHEST_" + id.to_upper() + "_DESC") + "\n" + tr("UI_CHEST_MISSING") % [missing, pool.size()], 15))
	var open := _button(tr("UI_BUY_FOR") % price, Vector2(200, 50), func() -> void:
		_last_chest = _meta.open_chest(_db, id, _rng)
		_meta.save()
		_show("chests")
		_play_chest(id))
	open.disabled = _meta.glut < price
	box.add_child(open)
	return card


## The chest opens with the pack animation; every find is a card.
func _play_chest(id: String) -> void:
	if _last_chest.is_empty():
		return
	var cards: Array = []
	for found in _last_chest:
		cards.append({"face": _find_face(found), "rarity": FIND_RARITY.get(found["kind"], 1),
			# Every legendary skin find gets its big reveal, also a duplicate.
			"skin": found["id"] if found["kind"] == "skins" else ""})
	var opening := PackOpening.create(cards, tr("CHEST_" + id.to_upper()))
	add_child(opening)


## The face of a chest find: its card, plus "neu!" or the duplicate refund.
func _find_face(found: Dictionary) -> Control:
	var kind: String = found["kind"]
	var id: String = found["id"]
	var face: Control
	match kind:
		"figures":
			face = _scaled(UnitCard.for_definition(_db.figures[id], 1, false), 1.15)
		"skins":
			var figure_id := String(MetaState.cosmetic(_db, id)["figure"])
			var worn := Cosmetics.skins.duplicate()
			Cosmetics.skins[figure_id] = id
			face = _scaled(UnitCard.for_definition(_db.figures[figure_id], 1, false), 1.15)
			Cosmetics.skins = worn
		"relics", "tarot", "pacts":
			var object_kind: String = {"relics": "relic", "tarot": "tarot", "pacts": "pact"}[kind]
			face = ObjectCard.create(_db, {"kind": object_kind, "id": id}, Vector2(150, 222))
		_:
			var panel := _panel(Vector2(150, 222), Palette.GOLD)
			var box := _box(panel)
			box.add_child(_centered(Emblem.create("skull", 46)))
			box.add_child(_text_label(_content_name(kind, id), 20, Palette.GOLD))
			box.add_child(_text_label(tr("CHEST_EVENTS"), 13, Palette.MUTED))
			face = panel
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_centered(face))
	var note := tr("UI_CHEST_NEW") if found["new"] else tr("UI_CHEST_DUPLICATE") % int(_db.meta["duplicate_refund"])
	column.add_child(_text_label(note, 16, Color("ffe08a") if found["new"] else Palette.MUTED))
	return column


func _celebrate(emblem: String, title: String, color: Color, big: bool) -> void:
	add_child.call_deferred(UnlockFlash.create(emblem, title, color, big))


func _chest_result_text() -> String:
	var parts: Array = []
	for found in _last_chest:
		var name := _content_name(found["kind"], found["id"])
		if found["new"]:
			parts.append("[color=#ffe08a][b]%s[/b] – %s[/color]" % [name, tr("UI_CHEST_NEW")])
		else:
			parts.append("[color=#9a9488]%s – %s[/color]" % [name, tr("UI_CHEST_DUPLICATE") % int(_db.meta["duplicate_refund"])])
	return "   ·   ".join(parts)


func _upgrade_card(entry: Dictionary) -> Control:
	var id: String = entry["id"]
	var level := int(_meta.upgrades.get(id, 0))
	var max_level: int = entry["prices"].size()
	var price := _meta.upgrade_price(_db, id)
	var card := _panel(Vector2(300, 250), Palette.GOLD if level > 0 else Color(1, 1, 1, 0.25))
	var box := _box(card)
	box.add_child(_text_label(tr("UPGRADE_" + id.to_upper()), 24, Palette.GOLD))
	box.add_child(_rich(tr("UPGRADE_" + id.to_upper() + "_DESC"), 15))
	box.add_child(_text_label(tr("UI_UPGRADE_LEVEL") % [level, max_level], 18, Palette.PARCHMENT))
	if price < 0:
		box.add_child(_text_label(tr("UI_MAXED"), 20, Palette.MUTED))
	else:
		var buy := _button(tr("UI_BUY_FOR") % price, Vector2(200, 50), func() -> void:
			if _meta.buy_upgrade(_db, id):
				_meta.save()
				_celebrate("star", tr("UPGRADE_" + id.to_upper()), Palette.GOLD, false)
			_show("altar"))
		buy.disabled = _meta.glut < price
		box.add_child(buy)
	return card


func _portrait_card(entry: Dictionary) -> Control:
	var id: String = entry["id"]
	var owned := id in _meta.occultists
	var card := _panel(Vector2(320, 280), Palette.GOLD if owned else Color(1, 1, 1, 0.25))
	var box := _box(card)
	box.add_child(_text_label(tr("OCC_" + id.to_upper()), 26, Palette.GOLD))
	box.add_child(_rich(tr("OCC_" + id.to_upper() + "_RULE"), 15))
	box.add_child(_rich("[color=#%s]%s[/color]" % [Palette.MUTED.to_html(false),
		tr("UI_OCC_CHALLENGE") % tr("CHALLENGE_" + String(entry["challenge"]).to_upper())], 15))
	if owned:
		box.add_child(_text_label(tr("UI_OWNED"), 20, Palette.LIFE))
	else:
		var buy := _button(tr("UI_BUY_FOR") % int(entry["price"]), Vector2(200, 50), func() -> void:
			if _meta.buy_occultist(_db, id):
				_meta.save()
				_celebrate(OCCULTIST_EMBLEMS.get(id, "skull"), tr("OCC_" + id.to_upper()), Palette.GOLD, true)
			_show("portraits"))
		buy.disabled = _meta.glut < int(entry["price"])
		box.add_child(buy)
	return card


func _cosmetic_card(entry: Dictionary) -> Control:
	var id: String = entry["id"]
	var owned := id in _meta.cosmetics
	var worn := _is_worn(entry)
	var card := _panel(Vector2(240, 200), Palette.GOLD if worn else (Palette.PARCHMENT if owned else Color(1, 1, 1, 0.2)))
	var box := _box(card)
	box.add_child(_text_label(tr("COSMETIC_KIND_" + String(entry["kind"]).to_upper()), 14, Palette.MUTED))
	box.add_child(_text_label(tr("COSMETIC_" + id.to_upper()), 20, Palette.GOLD if owned else Palette.PARCHMENT))
	if entry["kind"] == "back":
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(46, 30)
		swatch.color = Color(Cosmetics.BACKS[id]["bg"])
		box.add_child(_centered(swatch))
	if owned:
		box.add_child(_button(tr("UI_WORN") if worn else tr("UI_WEAR"), Vector2(170, 46), func() -> void:
			_meta.equip(_db, id)
			_meta.save()
			Cosmetics.apply(_meta)
			_show("mirror")))
	elif entry["kind"] == "skin":
		box.add_child(_rich("[color=#%s]%s[/color]" % [Palette.MUTED.to_html(false), tr("UI_SKIN_FROM_CHEST")], 13))
		box.add_child(_buy_cosmetic_button(id, int(entry["price"])))
	else:
		box.add_child(_buy_cosmetic_button(id, int(entry["price"])))
	return card


func _buy_cosmetic_button(id: String, price: int) -> Button:
	var buy := _button(tr("UI_BUY_FOR") % price, Vector2(170, 46), func() -> void:
		if _meta.buy_cosmetic(_db, id):
			_meta.save()
			if MetaState.cosmetic(_db, id).get("rarity", "") == "legendary":
				_show("mirror")
				add_child(LegendaryReveal.create(id))
				return
			_celebrate("soul", tr("COSMETIC_" + id.to_upper()), Color("ffb060"), false)
		_show("mirror"))
	buy.disabled = _meta.glut < price
	return buy


func _is_worn(entry: Dictionary) -> bool:
	if entry["kind"] == "skin":
		return _meta.equipped["skins"].get(entry["figure"], "") == entry["id"]
	return _meta.equipped.get(entry["kind"], "") == entry["id"]


func _owns(kind: String, id: String) -> bool:
	return id in _meta.cosmetics if kind == "skins" else _meta.is_unlocked(kind, id)


# --- Grimoire ------------------------------------------------------------------------------

func _build_grimoire(column: VBoxContainer) -> void:
	column.add_child(_header(tr("UI_GRIMOIRE_TITLE")))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for tab in GRIMOIRE_TABS:
		var all := _grimoire_entries(tab)
		var known := all.filter(func(id: String) -> bool: return _known(tab, id)).size()
		var button := _button("%s %d/%d" % [tr("GRIMOIRE_" + tab.to_upper()), known, all.size()], Vector2(0, 46), func() -> void:
			_tab = tab
			_show("grimoire"))
		button.add_theme_font_size_override("font_size", 17)
		if tab == _tab:
			button.add_theme_color_override("font_color", Palette.GOLD)
		tabs.add_child(button)
	column.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for id in _grimoire_entries(_tab):
		grid.add_child(_grimoire_card(_tab, id))
	_info = _rich(tr("UI_GRIMOIRE_HINT"), 16)
	column.add_child(_info)
	column.add_child(_back_button("menu"))


## One picture card: figures and enemies as their animated pixel figure,
## objects with their emblem; tapping opens the full description.
func _grimoire_card(tab: String, id: String) -> Control:
	if not _known(tab, id):
		var unknown := _panel(Vector2(112, 150), Color(1, 1, 1, 0.15))
		var box := _box(unknown)
		box.add_child(_centered(Emblem.create("star", 34)))
		box.get_child(0).modulate = Color(0.3, 0.3, 0.35)
		box.add_child(_text_label("???", 26, Palette.MUTED))
		return unknown
	match tab:
		"figures", "recipes", "enemies":
			var enemy := tab == "enemies"
			var definition: Dictionary = _db.enemies[id] if enemy else _db.figures[id]
			var card := UnitCard.for_definition(definition, 1, enemy)
			if detail_panel != null:
				card.tapped.connect(detail_panel.show_card)
			return _scaled(card, 0.9)
		"relics", "tarot", "pacts":
			var kind: String = {"relics": "relic", "tarot": "tarot", "pacts": "pact"}[tab]
			var object := ObjectCard.create(_db, {"kind": kind, "id": id}, Vector2(150, 222))
			if detail_panel != null:
				object.tapped.connect(detail_panel.show_object)
			return object
	# Master abilities: the two suits of the combination and the effect.
	var master := Fusion.master_by_id(_db, id)
	var panel := _panel(Vector2(200, 222), Palette.GOLD)
	# Master abilities wear the polychrome legend face (they crown an F3 fusion).
	var panel_style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.border_color = Color(0, 0, 0, 0)
	var face_holder := Control.new()
	face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(face_holder)
	var face := CardArt.face_rect(CardArt.for_unit({"rank": "legend", "suit": master["suits"][0]}, false, master["suits"][0], Vector2(200, 222)))
	face_holder.add_child(face)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = -12
	face.offset_top = -10
	face.offset_right = 12
	face.offset_bottom = 10
	var box := _box(panel)
	var suits := HBoxContainer.new()
	suits.alignment = BoxContainer.ALIGNMENT_CENTER
	for suit in master.get("suits", []):
		suits.add_child(Emblem.create("suit_" + String(suit), 34))
	box.add_child(suits)
	box.add_child(_text_label(_content_name(tab, id), 19, Palette.GOLD))
	box.add_child(_rich(_content_text(tab, id), 14))
	return panel


## Debug mode ("?debug=1") shows the whole grimoire.
func _known(tab: String, id: String) -> bool:
	return _debug or _meta.is_discovered(tab, id)


func _scaled(content: Control, factor: float) -> Control:
	var holder := Control.new()
	holder.add_child(content)
	content.scale = Vector2(factor, factor)
	var minimum := content.get_combined_minimum_size()
	content.size = minimum
	holder.custom_minimum_size = minimum * factor
	return holder


func _grimoire_entries(tab: String) -> Array:
	var ids: Array = []
	match tab:
		"figures":
			for f in _db.figures.values():
				if not f.get("recipe", false):
					ids.append(f["id"])
		"recipes":
			for f in _db.figures.values():
				if f.get("recipe", false):
					ids.append(f["id"])
		"relics":
			ids = _db.items["relics"].map(func(r: Dictionary) -> String: return r["id"])
		"tarot":
			ids = _db.items["tarot"].duplicate()
		"pacts":
			ids = _db.items["pacts"].duplicate()
		"masters":
			ids = _db.fusion["masters"].map(func(m: Dictionary) -> String: return m["id"])
		"enemies":
			for e in _db.enemies.values():
				ids.append(e["id"])
	ids.sort()
	return ids


func _content_name(kind: String, id: String) -> String:
	match kind:
		"figures", "recipes":
			return ContentDb.display_name(_db.figures[id])
		"enemies":
			return ContentDb.display_name(_db.enemies[id])
		"relics":
			return ItemText.relic_name(id)
		"tarot":
			return ItemText.tarot_name(id)
		"pacts":
			return tr("PACT_" + id.to_upper())
		"masters":
			return tr("MASTER_" + id.to_upper())
		"events":
			return tr("EVENT_" + id.to_upper())
		"skins":
			return tr("COSMETIC_" + id.to_upper())
	return id


func _content_text(kind: String, id: String) -> String:
	match kind:
		"figures", "recipes", "enemies":
			var definition: Dictionary = _db.figures[id] if kind != "enemies" else _db.enemies[id]
			var stats := "%d/%d" % [int(definition.get("attack", 0)), int(definition.get("health", 0))]
			if not definition.has("ability"):
				return stats
			var ability: Dictionary = definition["ability"]
			var text := tr("ABIL_" + id.to_upper())
			return stats + " · " + text.replace("{v}", NumberFormat.ability_value(ability["effect"], ability["values"][0]))
		"relics":
			return ItemText.relic_text(id)
		"tarot":
			return ItemText.tarot_text(id)
		"pacts":
			return tr("PACT_" + id.to_upper() + "_DESC")
		"masters":
			return tr("MASTER_" + id.to_upper() + "_DESC")
	return ""


# --- Building blocks -------------------------------------------------------------------

func _glut_badge() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(Emblem.create("soul", 30))
	row.add_child(_label(tr("UI_GLUT") % _meta.glut, 28, Color("ffb060")))
	return row


func _header(text: String) -> Label:
	var label := _label(text, 42, Palette.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _back_button(page: String) -> Control:
	return _centered(_button(tr("UI_BACK"), Vector2(220, 54), _show.bind(page)))


func _panel(min_size: Vector2, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.065, 0.1, 0.94)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _box(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _centered(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(control)
	return center


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _text_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _rich(text: String, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", Palette.PARCHMENT)
	label.text = "[center]" + Keywords.colorize(text) + "[/center]" if text != "" else ""
	return label


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button
