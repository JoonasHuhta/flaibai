extends Control
class_name ScoreboardUI

signal retry_requested
signal next_requested

var _title_label: Label
var _subtitle_label: Label
var _rows: VBoxContainer
var _retry_button: Button
var _next_button: Button
var _title_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func show_results(level_name: String, result: Dictionary, formatter: Callable) -> void:
	if _title_label == null:
		_build()

	var qualified: bool = bool(result.get("qualified", false))
	var new_record: bool = bool(result.get("new_record", false))
	var rank: int = int(result.get("rank", -1))
	var previous_best: float = float(result.get("previous_best", -1.0))
	var run_time: float = float(result.get("time", -1.0))
	var entries: Array = result.get("entries", [])

	if new_record:
		_title_label.text = "NEW RECORD!"
	elif qualified:
		_title_label.text = "TOP 10! RANK #%d" % rank
	else:
		_title_label.text = "FINISHED"

	var previous_text: String = "Previous %s" % str(formatter.call(previous_best)) if previous_best >= 0.0 else "First recorded time"
	_subtitle_label.text = "%s\nYour time %s\n%s" % [
		level_name,
		formatter.call(run_time),
		previous_text,
	]

	for child in _rows.get_children():
		child.queue_free()

	for i in 10:
		var row := Label.new()
		row.custom_minimum_size = Vector2(310.0, 24.0)
		row.add_theme_font_size_override("font_size", 18)
		if i < entries.size():
			var entry: Dictionary = entries[i]
			var time_value: float = float(entry.get("time", -1.0))
			row.text = "%2d. %s" % [i + 1, formatter.call(time_value)]
			if qualified and i == rank - 1:
				row.add_theme_color_override("font_color", Color(1.0, 0.86, 0.16, 1.0))
			else:
				row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		else:
			row.text = "%2d. --:--.---" % (i + 1)
			row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.35))
		_rows.add_child(row)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bounce_title()

func hide_results() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _title_label != null:
		return

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 28.0
	panel.offset_top = 170.0
	panel.offset_right = 362.0
	panel.offset_bottom = 760.0
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.16, 1.0))
	_title_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_subtitle_label.add_theme_font_size_override("font_size", 17)
	box.add_child(_subtitle_label)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	box.add_child(_rows)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_retry_button = Button.new()
	_retry_button.text = "RETRY"
	_retry_button.custom_minimum_size = Vector2(150.0, 44.0)
	_retry_button.pressed.connect(func(): retry_requested.emit())
	buttons.add_child(_retry_button)

	_next_button = Button.new()
	_next_button.text = "NEXT LEVEL"
	_next_button.custom_minimum_size = Vector2(170.0, 44.0)
	_next_button.pressed.connect(func(): next_requested.emit())
	buttons.add_child(_next_button)

func _bounce_title() -> void:
	if _title_tween != null:
		_title_tween.kill()
	_title_label.scale = Vector2(0.92, 0.92)
	_title_label.pivot_offset = Vector2(160.0, 18.0)
	_title_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_tween.tween_property(_title_label, "scale", Vector2(1.08, 1.08), 0.18)
	_title_tween.tween_property(_title_label, "scale", Vector2.ONE, 0.18)
