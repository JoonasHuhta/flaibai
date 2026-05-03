extends SceneTree

func _initialize() -> void:
	var scene := ResourceLoader.load("res://scenes/prototyyppi.tscn") as PackedScene
	if scene == null:
		printerr("FAILED_TO_LOAD_SCENE")
		quit(1)
		return

	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame

	var player := root.get_node_or_null("Flaibai")
	var body := root.get_node_or_null("Flaibai/Body") as RigidBody2D
	var visual_root := root.get_node_or_null("Flaibai/VisualRoot") as Node2D
	if player == null or body == null or visual_root == null:
		printerr("PLAYER_RUNTIME_MISSING")
		quit(1)
		return

	print("PLAYER_RUNTIME_OK body=%s visual=%s visible=%s" % [body.global_position, visual_root.global_position, visual_root.visible])
	quit(0)
