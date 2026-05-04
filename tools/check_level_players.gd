extends SceneTree

const SCENES := [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/level_04.tscn",
	"res://scenes/prototyyppi.tscn",
]
const PLAYER_RIG := "res://scenes/player/player_rig.tscn"

func _initialize() -> void:
	var rig := ResourceLoader.load(PLAYER_RIG) as PackedScene
	if rig == null:
		printerr("FAILED_PLAYER_RIG_LOAD %s" % PLAYER_RIG)
		quit(1)
		return

	for scene_path in SCENES:
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			printerr("FAILED_LOAD %s" % scene_path)
			quit(1)
			return
		var root := packed.instantiate()
		get_root().add_child(root)
		await process_frame
		var player := root.get_node_or_null("Flaibai") as PlayerController2D
		var body := root.get_node_or_null("Flaibai/Body") as RigidBody2D
		var left_foot := root.get_node_or_null("Flaibai/LeftFoot") as FootContact2D
		var right_foot := root.get_node_or_null("Flaibai/RightFoot") as FootContact2D
		var head := root.get_node_or_null("Flaibai/HeadContact") as HeadContact2D
		var visual_root := root.get_node_or_null("Flaibai/VisualRoot") as Node2D
		var game_manager := root.get_node_or_null("GameManager") as GameManager
		var goal_zone := root.get_node_or_null("GoalZone") as GoalZone
		var scoreboard := root.get_node_or_null("RetryLayer/ScoreboardUI") as ScoreboardUI
		var uses_player_rig := player != null and player.scene_file_path == PLAYER_RIG
		if player == null or body == null or left_foot == null or right_foot == null or head == null or visual_root == null or game_manager == null or goal_zone == null or scoreboard == null or not uses_player_rig:
			printerr("FAILED_LEVEL_CONTRACT %s player=%s body=%s left_foot=%s right_foot=%s head=%s visual=%s game_manager=%s goal_zone=%s scoreboard=%s rig=%s" % [
				scene_path,
				player != null,
				body != null,
				left_foot != null,
				right_foot != null,
				head != null,
				visual_root != null,
				game_manager != null,
				goal_zone != null,
				scoreboard != null,
				uses_player_rig,
			])
			quit(1)
			return
		root.queue_free()

	print("LEVEL_PLAYERS_OK")
	quit(0)
