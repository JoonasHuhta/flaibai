extends Node
class_name GameManager

@export var player_path: NodePath
@export var spawn_point_path: NodePath
@export var retry_label_path: NodePath
@export var feedback_label_path: NodePath
@export var score_label_path: NodePath
@export var flow_label_path: NodePath
@export var controls_hint_path: NodePath
@export var result_label_path: NodePath
@export var retry_catcher_path: NodePath
@export var fail_y: float = 980.0

var player: PlayerController2D
var spawn_point: Node2D
var retry_label: CanvasItem
var feedback_label: Label
var score_label: Label
var flow_label: Label
var controls_hint: CanvasItem
var result_label: Label
var retry_catcher: Control

var level_completed := false
var failed := false
var run_score := 0
var best_score := 0
var flow := 0.0
var run_time := 0.0
var best_time := -1.0
var clean_streak := 0
var best_clean_streak := 0
var bounce_count := 0
var _spawn_position := Vector2.ZERO
var _feedback_timer := 0.0
var _controls_hint_timer := 4.5
var _landing_bonus_score := 0
var _initialized := false
const SAVE_PATH := "user://flaibai_records.cfg"

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	player = _resolve_player()
	spawn_point = _resolve_spawn_point()
	retry_label = get_node_or_null(retry_label_path) as CanvasItem
	feedback_label = get_node_or_null(feedback_label_path) as Label
	score_label = get_node_or_null(score_label_path) as Label
	flow_label = get_node_or_null(flow_label_path) as Label
	controls_hint = get_node_or_null(controls_hint_path) as CanvasItem
	result_label = get_node_or_null(result_label_path) as Label
	retry_catcher = get_node_or_null(retry_catcher_path) as Control

	if player == null:
		push_error("GameManager could not find Flaibai/PlayerController2D.")
		set_process(false)
		return

	_load_records()
	player.crashed.connect(_on_player_crashed)
	player.bounced.connect(_on_player_bounced)
	player.surface_touched.connect(_on_player_surface_touched)
	if retry_label != null:
		retry_label.visible = false
		if retry_label is Label:
			(retry_label as Label).text = "Tap to try again"
	if feedback_label != null:
		feedback_label.visible = false
	if controls_hint != null:
		controls_hint.visible = true
	if result_label != null:
		result_label.visible = false
	if retry_catcher != null:
		retry_catcher.visible = false
		retry_catcher.gui_input.connect(_on_retry_catcher_gui_input)

	_spawn_position = spawn_point.global_position if spawn_point != null else player.body.global_position
	_update_score_label()
	_update_flow_label()
	_initialized = true

func _input(event: InputEvent) -> void:
	if _is_retry_event(event):
		respawn()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _is_retry_event(event):
		respawn()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _initialized:
		return

	if level_completed:
		return

	if player == null:
		return

	_feedback_timer = maxf(_feedback_timer - _delta, 0.0)
	if feedback_label != null and _feedback_timer <= 0.0:
		feedback_label.visible = false
	_controls_hint_timer = maxf(_controls_hint_timer - _delta, 0.0)
	if controls_hint != null and _controls_hint_timer <= 0.0:
		controls_hint.visible = false

	var distance_score: int = maxi(0, int((player.body.global_position.x - _spawn_position.x) * 0.1))
	run_score = max(run_score, distance_score + _landing_bonus_score)
	if not failed:
		run_time += _delta
	flow = maxf(flow - _delta * 2.5, 0.0)
	_update_score_label()
	_update_flow_label()

	if player.body.global_position.y > fail_y:
		_fail_run()

	if Input.is_key_pressed(KEY_R):
		respawn()

func respawn() -> void:
	if player == null:
		return

	failed = false
	level_completed = false
	run_score = 0
	_landing_bonus_score = 0
	flow = 0.0
	run_time = 0.0
	clean_streak = 0
	bounce_count = 0
	if retry_label != null:
		retry_label.visible = false
	if retry_catcher != null:
		retry_catcher.visible = false
	if feedback_label != null:
		feedback_label.visible = false
	if result_label != null:
		result_label.visible = false
	if controls_hint != null:
		controls_hint.visible = true
	_controls_hint_timer = 3.0
	_feedback_timer = 0.0
	_update_score_label()
	_update_flow_label()
	player.reset_to_spawn(_spawn_position)
	player.set_flow_boost(0.0)

func complete_level() -> void:
	if level_completed:
		return

	level_completed = true
	var previous_best_time := best_time
	var new_best := best_time < 0.0 or run_time < best_time
	if new_best:
		best_time = run_time
	best_clean_streak = maxi(best_clean_streak, clean_streak)
	best_score = max(best_score, run_score + 500)
	run_score += 500
	flow = 100.0
	_save_records()
	_update_score_label()
	_update_flow_label()

	# Build the result card text
	var time_line := "⏱  %s" % _format_time(run_time)
	var best_line := "🏆 New best!" if new_best else ("Best: %s" % _format_time(previous_best_time if previous_best_time >= 0.0 else run_time))
	var clean_line := "✨ Clean landings: %d" % clean_streak
	var score_line := "Score: %d" % run_score

	if result_label != null:
		result_label.text = "KENTTÄ LÄPÄISTY!\n\n%s\n%s\n%s\n%s" % [time_line, best_line, clean_line, score_line]
		result_label.visible = true
	if feedback_label != null:
		feedback_label.text = "🎉 Great run!"
		feedback_label.visible = true
		_feedback_timer = 1.5
	if retry_label != null:
		retry_label.visible = true
		if retry_label is Label:
			(retry_label as Label).text = "▶  Next Level"
	if retry_catcher != null:
		retry_catcher.visible = true
	print("LEVEL COMPLETE — time: ", _format_time(run_time), " clean: ", clean_streak)

func _on_player_crashed() -> void:
	_fail_run()

func _on_player_bounced(angle_degrees: float, flip_count: int) -> void:
	if feedback_label == null or failed:
		return

	var bonus := 0
	var flow_gain := 6.0
	var clean := angle_degrees <= 12.0
	bounce_count += 1
	if clean:
		clean_streak += 1
	else:
		clean_streak = 0
	best_clean_streak = maxi(best_clean_streak, clean_streak)

	if flip_count > 0:
		feedback_label.text = "Full flip x%d" % flip_count
		bonus = 180 * flip_count
		flow_gain = 24.0 * flip_count
	elif clean:
		feedback_label.text = "Clean x%d" % clean_streak
		bonus = 60
		flow_gain = 20.0
	elif angle_degrees <= 32.0:
		feedback_label.text = "Nice save"
		bonus = 25
		flow_gain = 10.0
	else:
		feedback_label.text = "Hold it"

	flow = clampf(flow + flow_gain, 0.0, 100.0)
	player.set_flow_boost(flow / 100.0)
	_landing_bonus_score += bonus
	run_score += bonus
	_update_score_label()
	_update_flow_label()
	feedback_label.visible = true
	_feedback_timer = 0.85

func _on_player_surface_touched(surface_type: String) -> void:
	if feedback_label == null or failed or level_completed:
		return

	if surface_type == "mushroom":
		feedback_label.text = "Super bounce"
	elif surface_type == "moss":
		feedback_label.text = "Soft landing"
	elif surface_type == "ice":
		feedback_label.text = "Slide"
	else:
		return

	feedback_label.visible = true
	_feedback_timer = 0.65

func _fail_run() -> void:
	if failed:
		return

	failed = true
	best_score = max(best_score, run_score)
	flow = 0.0
	_update_score_label()
	_update_flow_label()
	if player != null:
		player.set_controls_enabled(false)
		player.set_flow_boost(0.0)
	# Delay retry UI to let crash tumble animation play out
	get_tree().create_timer(0.5).timeout.connect(_show_retry_ui)

func _show_retry_ui() -> void:
	if not failed:
		return
	if retry_label != null:
		retry_label.visible = true
		if retry_label is Label:
			(retry_label as Label).text = "Tap to try again"
	if retry_catcher != null:
		retry_catcher.visible = true

func _update_score_label() -> void:
	if score_label == null:
		return

	score_label.text = "Time %s\nBest %s\nClean x%d" % [_format_time(run_time), _format_best_time(), clean_streak]

func _update_flow_label() -> void:
	if flow_label == null:
		return

	flow_label.text = "Flow %d%%" % int(round(flow))

func _is_retry_event(event: InputEvent) -> bool:
	if not failed and not level_completed:
		return false

	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and event.keycode == KEY_R

	return false

func _on_retry_catcher_gui_input(event: InputEvent) -> void:
	if _is_retry_event(event):
		respawn()
		get_viewport().set_input_as_handled()

func _format_time(seconds: float) -> String:
	var clamped_seconds := maxf(seconds, 0.0)
	var whole_seconds := int(floor(clamped_seconds))
	var centiseconds := int(floor((clamped_seconds - whole_seconds) * 100.0))
	return "%02d.%02d" % [whole_seconds, centiseconds]

func _format_best_time() -> String:
	if best_time < 0.0:
		return "--.--"

	return _format_time(best_time)

func _format_result_text(new_best: bool, previous_best_time: float) -> String:
	var best_line := "New personal best"
	if not new_best and previous_best_time >= 0.0:
		best_line = "Best %s" % _format_time(previous_best_time)

	return "FLAIBAI\n%s\nTime %s\nClean streak %d\nBounces %d" % [
		best_line,
		_format_time(run_time),
		clean_streak,
		bounce_count,
	]

func _load_records() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return

	var saved_best_time: Variant = config.get_value("level_1", "best_time", -1.0)
	var saved_best_streak: Variant = config.get_value("level_1", "best_clean_streak", 0)
	best_time = float(saved_best_time)
	best_clean_streak = int(saved_best_streak)

func _save_records() -> void:
	var config := ConfigFile.new()
	config.set_value("level_1", "best_time", best_time)
	config.set_value("level_1", "best_clean_streak", best_clean_streak)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save Flaibai records.")

func _resolve_player() -> PlayerController2D:
	var node := get_node_or_null(player_path) if not player_path.is_empty() else null
	if node is PlayerController2D:
		return node

	node = get_parent().get_node_or_null("Flaibai") if get_parent() != null else null
	if node is PlayerController2D:
		return node

	return get_tree().get_first_node_in_group("player") as PlayerController2D

func _resolve_spawn_point() -> Node2D:
	var node := get_node_or_null(spawn_point_path) if not spawn_point_path.is_empty() else null
	if node is Node2D:
		return node

	node = get_parent().get_node_or_null("SpawnPoint") if get_parent() != null else null
	return node as Node2D
