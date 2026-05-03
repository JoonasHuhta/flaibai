extends Control
class_name GameplayTouchLayer

@export var player_path: NodePath
@export var game_manager_path: NodePath
@export var debug_label_path: NodePath

var player: PlayerController2D
var game_manager: GameManager
var debug_label: Label
var _mouse_active := false
var _touch_index := -1
var _event_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	player = get_node_or_null(player_path) as PlayerController2D
	game_manager = get_node_or_null(game_manager_path) as GameManager
	debug_label = get_node_or_null(debug_label_path) as Label
	_set_debug("touch ready player=%s gm=%s" % [player != null, game_manager != null])

func _input(event: InputEvent) -> void:
	_handle_input_event(event)

func _gui_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _handle_input_event(event: InputEvent) -> void:
	if player == null:
		_set_debug("touch no player")
		return
	if game_manager != null and (game_manager.failed or game_manager.level_completed):
		_set_debug("touch blocked failed=%s done=%s" % [game_manager.failed, game_manager.level_completed])
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_active = true
			_count_event("mouse down %s" % player.begin_launch_from_screen(event.position))
		else:
			_mouse_active = false
			_count_event("mouse up %s" % player.end_launch_from_screen(event.position))
		_accept_touch_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_count_event("mouse drag %s" % player.update_launch_from_screen(event.position))
		_accept_touch_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			_count_event("touch down %s" % player.begin_launch_from_screen(event.position, event.index))
		elif event.index == _touch_index:
			_count_event("touch up %s" % player.end_launch_from_screen(event.position, event.index))
			_touch_index = -1
		_accept_touch_event()
	elif event is InputEventScreenDrag:
		_touch_index = event.index
		_count_event("touch drag %s" % player.update_launch_from_screen(event.position, event.index))
		_accept_touch_event()

func _accept_touch_event() -> void:
	accept_event()
	get_viewport().set_input_as_handled()

func _count_event(message: String) -> void:
	_event_count += 1
	var grounded := player.is_grounded_any() if player != null else false
	_set_debug("%03d %s grounded=%s" % [_event_count, message, grounded])

func _set_debug(message: String) -> void:
	if debug_label != null:
		debug_label.text = message
