extends Node2D
## StartScreen — title screen shown when game launches.

signal start_requested

@export var level_to_load: String = "res://scenes/levels/level_01.tscn"

var _tap_enabled := false
var _title_tween: Tween = null

func _ready() -> void:
	# Start music on title screen
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_music("title_theme.ogg")
	# Small delay before accepting taps (avoids accidental skip)
	await get_tree().create_timer(0.6).timeout
	_tap_enabled = true
	_start_tap_pulse()
	# Animate title in
	_animate_title_in()

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	# Drift stars
	for i in range(1, 7):
		var star = get_node_or_null("Star" + str(i))
		if star:
			star.position.x -= delta * 12.0 * (1.0 + float(i) * 0.15)
			if star.position.x < -100:
				star.position.x = 480
	
	# Float character
	var flaibai = get_node_or_null("FlaibaiAnchor")
	if flaibai:
		flaibai.position.y = 480.0 + sin(_time * 1.5) * 15.0
		flaibai.rotation = sin(_time * 0.8) * 0.15

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
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_sfx("ui_tap")
		am.stop_music()
	# Flash + scale effect before loading
	var tap_label := get_node_or_null("TapLabel")
	if tap_label:
		var tw := create_tween()
		tw.tween_property(tap_label, "modulate:a", 0.0, 0.2)
	var tw2 := create_tween()
	var title := get_node_or_null("UILayer/TitleAnchor")
	if title:
		title.pivot_offset = title.size / 2.0
		tw2.tween_property(title, "scale", Vector2(1.08, 1.08), 0.12)
		tw2.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	await get_tree().create_timer(0.25).timeout
	# Reset level progress to start from level 1
	var ps = get_tree().root.get_node_or_null("ProjectState")
	if ps != null:
		ps.reset()
	get_tree().change_scene_to_file(level_to_load)

func _start_tap_pulse() -> void:
	var tap_label := get_node_or_null("UILayer/TapLabel")
	if tap_label == null:
		return
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(tap_label, "modulate:a", 0.4, 0.8)
	_title_tween.parallel().tween_property(tap_label, "scale", Vector2(0.96, 0.96), 0.8)
	_title_tween.tween_property(tap_label, "modulate:a", 1.0, 0.8)
	_title_tween.parallel().tween_property(tap_label, "scale", Vector2(1.04, 1.04), 0.8)
