extends GutTest
## First-time hints: shown once, can be switched off and reset.


func before_each() -> void:
	Hints.set_enabled(true)
	Hints.reset()


func after_all() -> void:
	Hints.set_enabled(true)
	Hints.reset()


func test_a_hint_shows_once_and_points_at_its_target() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child_autofree(host)
	var target := Button.new()
	target.position = Vector2(500, 300)
	target.size = Vector2(120, 60)
	host.add_child(target)
	var note := Hints.show(host, "shop", target)
	assert_not_null(note)
	assert_null(Hints.show(host, "pack", target), "one note at a time")
	note._dismiss()
	assert_false(Hints.wants("shop"))
	await wait_seconds(0.4)
	assert_null(Hints.show(host, "shop", target), "never twice")


func test_hints_can_be_switched_off_and_reset() -> void:
	Hints.mark_seen("shop")
	Hints.set_enabled(false)
	assert_false(Hints.wants("pack"))
	Hints.set_enabled(true)
	Hints.reset()
	assert_true(Hints.wants("shop"))


func test_every_hint_has_a_text() -> void:
	for id in ["choice", "boss", "shop", "fight", "pack", "suit", "souls", "reward", "event", "danger", "fusion", "treasury"]:
		assert_ne(tr("HINT_" + id.to_upper()), "HINT_" + id.to_upper())
		assert_ne(tr("HINT_" + id.to_upper() + "_TITLE"), "HINT_" + id.to_upper() + "_TITLE")
