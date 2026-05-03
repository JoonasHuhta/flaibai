extends SceneTree

func _initialize() -> void:
	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene"))
	var scene := ResourceLoader.load(main_scene_path) as PackedScene
	if scene == null:
		printerr("FAILED_TO_LOAD_MAIN_SCENE %s" % main_scene_path)
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	print("MAIN_SCENE_OK %s" % main_scene_path)
	quit(0)
