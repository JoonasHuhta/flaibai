extends Control
class_name OffscreenIndicator

@export var target_path: NodePath
@export var top_margin: float = 54.0
@export var side_margin: float = 28.0
@export var hidden_below_top: float = 8.0

@onready var target: Node2D = get_node_or_null(target_path)

var _screen_position := Vector2.ZERO
var _visible_indicator := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if target == null:
		target = get_node_or_null(target_path)
	if target == null:
		_visible_indicator = false
		queue_redraw()
		return

	var canvas_position := get_viewport().get_canvas_transform() * target.global_position
	var viewport_size := get_viewport_rect().size
	_visible_indicator = canvas_position.y < -hidden_below_top
	_screen_position = Vector2(
		clampf(canvas_position.x, side_margin, viewport_size.x - side_margin),
		top_margin
	)
	queue_redraw()

func _draw() -> void:
	if not _visible_indicator:
		return

	var p := _screen_position
	var fill := Color(1.0, 0.86, 0.16, 0.95)
	var outline := Color(0.06, 0.07, 0.12, 0.95)
	var triangle := PackedVector2Array([
		p + Vector2(0.0, 18.0),
		p + Vector2(-15.0, -8.0),
		p + Vector2(15.0, -8.0),
	])
	draw_colored_polygon(triangle, fill)
	draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), outline, 3.0)
	draw_circle(p + Vector2(0.0, -17.0), 5.5, fill)
	draw_arc(p + Vector2(0.0, -17.0), 7.5, 0.0, TAU, 24, outline, 2.5)
