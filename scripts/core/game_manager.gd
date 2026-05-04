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
@export var scoreboard_path: NodePath = ^"../RetryLayer/ScoreboardUI"
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
var scoreboard: Node
var camera: CameraFollow2D

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
var _scene_transition_started := false

func _ready() -> void:
	call_deferred("_initialize")
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_music("game_theme.ogg")

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
	scoreboard = get_node_or_null(scoreboard_path)
	camera = get_parent().get_node_or_null("Camera2D") as CameraFollow2D if get_parent() != null else null

	if player == null:
		push_error("GameManager could not find Flaibai/PlayerController2D.")
		set_process(false)
		return

	_sync_project_state_to_current_scene()
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
	if scoreboard != null:
		scoreboard.call("hide_results")
		scoreboard.connect("retry_requested", Callable(self, "respawn"))
		scoreboard.connect("next_requested", Callable(self, "_load_next_level"))

	_spawn_position = spawn_point.global_position if spawn_point != null else player.body.global_position
	_update_score_label()
	_update_flow_label()
	_initialized = true

func _input(event: InputEvent) -> void:
	if not (failed or level_completed):
		return
	if level_completed:
		if _is_next_key_event(event):
			_load_next_level()
			get_viewport().set_input_as_handled()
	else:
		if _is_tap_event(event):
			respawn()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not (failed or level_completed):
		return
	if level_completed:
		if _is_next_key_event(event):
			_load_next_level()
			get_viewport().set_input_as_handled()
	else:
		if _is_tap_event(event):
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

	_scene_transition_started = false
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
	if scoreboard != null:
		scoreboard.call("hide_results")
	if controls_hint != null:
		controls_hint.visible = true
	_controls_hint_timer = 3.0
	_feedback_timer = 0.0
	_update_score_label()
	_update_flow_label()
	player.reset_to_spawn(_spawn_position)
	player.set_flow_boost(0.0)
	if camera != null:
		camera.reset_focus()

func complete_level() -> void:
	if level_completed:
		return

	failed = false
	level_completed = true
	var result := _record_level_result()
	var new_best: bool = bool(result.get("new_record", false))
	if new_best:
		best_time = run_time
	best_clean_streak = maxi(best_clean_streak, clean_streak)
	best_score = max(best_score, run_score + 500)
	run_score += 500
	flow = 100.0
	_update_score_label()
	_update_flow_label()

	if result_label != null:
		result_label.visible = false
	if scoreboard != null:
		scoreboard.call("show_results", _get_current_level_name(), result, Callable(self, "_format_time"))
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_sfx("level_complete")
		am.stop_music()
	if feedback_label != null:
		feedback_label.text = "Great run!"
		feedback_label.visible = true
		_feedback_timer = 1.5
	if retry_label != null:
		retry_label.visible = false
	if retry_catcher != null:
		retry_catcher.visible = false
	print("LEVEL COMPLETE - time: ", _format_time(run_time), " clean: ", clean_streak)

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
		var am = get_tree().root.get_node_or_null("AudioManager")
		if am != null:
			am.play_sfx("clean_streak", 1.0 + (clean_streak - 1) * 0.04)
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
	if camera != null:
		camera.focus_crash()
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

func _is_tap_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and event.keycode == KEY_R
	return false

func _is_next_key_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]
	return false

func _load_next_level() -> void:
	if _scene_transition_started:
		return
	_scene_transition_started = true

	var state = get_tree().root.get_node_or_null("ProjectState")
	if state != null:
		state.advance_level()
		var next_scene: String = str(state.get_current_scene())
		var error := get_tree().change_scene_to_file(next_scene)
		if error != OK:
			push_error("Could not load next Flaibai level: %s error=%d" % [next_scene, error])
			_scene_transition_started = false
	else:
		# Fallback: reload current scene
		var error := get_tree().reload_current_scene()
		if error != OK:
			push_error("Could not reload Flaibai scene. error=%d" % error)
			_scene_transition_started = false

func _sync_project_state_to_current_scene() -> void:
	var state = get_tree().root.get_node_or_null("ProjectState")
	if state == null or get_parent() == null:
		return

	var current_scene_path := str(get_parent().scene_file_path)
	if current_scene_path.is_empty():
		return

	for i in state.level_scenes.size():
		if str(state.level_scenes[i]) == current_scene_path:
			state.start_level(i)
			return

func _on_retry_catcher_gui_input(event: InputEvent) -> void:
	if not _is_tap_event(event):
		return
	if level_completed:
		_load_next_level()
	else:
		respawn()
	get_viewport().set_input_as_handled()

func _format_time(seconds: float) -> String:
	var clamped_seconds := maxf(seconds, 0.0)
	var total_milliseconds := int(round(clamped_seconds * 1000.0))
	var minutes := total_milliseconds / 60000
	var remaining := total_milliseconds % 60000
	var whole_seconds := remaining / 1000
	var milliseconds := remaining % 1000
	return "%d:%02d.%03d" % [minutes, whole_seconds, milliseconds]

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
	var state = get_tree().root.get_node_or_null("ProjectState")
	if state != null:
		best_time = state.get_best_time(state.current_level_index)
		best_clean_streak = state.get_best_clean_streak(state.current_level_index)

func _record_level_result() -> Dictionary:
	var state = get_tree().root.get_node_or_null("ProjectState")
	if state == null:
		var new_best := best_time < 0.0 or run_time < best_time
		if new_best:
			best_time = run_time
		return {
			"qualified": true,
			"new_record": new_best,
			"rank": 1 if new_best else -1,
			"previous_best": -1.0,
			"time": run_time,
			"entries": [{"time": run_time, "date": ""}],
		}

	return state.record_level_time(state.current_level_index, run_time, clean_streak)

func _get_current_level_name() -> String:
	var state = get_tree().root.get_node_or_null("ProjectState")
	if state == null:
		return "Level"
	return str(state.get_level_name(state.current_level_index))

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
