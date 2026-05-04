extends SceneTree

func _initialize() -> void:
	var state = get_root().get_node_or_null("ProjectState")
	if state == null:
		printerr("PROJECT_STATE_MISSING")
		quit(1)
		return

	var level_count: int = int(state.get_level_count())
	if level_count <= 0:
		printerr("LEVEL_CATALOG_EMPTY")
		quit(1)
		return

	for i in range(level_count):
		var scene_path: String = str(state.level_scenes[i])
		var level_name: String = str(state.get_level_name(i))
		if scene_path.is_empty() or level_name.is_empty():
			printerr("LEVEL_CATALOG_BAD_ENTRY index=%d scene=%s name=%s" % [i, scene_path, level_name])
			quit(1)
			return

		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			printerr("LEVEL_CATALOG_SCENE_LOAD_FAILED index=%d scene=%s" % [i, scene_path])
			quit(1)
			return

		var root := packed.instantiate()
		get_root().add_child(root)
		await process_frame

		var camera := root.get_node_or_null("Camera2D") as Camera2D
		var goal := root.get_node_or_null("GoalZone") as GoalZone
		if camera == null or goal == null:
			printerr("LEVEL_CATALOG_CONTRACT_FAILED index=%d camera=%s goal=%s" % [i, camera != null, goal != null])
			quit(1)
			return
		if camera.zoom != Vector2(0.7, 0.7):
			printerr("LEVEL_CAMERA_ZOOM_FAILED index=%d zoom=%s" % [i, camera.zoom])
			quit(1)
			return

		root.queue_free()

	print("LEVEL_CATALOG_OK count=%d" % level_count)
	quit(0)
