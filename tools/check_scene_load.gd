extends SceneTree

func _initialize() -> void:
	var scene := ResourceLoader.load("res://scenes/prototyyppi.tscn")
	if scene == null:
		printerr("FAILED_TO_LOAD_SCENE")
		quit(1)
		return

	print("SCENE_LOAD_OK")
	quit(0)
