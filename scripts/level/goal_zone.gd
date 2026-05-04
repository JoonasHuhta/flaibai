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
@export var half_width: float = 95.0
@export var half_height: float = 150.0
@export var contact_grace_time: float = 0.18
@export var clean_hold_time: float = 0.08
@export var sloppy_hold_time: float = 0.04
@export var crash_hold_time: float = 0.04
@export var finish_delay: float = 0.18
@export var instant_finish_max_speed: float = 1180.0
@export var sloppy_max_speed: float = 760.0
@export var sloppy_max_vertical_speed: float = 560.0
@export var progress_path: NodePath = ^"ProgressFill"
@export var glow_path: NodePath = ^"GlowZone"

var current_state: State = State.WAITING

var player: PlayerController2D
var game_manager: GameManager
var progress_fill: Node2D
var glow_zone: CanvasItem

var _hold_timer := 0.0
var _player_inside := false
var _inside_grace_timer := 0.0
var _completion_started := false

func _ready() -> void:
	player = _resolve_player()
	game_manager = _resolve_game_manager()

	if tuning == null:
		tuning = PlayerTuning.new()
	progress_fill = get_node_or_null(progress_path) as Node2D
	glow_zone = get_node_or_null(glow_path) as CanvasItem
	_update_goal_feedback()

	if player == null:
		push_error("GoalZone could not find Flaibai/PlayerController2D.")
	if game_manager == null:
		push_error("GoalZone could not find GameManager.")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if current_state == State.COMPLETE or _completion_started:
		_update_goal_feedback()
		return

	if player == null or game_manager == null:
		current_state = State.WAITING
		_update_goal_feedback()
		return

	var currently_inside := _is_player_inside_goal()
	if currently_inside:
		_inside_grace_timer = contact_grace_time
	else:
		_inside_grace_timer = maxf(_inside_grace_timer - delta, 0.0)

	if _inside_grace_timer <= 0.0:
		_hold_timer = maxf(_hold_timer - delta * 2.0, 0.0)
		current_state = State.WAITING
		_update_goal_feedback()
		return

	if not player.is_waiting_for_tap():
		var angle := absf(rad_to_deg(wrapf(player.body.rotation, -PI, PI)))
		var speed := player.body.linear_velocity.length()
		var vertical_speed := absf(player.body.linear_velocity.y)
		var upright := angle <= tuning.goal_upright_limit_degrees + 8.0
		var settled := vertical_speed <= tuning.goal_max_vertical_speed + 80.0
		var slow_enough := player.body.linear_velocity.length() <= 520.0
		var sloppy_finish := player.is_grounded_any() and speed <= sloppy_max_speed and vertical_speed <= sloppy_max_vertical_speed
		var crashed_in_goal := player.has_crashed() and speed <= sloppy_max_speed

		if currently_inside and speed <= instant_finish_max_speed:
			_hold_timer = maxf(_hold_timer, sloppy_hold_time)
			current_state = State.ARMED
			_complete_goal(not player.has_crashed())
		elif upright and settled and slow_enough and not player.has_crashed():
			_hold_timer += delta
			current_state = State.ARMED
			if _hold_timer >= minf(tuning.goal_hold_time, clean_hold_time):
				_complete_goal()
		elif crashed_in_goal:
			_hold_timer += delta
			current_state = State.ARMED
			if _hold_timer >= crash_hold_time:
				_complete_goal(false)
		elif sloppy_finish:
			_hold_timer += delta
			current_state = State.ARMED
			if _hold_timer >= sloppy_hold_time:
				_complete_goal()
		else:
			_hold_timer = maxf(_hold_timer - delta * 1.5, 0.0)
			current_state = State.WAITING
	else:
		_hold_timer = maxf(_hold_timer - delta * 2.0, 0.0)
		current_state = State.WAITING
	_update_goal_feedback()

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

func _update_goal_feedback() -> void:
	var progress := 0.0
	if tuning != null and tuning.goal_hold_time > 0.0:
		progress = clampf(_hold_timer / tuning.goal_hold_time, 0.0, 1.0)

	if progress_fill != null:
		progress_fill.scale.x = progress
		progress_fill.visible = progress > 0.01
	if glow_zone != null:
		glow_zone.modulate = Color(1.0, 1.0, 1.0, 0.55 + progress * 0.45)

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
