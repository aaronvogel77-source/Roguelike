extends GutTest
## Keyword coloring for descriptions.


func test_colors_triggers_statuses_and_stats() -> void:
	var text := Keywords.colorize("Kampfbeginn: erhält Schild 2 und +1 Angriff.", false)
	assert_string_contains(text, "]Kampfbeginn[/color]")
	assert_string_contains(text, "]Schild[/color]")
	assert_string_contains(text, "]Angriff[/color]")


func test_statuses_and_stats_become_symbols() -> void:
	var text := Keywords.colorize("Kampfbeginn: erhält Schild 2 und +1 Angriff.")
	assert_string_contains(text, "]Kampfbeginn[/color]", "triggers stay words")
	assert_string_contains(text, "keywords/shield.png")
	assert_string_contains(text, "keywords/attack.png")
	assert_false(text.contains("Schild"), "the word is replaced by its symbol")
	assert_eq(Keywords.icon_kinds("Brennen 2, dann Blutung und Gold"), ["burn", "bleed", "gold"])
	for kind in Keywords.ICON_WORDS.values():
		assert_true(ResourceLoader.exists(Keywords.ICON_PATH % kind), "symbol file for " + kind)


func test_longest_keyword_wins() -> void:
	var text := Keywords.colorize("Kampfbeginn (zuletzt): Blutung")
	assert_string_contains(text, "]Kampfbeginn (zuletzt)[/color]")


func test_multiplier_is_colored() -> void:
	assert_string_contains(Keywords.colorize("erhält ×1,5 Angriff"), "]×1,5[/color]")


func test_plain_text_is_unchanged() -> void:
	assert_eq(Keywords.colorize("nichts besonderes"), "nichts besonderes")


func test_keywords_inside_other_words_stay_plain() -> void:
	assert_eq(Keywords.colorize("Die Goldene Mauer"), "Die Goldene Mauer")
