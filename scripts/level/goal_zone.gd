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

var current_state: State = State.WAITING

var player: PlayerController2D
var game_manager: GameManager

var _hold_timer := 0.0
var _player_inside := false

func _ready() -> void:
	player = _resolve_player()
	game_manager = _resolve_game_manager()

	if tuning == null:
		tuning = PlayerTuning.new()

	if player == null:
		push_error("GoalZone could not find Flaibai/PlayerController2D.")
	if game_manager == null:
		push_error("GoalZone could not find GameManager.")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if current_state == State.COMPLETE:
		return

	if player == null or game_manager == null or not _player_inside:
		_hold_timer = 0.0
		current_state = State.WAITING
		return

	if player.is_clean_landing(tuning.goal_upright_limit_degrees, tuning.goal_max_vertical_speed):
		_hold_timer += delta
		current_state = State.ARMED

		if _hold_timer >= tuning.goal_hold_time:
			current_state = State.COMPLETE
			game_manager.complete_level()
	else:
		_hold_timer = 0.0
		current_state = State.WAITING

func _on_body_entered(body: Node2D) -> void:
	if player == null:
		return

	if body == player.body:
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if player == null:
		return

	if body == player.body:
		_player_inside = false
		_hold_timer = 0.0

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
