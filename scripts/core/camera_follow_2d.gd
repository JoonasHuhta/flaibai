extends Camera2D
class_name CameraFollow2D

@export var target_path: NodePath
@export var follow_speed: float = 6.0
@export var look_ahead: float = 120.0
@export var vertical_follow_speed: float = 3.0
@export var vertical_offset: float = -120.0
@export var min_x: float = 195.0
@export var max_x: float = 2600.0
@export var min_y: float = 240.0
@export var max_y: float = 680.0
@export var crash_zoom: Vector2 = Vector2(0.88, 0.88)
@export var zoom_speed: float = 5.0

@onready var target: Node2D = get_node_or_null(target_path)

var _shake_intensity := 0.0
var _shake_timer := 0.0
var _shake_decay := 8.0
var _base_zoom := Vector2.ONE
var _target_zoom := Vector2.ONE

func _ready() -> void:
	_base_zoom = zoom
	_target_zoom = zoom
	make_current()

func shake(intensity: float, duration: float = 0.2) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)

func focus_crash() -> void:
	_target_zoom = crash_zoom

func reset_focus() -> void:
	_target_zoom = _base_zoom

func _process(delta: float) -> void:
	if target == null:
		return

	var velocity_x := 0.0
	if target is RigidBody2D:
		velocity_x = target.linear_velocity.x

	var dynamic_look_ahead := look_ahead * signf(velocity_x) if absf(velocity_x) > 30.0 else look_ahead
	var target_x := clampf(target.global_position.x + dynamic_look_ahead, min_x, max_x)
	var target_y := clampf(target.global_position.y + vertical_offset, min_y, max_y)

	global_position.x = lerpf(global_position.x, target_x, 1.0 - exp(-follow_speed * delta))
	# Intentionally slower vertical follow — lets Flaibai fly off-screen briefly
	global_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-vertical_follow_speed * delta))
	zoom = zoom.lerp(_target_zoom, 1.0 - exp(-zoom_speed * delta))

	# Camera shake
	_shake_timer = maxf(_shake_timer - delta, 0.0)
	if _shake_timer > 0.0:
		var shake_amount := _shake_intensity * (_shake_timer / maxf(_shake_timer + delta, 0.01))
		offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		_shake_intensity = maxf(_shake_intensity - _shake_decay * delta * _shake_intensity, 0.0)
	else:
		offset = Vector2.ZERO
		_shake_intensity = 0.0
