extends Area2D
class_name GoalZone

enum State {
	WAITING,
	ARMED,
	COMPLETE,
}

@export var player_path: NodePath
@export var game_manager_path: NodePath
@export var tuning: PlayerTuning
@export var half_width: float = 180.0
@export var half_height: float = 170.0
@export var contact_grace_time: float = 0.22
@export var clean_hold_time: float = 0.08
@export var sloppy_hold_time: float = 0.04
@export var crash_hold_time: float = 0.04
@export var finish_delay: float = 0.12
@export var instant_finish_max_speed: float = 2600.0
@export var sloppy_max_speed: float = 760.0
@export var sloppy_max_vertical_speed: float = 560.0
@export var sweep_extra_width: float = 35.0
@export var sweep_extra_height: float = 80.0
@export var progress_path: NodePath = ^"ProgressFill"
@export var glow_path: NodePath = ^"GlowZone"
@export var landing_pad_path: NodePath = ^"LandingPad"
@export var flag_gold_path: NodePath = ^"FlagGold"
@export var flag_dark_path: NodePath = ^"FlagDark"

var current_state: State = State.WAITING

var player: PlayerController2D
var game_manager: GameManager
var progress_fill: Node2D
var glow_zone: CanvasItem
var landing_pad: CanvasItem
var flag_gold: CanvasItem
var flag_dark: CanvasItem

var _hold_timer := 0.0
var _player_inside := false
var _inside_grace_timer := 0.0
var _completion_started := false
var _last_body_position := Vector2.INF
var _last_left_foot_position := Vector2.INF
var _last_right_foot_position := Vector2.INF
var _last_head_position := Vector2.INF
var _activation_pulse := 0.0
var _was_goal_active := false

func _ready() -> void:
	player = _resolve_player()
	game_manager = _resolve_game_manager()

	if tuning == null:
		tuning = PlayerTuning.new()
	progress_fill = get_node_or_null(progress_path) as Node2D
	glow_zone = get_node_or_null(glow_path) as CanvasItem
	landing_pad = get_node_or_null(landing_pad_path) as CanvasItem
	flag_gold = get_node_or_null(flag_gold_path) as CanvasItem
	flag_dark = get_node_or_null(flag_dark_path) as CanvasItem
	_update_goal_feedback()

	if player == null:
		push_error("GoalZone could not find Flaibai/PlayerController2D.")
	if game_manager == null:
		push_error("GoalZone could not find GameManager.")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_store_player_positions()

func _process(delta: float) -> void:
	if current_state == State.COMPLETE or _completion_started:
		_update_goal_feedback()
		_store_player_positions()
		return

	if player == null or game_manager == null:
		current_state = State.WAITING
		_update_goal_feedback()
		return

	var currently_inside := _is_player_inside_goal()
	var swept_inside := _did_player_sweep_through_goal()
	var finish_contact := currently_inside or swept_inside
	if finish_contact:
		_inside_grace_timer = contact_grace_time
		if not _was_goal_active:
			_activation_pulse = 1.0
		_was_goal_active = true
	else:
		_inside_grace_timer = maxf(_inside_grace_timer - delta, 0.0)
		if _inside_grace_timer <= 0.0:
			_was_goal_active = false
	_activation_pulse = maxf(_activation_pulse - delta * 3.8, 0.0)

	if _inside_grace_timer <= 0.0:
		_hold_timer = maxf(_hold_timer - delta * 2.0, 0.0)
		current_state = State.WAITING
		_update_goal_feedback()
		_store_player_positions()
		return

	var speed := player.body.linear_velocity.length()
	if finish_contact and speed <= instant_finish_max_speed:
		_hold_timer = tuning.goal_hold_time
		current_state = State.ARMED
		_complete_goal(not player.has_crashed())
	elif finish_contact:
		_hold_timer += delta
		current_state = State.ARMED
		if _hold_timer >= sloppy_hold_time:
			_complete_goal(not player.has_crashed())
	else:
		_hold_timer = maxf(_hold_timer - delta * 1.5, 0.0)
		current_state = State.WAITING
	_update_goal_feedback()
	_store_player_positions()

func _on_body_entered(body: Node2D) -> void:
	if player == null:
		return

	if body == player.body:
		_player_inside = true
		_inside_grace_timer = contact_grace_time

func _on_body_exited(body: Node2D) -> void:
	if player == null:
		return

	if body == player.body:
		_player_inside = false

func _complete_goal(play_celebration: bool = true) -> void:
	if _completion_started:
		return

	_completion_started = true
	current_state = State.COMPLETE
	_hold_timer = tuning.goal_hold_time
	_update_goal_feedback()
	if play_celebration and not player.has_crashed():
		player.celebrate()
	else:
		player.set_controls_enabled(false)
	get_tree().create_timer(finish_delay).timeout.connect(func():
		if game_manager != null:
			game_manager.complete_level()
	)

func _is_player_inside_goal() -> bool:
	if player == null or player.body == null:
		return false

	if _player_inside:
		return true

	if _is_world_position_inside(player.body.global_position):
		return true
	if _is_world_position_inside(player.left_foot.global_position):
		return true
	if _is_world_position_inside(player.right_foot.global_position):
		return true
	if player.head_contact != null and _is_world_position_inside(player.head_contact.global_position):
		return true

	return false

func _is_world_position_inside(world_position: Vector2) -> bool:
	var local := to_local(world_position)
	return absf(local.x) <= half_width and absf(local.y) <= half_height

func _did_player_sweep_through_goal() -> bool:
	if player == null or player.body == null:
		return false
	if _last_body_position == Vector2.INF:
		return false

	if _segment_hits_goal(_last_body_position, player.body.global_position):
		return true
	if _segment_hits_goal(_last_left_foot_position, player.left_foot.global_position):
		return true
	if _segment_hits_goal(_last_right_foot_position, player.right_foot.global_position):
		return true
	if player.head_contact != null and _segment_hits_goal(_last_head_position, player.head_contact.global_position):
		return true

	return false

func _segment_hits_goal(from_world: Vector2, to_world: Vector2) -> bool:
	if from_world == Vector2.INF or to_world == Vector2.INF:
		return false

	var from_local := to_local(from_world)
	var to_local_position := to_local(to_world)
	var min_x := -half_width - sweep_extra_width
	var max_x := half_width + sweep_extra_width
	var min_y := -half_height - sweep_extra_height
	var max_y := half_height + sweep_extra_height

	if _point_inside_rect(from_local, min_x, max_x, min_y, max_y):
		return true
	if _point_inside_rect(to_local_position, min_x, max_x, min_y, max_y):
		return true

	var steps := 5
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var p := from_local.lerp(to_local_position, t)
		if _point_inside_rect(p, min_x, max_x, min_y, max_y):
			return true
	return false

func _point_inside_rect(local_position: Vector2, min_x: float, max_x: float, min_y: float, max_y: float) -> bool:
	return local_position.x >= min_x and local_position.x <= max_x and local_position.y >= min_y and local_position.y <= max_y

func _store_player_positions() -> void:
	if player == null or player.body == null:
		return
	_last_body_position = player.body.global_position
	_last_left_foot_position = player.left_foot.global_position
	_last_right_foot_position = player.right_foot.global_position
	_last_head_position = player.head_contact.global_position if player.head_contact != null else Vector2.INF

func _update_goal_feedback() -> void:
	var progress := 0.0
	if tuning != null and tuning.goal_hold_time > 0.0:
		progress = clampf(_hold_timer / tuning.goal_hold_time, 0.0, 1.0)
	var active := _inside_grace_timer > 0.0 or current_state == State.COMPLETE
	var pulse := _activation_pulse
	var active_amount := 1.0 if active else 0.0

	if progress_fill != null:
		progress_fill.scale.x = maxf(progress, 0.12 if active else 0.0)
		progress_fill.visible = active or progress > 0.01
		if progress_fill is CanvasItem:
			(progress_fill as CanvasItem).modulate = Color(1.0, 0.95, 0.22, 0.7 + progress * 0.3)
	if glow_zone != null:
		glow_zone.modulate = Color(0.65 + pulse * 0.35, 1.0, 0.35 + pulse * 0.2, 0.18 + active_amount * 0.42 + progress * 0.25)
		if glow_zone is Node2D:
			var glow_node := glow_zone as Node2D
			var glow_scale := 1.0 + pulse * 0.12 + progress * 0.04
			glow_node.scale = Vector2(glow_scale, glow_scale)
	if landing_pad != null:
		landing_pad.modulate = Color(1.0, 0.82 + active_amount * 0.16, 0.1 + active_amount * 0.18, 0.9 + active_amount * 0.1)
	if flag_gold != null:
		flag_gold.modulate = Color(1.0, 0.82 + pulse * 0.16, 0.1 + pulse * 0.18, 1.0)
		if flag_gold is Node2D:
			(flag_gold as Node2D).position.y = -pulse * 5.0
	if flag_dark != null:
		flag_dark.modulate = Color(0.08 + pulse * 0.1, 0.08 + pulse * 0.1, 0.14 + pulse * 0.12, 1.0)
		if flag_dark is Node2D:
			(flag_dark as Node2D).position.y = -pulse * 5.0

func _resolve_player() -> PlayerController2D:
	var node := get_node_or_null(player_path) if not player_path.is_empty() else null
	if node is PlayerController2D:
		return node

	node = get_parent().get_node_or_null("Flaibai") if get_parent() != null else null
	if node is PlayerController2D:
		return node

	return get_tree().get_first_node_in_group("player") as PlayerController2D

func _resolve_game_manager() -> GameManager:
	var node := get_node_or_null(game_manager_path) if not game_manager_path.is_empty() else null
	if node is GameManager:
		return node

	node = get_parent().get_node_or_null("GameManager") if get_parent() != null else null
	return node as GameManager
