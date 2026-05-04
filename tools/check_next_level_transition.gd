extends SceneTree

func _initialize() -> void:
	var state = get_root().get_node_or_null("ProjectState")
	if state == null:
		printerr("PROJECT_STATE_MISSING")
		quit(1)
		return

	state.start_level(0)
	var first_scene: String = str(state.get_current_scene())
	var first := ResourceLoader.load(first_scene) as PackedScene
	if first == null:
		printerr("FIRST_LEVEL_LOAD_FAILED %s" % first_scene)
		quit(1)
		return

	var root := first.instantiate()
	get_root().add_child(root)
	await process_frame

	var game_manager := root.get_node_or_null("GameManager") as GameManager
	if game_manager == null:
		printerr("GAME_MANAGER_MISSING")
		quit(1)
		return

	game_manager.call("_load_next_level")
	await process_frame
	await process_frame

	if state.current_level_index != 1:
		printerr("NEXT_LEVEL_INDEX_FAILED index=%d" % state.current_level_index)
		quit(1)
		return

	var second_scene: String = str(state.get_current_scene())
	if second_scene != "res://scenes/levels/level_02.tscn":
		printerr("NEXT_LEVEL_SCENE_FAILED %s" % second_scene)
		quit(1)
		return

	print("NEXT_LEVEL_TRANSITION_OK %s" % second_scene)
	quit(0)
