extends GutTest
## Smoke test: UI scenes load, compile and survive a few frames.


func test_battle_scene_runs() -> void:
	var scene: PackedScene = load("res://scenes/battle.tscn")
	assert_not_null(scene)
	var view: Node = scene.instantiate()
	add_child_autofree(view)
	await wait_frames(3)
	assert_true(is_instance_valid(view))
