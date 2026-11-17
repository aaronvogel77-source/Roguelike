class_name ItemText
extends RefCounted
## Names and description lines for objects (equipment, relics, tarot, packs).

## Common, magic, rare, cursed, unique (turquoise silver).
const RARITY_COLORS := [Color(0.75, 0.72, 0.65), Color(0.4, 0.6, 1.0), Color(0.95, 0.78, 0.3), Color(0.75, 0.25, 0.85), Color(0.45, 0.95, 0.88)]


static func equipment_name(item: Dictionary) -> String:
	return TranslationServer.translate("EQUIP_" + String(item["base"]).to_upper())


static func rarity_name(rarity: int) -> String:
	return TranslationServer.translate("RARITY_%d" % rarity)


## One line per effect: base effect, affixes, drawback (prefixed with "–").
static func equipment_lines(db: ContentDb, item: Dictionary) -> Array:
	var lines: Array = []
	var base: Dictionary = _find(db.items["equipment"], item["base"])["base"]
	var base_value: Variant = base.get("value", base.get("ability", {}).get("values", [0])[0])
	var t := TranslationServer
	lines.append(t.translate("UI_BASE_EFFECT") + ": " + _fill("EQUIP_%s_DESC" % String(item["base"]).to_upper(), base_value))
	for affix in item["affixes"]:
		lines.append(t.translate("UI_EXTRA_EFFECT") + ": " + _fill("AFFIX_" + String(affix["id"]).to_upper(), affix["value"]))
	if not item.get("drawback", {}).is_empty():
		lines.append(t.translate("UI_DRAWBACK") + ": " + _fill("AFFIX_" + String(item["drawback"]["id"]).to_upper(), item["drawback"]["value"]))
	if item.has("unique"):
		lines.append(t.translate("UI_UNIQUE_EFFECT") + ": " + t.translate("UNIQUE_" + String(item["unique"]).to_upper()))
	return lines


## "Magisch – +1 Zusatzeffekt".
static func rarity_line(rarity: int) -> String:
	return "%s – %s" % [rarity_name(rarity), TranslationServer.translate("RARITY_%d_DESC" % rarity)]


static func relic_name(relic_id: String) -> String:
	return TranslationServer.translate("RELIC_" + relic_id.to_upper())


static func relic_text(relic_id: String) -> String:
	return TranslationServer.translate("RELIC_" + relic_id.to_upper() + "_DESC")


static func tarot_name(tarot_id: String) -> String:
	return TranslationServer.translate("TAROT_" + tarot_id.to_upper())


static func tarot_text(tarot_id: String) -> String:
	return TranslationServer.translate("TAROT_" + tarot_id.to_upper() + "_DESC")


static func pack_name(pack: Dictionary) -> String:
	var name := TranslationServer.translate("PACK_" + String(pack["type"]).to_upper())
	var size := TranslationServer.translate("PACK_SIZE_" + String(pack["size"]).to_upper())
	var full: String = name if size == "" or size == "PACK_SIZE_NORMAL" else "%s (%s)" % [name, size]
	if pack.get("loot", false):
		return TranslationServer.translate("PACK_LOOT") % full
	return full


static func _fill(key: String, value: Variant) -> String:
	var text := TranslationServer.translate(key)
	var shown := NumberFormat.decimal(float(value)) if value is float else str(value)
	return text.replace("{v}", shown)


static func _find(list: Array, id: String) -> Dictionary:
	for entry in list:
		if entry["id"] == id:
			return entry
	return {}
