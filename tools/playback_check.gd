extends SceneTree
## Debug helper: plays several battles in the real battle view (headless, 4x)
## so script errors during playback show up in the console.

func _init() -> void:
	var view: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(view)
	await process_frame
	view._set_speed(4.0)
	for i in 6:
		view._new_battle()
		view._start_battle()
		var waited := 0.0
		while waited < 25.0 and view._banner.text != tr("UI_VICTORY") and view._banner.text != tr("UI_DEFEAT") and view._banner.text != tr("UI_DRAW"):
			await create_timer(0.5).timeout
			waited += 0.5
		print("battle %d finished=%s after %.1fs events=%d" % [i, waited < 25.0, waited, view._battle["events"].size()])
	quit()
