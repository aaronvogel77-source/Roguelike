class_name FusionView
extends ColorRect
## Full-screen fusion overlay: pick a main figure and a partner from the row,
## see the result (stats, stage, master ability, cost), choose which
## abilities stay, then fuse - or skip. Shown whenever the run has a
## fusion offer (altar, after a boss, ritual candle, blood moon).

## The run changed (a fusion happened or the offer ended): rebuild the screen.
signal finished(message_title: String, message_text: String)

const CARD_SCALE := 1.25

var _run: RunState
var _db: ContentDb
var _detail: DetailPanel
var _main := -1
var _partner := -1
var _keep: Array = []
var _confirm := false


static func create(run: RunState, db: ContentDb, detail: DetailPanel) -> FusionView:
	var view := FusionView.new()
	view._run = run
	view._db = db
	view._detail = detail
	view.color = Color(0.03, 0.01, 0.04, 0.96)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view._rebuild()
	return view


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(_label(_source_text(), 30, Palette.GOLD))

	var preview := Fusion.preview(_run, _main, _partner) if _main >= 0 and _partner >= 0 else {}
	column.add_child(_label(_hint_text(preview), 21, Palette.PARCHMENT))
	column.add_child(_centered(_row_cards()))
	if not preview.is_empty():
		column.add_child(_centered(_preview_box(preview)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var block := _run.fusion_block(_main, _partner) if not preview.is_empty() else "pick"
	var choosing: bool = int(preview.get("keep", 0)) < preview.get("candidates", []).size()
	var ready: bool = block == "" and (preview.get("recipe", "") != "" or not choosing or _keep.size() == int(preview.get("keep", 0)))
	var fuse := _button(tr("UI_FUSION_CONFIRM") if _confirm else tr("UI_FUSE"), Vector2(360 if _confirm else 260, 60), _on_fuse)
	fuse.disabled = not ready
	if _confirm:
		fuse.add_theme_color_override("font_color", Palette.GOLD)
	buttons.add_child(fuse)
	buttons.add_child(_button(tr("UI_FUSION_SKIP"), Vector2(260, 60), _on_skip))
	column.add_child(buttons)


func _source_text() -> String:
	var source: String = _run.fusion_offer.get("source", "")
	if source == "blood_moon":
		var left := int(_run.fusion_offer.get("left", 1))
		return tr("UI_FUSION_SOURCE_BLOOD_MOON_ONE") if left == 1 else tr("UI_FUSION_SOURCE_BLOOD_MOON") % left
	return tr("UI_FUSION_SOURCE_" + source.to_upper())


func _hint_text(preview: Dictionary) -> String:
	if _main < 0:
		return tr("UI_FUSION_PICK_MAIN")
	if _partner < 0:
		return tr("UI_FUSION_PICK_PARTNER")
	match preview.get("reason", ""):
		"final":
			return tr("UI_FUSION_REASON_FINAL")
		"too_many":
			return tr("UI_FUSION_REASON_TOO_MANY")
	if _run.fusion_block(_main, _partner) == "souls":
		return tr("UI_FUSION_REASON_SOULS")
	if preview.get("recipe", "") != "":
		return tr("UI_FUSION_SECRET_HINT")
	if int(preview["keep"]) < preview["candidates"].size():
		return tr("UI_FUSION_CHOOSE") % [int(preview["keep"]), _keep.size()]
	return tr("UI_FUSION_ALL_KEPT")


## The own row (front on the right, as everywhere): tap main, then partner.
func _row_cards() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var team := _run.player_battle_team()
	for i in range(_run.row.size() - 1, -1, -1):
		var figure: Variant = _run.row[i]
		if figure == null:
			continue
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var card := UnitCard.for_entry(team[_entry_index(i)], figure, _db)
		# A flat button under the card takes the tap (reliable on touch).
		var hit := Button.new()
		hit.flat = true
		hit.custom_minimum_size = card.card_size
		hit.pressed.connect(func() -> void: _on_card(i))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit.add_child(card)
		if i != _main and i != _partner and (_main >= 0 and _partner >= 0):
			card.body.modulate = Color(0.6, 0.6, 0.6)
		box.add_child(hit)
		var tag := ""
		if i == _main:
			tag = tr("UI_FUSION_MAIN")
		elif i == _partner:
			tag = tr("UI_FUSION_PARTNER")
		box.add_child(_label(tag, 16, Palette.GOLD))
		row.add_child(box)
	return _scaled(row, CARD_SCALE)


## Index into the battle team for a row slot (empty slots are skipped there).
func _entry_index(row_index: int) -> int:
	var k := 0
	for i in row_index:
		if _run.row[i] != null:
			k += 1
	return k


func _preview_box(preview: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.1)
	style.border_color = Palette.GOLD.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	if preview["reason"] != "":
		row.add_child(_label(_hint_text(preview), 20, Palette.HEALTH))
		return panel

	var secret: bool = preview["recipe"] != ""
	row.add_child(_secret_card() if secret else _result_card(preview))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.custom_minimum_size = Vector2(300, 0)
	row.add_child(info)
	if not secret:
		info.add_child(_label(tr("UI_FUSION_STAGE") % int(preview["stage"]) + "  ·  %d / %d" % [preview["attack"], preview["health"]], 24, Palette.GOLD))
		info.add_child(_label(tr("UI_FUSION_RESET"), 17, Palette.MUTED))
		if preview["master"] != "":
			var master_key := "MASTER_" + String(preview["master"]).to_upper()
			info.add_child(_rich(tr("UI_FUSION_MASTER") % ("[b]%s[/b]" % tr(master_key)) + "\n" + tr(master_key + "_DESC"), 17, 300))
	var source: String = _run.fusion_offer.get("source", "")
	info.add_child(_label(tr("UI_FUSION_COST") % int(preview["cost"]) if source == "altar" else tr("UI_FUSION_FREE"), 19, Palette.GOLD))
	var partner: Dictionary = _run.row[_partner]
	if partner.has("equipment") or partner.has("blessing") or int(partner.get("strength", 0)) > 0:
		info.add_child(_rich("[color=#%s]%s[/color]" % [Palette.HEALTH.to_html(false), tr("UI_FUSION_LOST_OBJECTS")], 16, 300))
	if not secret and not preview["candidates"].is_empty():
		row.add_child(_ability_list(preview))
	return panel


func _result_card(preview: Dictionary) -> Control:
	var figure := {"def_id": _run.row[_main]["def_id"], "fusion": {"parts": preview["parts"], "suits": preview["suits"],
		"abilities": [], "attack": preview["attack"], "health": preview["health"]}}
	var card := UnitCard.for_definition(Fusion.definition(_db, figure), 1, false)
	return _scaled(card, 1.3)


func _secret_card() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.02, 0.06)
	style.border_color = Color(0.95, 0.3, 0.4)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.95, 0.3, 0.4, 0.6)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = UnitCard.CARD_SIZE * 1.3
	var label := _label(tr("UI_FUSION_SECRET"), 48, Color(0.95, 0.5, 0.55))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


## One toggle per ability that can stay (texts at level 1: the fusion restarts).
func _ability_list(preview: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label(tr("UI_FUSION_ABILITIES"), 18, Palette.MUTED))
	var choosing: bool = int(preview["keep"]) < preview["candidates"].size()
	var candidates: Array = preview["candidates"]
	for i in candidates.size():
		var id: String = candidates[i]
		var ability: Dictionary = _db.figures[id]["ability"]
		var text := tr("ABIL_" + id.to_upper()).replace("{v}", NumberFormat.ability_value(ability["effect"], float(ability["values"][0])))
		var button := Button.new()
		button.custom_minimum_size = Vector2(420, 0)
		button.toggle_mode = true
		button.button_pressed = (not choosing) or i in _keep
		button.disabled = not choosing
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.add_theme_font_size_override("font_size", 15)
		button.text = "%s: %s" % [tr(ContentDb.name_key(_db.figures[id])), text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggled.connect(func(on: bool) -> void: _on_toggle(i, on, int(preview["keep"])))
		box.add_child(button)
	return box


func _on_card(index: int) -> void:
	_confirm = false
	if index == _main:
		_main = _partner
		_partner = -1
	elif index == _partner:
		_partner = -1
	elif _main < 0:
		_main = index
	else:
		_partner = index
	_keep.clear()
	_rebuild()


func _on_toggle(index: int, on: bool, limit: int) -> void:
	_confirm = false
	if on and not index in _keep and _keep.size() < limit:
		_keep.append(index)
	elif not on:
		_keep.erase(index)
	_rebuild()


func _on_fuse() -> void:
	if not _confirm:
		_confirm = true
		_rebuild()
		return
	var preview := Fusion.preview(_run, _main, _partner)
	var keep_ids: Array = _keep.map(func(i: int) -> String: return preview["candidates"][i])
	if not _run.fuse(_main, _partner, keep_ids):
		_confirm = false
		_rebuild()
		return
	var title := ""
	var text := ""
	if preview["recipe"] != "":
		var name := tr(ContentDb.name_key(_db.figures[preview["recipe"]]))
		title = tr("UI_FUSION_DISCOVERED") % name
		text = tr("ABIL_" + String(preview["recipe"]).to_upper()).replace("{v}",
			NumberFormat.ability_value(_db.figures[preview["recipe"]]["ability"]["effect"], float(_db.figures[preview["recipe"]]["ability"]["values"][0])))
	_main = -1
	_partner = -1
	_keep.clear()
	_confirm = false
	finished.emit(title, text)


func _on_skip() -> void:
	_run.decline_fusion()
	finished.emit("", "")


# --- Small builders -----------------------------------------------------------------

func _label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _rich(text: String, font_size: int, width: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", Palette.PARCHMENT)
	label.text = Keywords.colorize(text)
	return label


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button


func _centered(control: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(control)
	return center


func _scaled(content: Control, factor: float) -> Control:
	var holder := Control.new()
	holder.add_child(content)
	content.scale = Vector2(factor, factor)
	var minimum := content.get_combined_minimum_size()
	content.size = minimum
	holder.custom_minimum_size = minimum * factor
	return holder
