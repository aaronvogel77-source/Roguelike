class_name NumberFormat
extends RefCounted
## Locale-aware number display (German uses a decimal comma).


## 1.5 -> "1,5" (de) / "1.5" (en); whole numbers without decimals; max 2 decimals.
static func decimal(value: float) -> String:
	var text := ("%.2f" % value).rstrip("0").rstrip(".")
	if TranslationServer.get_locale().begins_with("de"):
		text = text.replace(".", ",")
	return text


## Formats an ability value for its description text.
static func ability_value(effect: String, value: float) -> String:
	if effect == "lifesteal":
		return str(int(round(value * 100)))
	return decimal(value)
