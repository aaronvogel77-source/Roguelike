extends GutTest
## The translation table must keep exactly three columns per row (key, de, en):
## an unquoted comma silently cuts a German text short in the game.


func test_every_row_has_key_german_and_english() -> void:
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	assert_not_null(file)
	var line_number := 0
	var bad: Array = []
	while not file.eof_reached():
		var fields := file.get_csv_line()
		line_number += 1
		if fields.size() == 1 and fields[0] == "":
			continue  # trailing empty line
		if fields.size() != 3:
			bad.append("%d: %s" % [line_number, fields[0]])
	assert_eq(bad, [], "rows with a wrong column count (quote texts that contain commas)")
