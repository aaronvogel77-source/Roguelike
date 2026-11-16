extends GutTest
## Keyword coloring for descriptions.


func test_colors_triggers_statuses_and_stats() -> void:
	var text := Keywords.colorize("Kampfbeginn: erhält Schild 2 und +1 Angriff.")
	assert_string_contains(text, "]Kampfbeginn[/color]")
	assert_string_contains(text, "]Schild[/color]")
	assert_string_contains(text, "]Angriff[/color]")


func test_longest_keyword_wins() -> void:
	var text := Keywords.colorize("Kampfbeginn (zuletzt): Blutung")
	assert_string_contains(text, "]Kampfbeginn (zuletzt)[/color]")


func test_multiplier_is_colored() -> void:
	assert_string_contains(Keywords.colorize("erhält ×1,5 Angriff"), "]×1,5[/color]")


func test_plain_text_is_unchanged() -> void:
	assert_eq(Keywords.colorize("nichts besonderes"), "nichts besonderes")
