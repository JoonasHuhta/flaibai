extends RigidBody2D

@export var max_launch_power: float = 8000.0
@export var min_drag: float = 10.0

var dragging: bool = false
var drag_start: Vector2
var drag_current: Vector2

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = get_global_mouse_position()
				drag_current = drag_start
			else:
				if dragging:
					var drag = drag_start - drag_current
					if drag.length() > min_drag:
						linear_velocity = Vector2.ZERO
						angular_velocity = 0.0
						apply_central_impulse(drag.normalized() * min(drag.length() * 10.0, max_launch_power))
					dragging = false
		queue_redraw()

	if event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()

func _physics_process(delta):
	var angle = rotation
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	apply_torque(-angle * 300.0)
	angular_velocity = clamp(angular_velocity, -10.0, 10.0)

func _draw():
	if not dragging:
		return
	var drag = drag_start - drag_current
	var power = clamp(drag.length() / 300.0, 0.0, 1.0)
	var color = Color(1.0, 1.0 - power, 0.0)
	draw_line(Vector2.ZERO, to_local(drag_start + drag), color, 3.0)
	draw_circle(to_local(drag_start + drag), 8.0, color)
