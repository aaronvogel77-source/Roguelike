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
		await process_frame  # the previous summary is freed at the end of the frame
		view._start_battle()
		var waited := 0.0
		# The end shows the summary overlay (it also clears the result banner).
		while waited < 25.0 and not is_instance_valid(view._summary):
			await create_timer(0.5).timeout
			waited += 0.5
		print("battle %d finished=%s after %.1fs events=%d" % [i, waited < 25.0, waited, view._battle["events"].size()])
	quit()
