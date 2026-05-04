extends Node2D
## StartScreen — title screen shown when game launches.

signal start_requested

@export var level_to_load: String = "res://scenes/levels/level_01.tscn"

var _tap_enabled := false
var _title_tween: Tween = null

func _ready() -> void:
	# Start music on title screen
	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").play_music("title_theme.ogg")
	# Small delay before accepting taps (avoids accidental skip)
	await get_tree().create_timer(0.6).timeout
	_tap_enabled = true
	_start_tap_pulse()
	# Animate title in
	var title := get_node_or_null("TitleLabel")
	if title:
		title.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(title, "modulate:a", 1.0, 0.7)

func _input(event: InputEvent) -> void:
	if not _tap_enabled:
		return
	if event is InputEventScreenTouch and event.pressed:
		_on_tap()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_on_tap()

func _on_tap() -> void:
	if not _tap_enabled:
		return
	_tap_enabled = false
	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").play_sfx("ui_tap")
		Engine.get_singleton("AudioManager").stop_music()
	# Flash + scale effect before loading
	var tap_label := get_node_or_null("TapLabel")
	if tap_label:
		var tw := create_tween()
		tw.tween_property(tap_label, "modulate:a", 0.0, 0.2)
	var tw2 := create_tween()
	var title := get_node_or_null("TitleLabel")
	if title:
		tw2.tween_property(title, "scale", Vector2(1.08, 1.08), 0.12)
		tw2.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	await get_tree().create_timer(0.25).timeout
	# Reset level progress to start from level 1
	if Engine.has_singleton("ProjectState"):
		Engine.get_singleton("ProjectState").reset()
	get_tree().change_scene_to_file(level_to_load)

func _start_tap_pulse() -> void:
	var tap_label := get_node_or_null("TapLabel")
	if tap_label == null:
		return
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(tap_label, "modulate:a", 0.25, 0.7)
	_title_tween.tween_property(tap_label, "modulate:a", 1.0, 0.7)
