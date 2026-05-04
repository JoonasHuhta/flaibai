extends Node2D

@export var level_to_load: String = "res://scenes/levels/level_01.tscn"

var _tap_enabled := false
var _title_tween: Tween = null
var _time := 0.0

func _ready() -> void:
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_music("title_theme.ogg")

	_build_menu()
	_animate_title_in()
	await get_tree().create_timer(0.35).timeout
	_tap_enabled = true
	_start_tap_pulse()

func _process(delta: float) -> void:
	_time += delta
	for i in range(1, 7):
		var star = get_node_or_null("Star" + str(i))
		if star:
			star.position.x -= delta * 12.0 * (1.0 + float(i) * 0.15)
			if star.position.x < -100:
				star.position.x = 480

	var flaibai = get_node_or_null("FlaibaiAnchor")
	if flaibai:
		flaibai.position.y = 500.0 + sin(_time * 1.5) * 15.0
		flaibai.rotation = sin(_time * 0.8) * 0.15

func _unhandled_input(event: InputEvent) -> void:
	if not _tap_enabled:
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_start_level(_get_project_state().current_level_index if _get_project_state() != null else 0)

func _build_menu() -> void:
	var layer := get_node_or_null("UILayer") as CanvasLayer
	if layer == null:
		return

	var old_menu := layer.get_node_or_null("LevelMenu")
	if old_menu != null:
		old_menu.queue_free()

	var menu := VBoxContainer.new()
	menu.name = "LevelMenu"
	menu.offset_left = 28.0
	menu.offset_top = 595.0
	menu.offset_right = 362.0
	menu.offset_bottom = 830.0
	menu.add_theme_constant_override("separation", 8)
	layer.add_child(menu)

	var play_button := Button.new()
	play_button.name = "ContinueButton"
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(334.0, 46.0)
	play_button.pressed.connect(func(): _start_level(_get_resume_level_index()))
	menu.add_child(play_button)

	var state := _get_project_state()
	if state == null:
		return

	for i in state.level_scenes.size():
		var level_index: int = i
		var row := Button.new()
		row.name = "Level%dButton" % (level_index + 1)
		row.custom_minimum_size = Vector2(334.0, 38.0)
		row.disabled = not state.is_level_unlocked(level_index)
		row.text = _format_level_row(state, level_index)
		row.pressed.connect(func(): _start_level(level_index))
		menu.add_child(row)

func _format_level_row(state: Node, index: int) -> String:
	var lock: String = "" if state.is_level_unlocked(index) else "LOCKED  "
	var best_time: float = float(state.get_best_time(index))
	var best: String = str(state.format_time(best_time))
	var level_name: String = str(state.get_level_name(index))
	return "%s%d. %s     Best %s" % [lock, index + 1, level_name, best]

func _get_resume_level_index() -> int:
	var state: Node = _get_project_state()
	if state == null:
		return 0
	var current_index: int = int(state.current_level_index)
	var unlocked_count: int = int(state.unlocked_level_count)
	return clampi(current_index, 0, unlocked_count - 1)

func _start_level(index: int) -> void:
	if not _tap_enabled:
		return

	var state := _get_project_state()
	if state != null:
		if not state.is_level_unlocked(index):
			return
		state.start_level(index)
		level_to_load = state.get_current_scene()

	_tap_enabled = false
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_sfx("ui_tap")
		am.stop_music()

	var tap_label := get_node_or_null("UILayer/TapLabel")
	if tap_label:
		var fade := create_tween()
		fade.tween_property(tap_label, "modulate:a", 0.0, 0.15)

	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(level_to_load)

func _animate_title_in() -> void:
	var anchor = get_node_or_null("UILayer/TitleAnchor")
	if anchor == null:
		return
	for i in anchor.get_child_count():
		var letter = anchor.get_child(i)
		letter.modulate = Color(1, 1, 1, 0)
		letter.position.y -= 50
		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(i * 0.08)
		tw.tween_property(letter, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(letter, "position:y", letter.position.y + 50, 0.45)

func _start_tap_pulse() -> void:
	var tap_label := get_node_or_null("UILayer/TapLabel")
	if tap_label == null:
		return
	tap_label.text = "SELECT LEVEL"
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(tap_label, "modulate:a", 0.45, 0.8)
	_title_tween.parallel().tween_property(tap_label, "scale", Vector2(0.98, 0.98), 0.8)
	_title_tween.tween_property(tap_label, "modulate:a", 1.0, 0.8)
	_title_tween.parallel().tween_property(tap_label, "scale", Vector2(1.02, 1.02), 0.8)

func _get_project_state() -> Node:
	return get_tree().root.get_node_or_null("ProjectState")
