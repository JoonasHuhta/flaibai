extends Node2D
class_name PlayerController2D

signal crashed
signal bounced(angle_degrees: float, flip_count: int)
signal surface_touched(surface_type: String)
signal request_camera_shake(intensity: float, duration: float)

@export_category("Refs")
@export var body_path: NodePath = ^"Body"
@export var left_foot_path: NodePath = ^"LeftFoot"
@export var right_foot_path: NodePath = ^"RightFoot"
@export var left_contact_path: NodePath = ^"LeftFoot"
@export var right_contact_path: NodePath = ^"RightFoot"
@export var aim_line_path: NodePath = ^"AimLine"
@export var tuning: PlayerTuning
@export var left_foot_offset: Vector2 = Vector2(-17.0, 70.0)
@export var right_foot_offset: Vector2 = Vector2(17.0, 70.0)

@onready var body: RigidBody2D = get_node(body_path)
@onready var left_foot: Node2D = get_node(left_foot_path)
@onready var right_foot: Node2D = get_node(right_foot_path)
@onready var left_contact: FootContact2D = get_node(left_contact_path)
@onready var right_contact: FootContact2D = get_node(right_contact_path)
@onready var aim_line: Line2D = get_node(aim_line_path)

var _aiming := false
var _aim_touch_index := -1
var _drag_start_world := Vector2.ZERO
var _drag_current_world := Vector2.ZERO
var _air_touch_active := false
var _air_touch_index := -1
var _air_touch_x := 0.0
var _bounce_cooldown_remaining := 0.0
var _spring_visual_timer := 0.0
var _spring_visual_peak := 0.0
var _controls_enabled := true
var _crashed := false
var _last_body_rotation := 0.0
var _air_rotation_total := 0.0
var _flow_boost_01 := 0.0
var _body_crash_grace_remaining := 0.0
var _last_spawn_position := Vector2.ZERO
var _crash_tumble_timer := 0.0
var _crash_shown_retry := false

func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	global_position = Vector2.ZERO
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_body_entered)
	aim_line.top_level = true
	aim_line.visible = false
	_last_spawn_position = body.global_position
	_last_body_rotation = body.rotation

func _input(event: InputEvent) -> void:
	if not _controls_enabled:
		return

	_handle_pointer_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return

	_handle_pointer_input(event)

func _physics_process(_delta: float) -> void:
	_bounce_cooldown_remaining = maxf(_bounce_cooldown_remaining - _delta, 0.0)
	_spring_visual_timer = maxf(_spring_visual_timer - _delta, 0.0)
	_body_crash_grace_remaining = maxf(_body_crash_grace_remaining - _delta, 0.0)
	_sync_feet_to_body()
	_track_air_rotation()
	if not _crashed:
		_handle_air_control()
	else:
		_handle_crash_tumble(_delta)

func is_grounded_any() -> bool:
	return left_contact.is_grounded or right_contact.is_grounded or _is_body_near_ground()

func is_grounded_fully() -> bool:
	return left_contact.is_grounded and right_contact.is_grounded

func has_crashed() -> bool:
	return _crashed

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_stop_aiming()
		_air_touch_active = false
		_air_touch_index = -1

func set_flow_boost(value: float) -> void:
	_flow_boost_01 = clampf(value, 0.0, 1.0)

func begin_launch_from_screen(screen_position: Vector2, touch_index: int = -1) -> bool:
	if not _controls_enabled:
		return false
	if not is_grounded_any() and not _is_near_start_area():
		return false

	_aim_touch_index = touch_index
	_start_aiming(_screen_to_world(screen_position))
	return true

func update_launch_from_screen(screen_position: Vector2, touch_index: int = -1) -> bool:
	if not _controls_enabled:
		return false
	if not _aiming:
		_set_air_input_from_screen(screen_position, touch_index)
		return true
	if _aim_touch_index != -1 and touch_index != -1 and touch_index != _aim_touch_index:
		return false

	_drag_current_world = _screen_to_world(screen_position)
	_update_aim_line()
	return true

func end_launch_from_screen(screen_position: Vector2, touch_index: int = -1) -> bool:
	if not _controls_enabled:
		return false
	if _aiming:
		if _aim_touch_index != -1 and touch_index != -1 and touch_index != _aim_touch_index:
			return false
		_aim_touch_index = -1
		_release_launch(_screen_to_world(screen_position))
		return true

	_air_touch_active = false
	_air_touch_index = -1
	return true

func set_air_input_from_screen(screen_position: Vector2, touch_index: int = -1, active: bool = true) -> void:
	if active:
		_set_air_input_from_screen(screen_position, touch_index)
	else:
		_air_touch_active = false
		_air_touch_index = -1

func get_landing_speed() -> float:
	return maxf(body.linear_velocity.y, 0.0)

func get_spring_compression_01() -> float:
	if _spring_visual_timer <= 0.0:
		return 0.0

	return _spring_visual_peak * (_spring_visual_timer / tuning.spring_visual_compression_time)

func get_visual_charge_01() -> float:
	if not _aiming:
		return 0.0

	var drag := _drag_start_world - _drag_current_world
	return clampf(drag.length() / tuning.visual_charge_distance, 0.0, 1.0)

func is_clean_landing(max_angle_degrees: float, max_vertical_speed: float) -> bool:
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	var upright := angle <= max_angle_degrees
	var stable_y := absf(body.linear_velocity.y) <= max_vertical_speed
	return is_grounded_fully() and upright and stable_y

func try_foot_bounce(impact_speed: float, ground_body: Node = null) -> void:
	if _crashed:
		return

	if _bounce_cooldown_remaining > 0.0:
		return

	if impact_speed < tuning.min_bounce_impact_speed:
		return

	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	var surface := _get_surface_type(ground_body)
	var surface_rotation := _get_surface_rotation(ground_body)
	var surface_slope := clampf(_normalize_angle(surface_rotation) / deg_to_rad(35.0), -1.0, 1.0)
	if surface == "moss":
		surface_touched.emit(surface)
		_absorb_landing(impact_speed)
		return

	if angle > tuning.upright_limit_degrees:
		_bad_landing_bounce(impact_speed, angle, surface, surface_slope)
		return

	var flip_count := int(floor(absf(_air_rotation_total) / TAU))

	var tilt := clampf(_normalize_angle(body.rotation) / deg_to_rad(tuning.upright_limit_degrees), -1.0, 1.0)
	var flow_power := 1.0 + _flow_boost_01 * 0.28
	var clean_quality := 1.0 - clampf(angle / tuning.upright_limit_degrees, 0.0, 1.0)
	var sketchiness := 1.0 - clean_quality
	var vertical_multiplier := 1.0
	var horizontal_multiplier := 1.0
	var extra_tilt := 0.0

	if surface == "mushroom":
		vertical_multiplier = 1.85
		horizontal_multiplier = 1.18
		extra_tilt = 120.0
	elif surface == "ice":
		vertical_multiplier = 0.72
		horizontal_multiplier = 1.55
		extra_tilt = 260.0
		sketchiness = minf(sketchiness + 0.18, 1.0)

	var landing_quality_power := lerpf(0.76, 1.08, clean_quality)
	var takeoff_speed := clampf((tuning.bounce_takeoff_speed + impact_speed * 0.25) * flow_power * vertical_multiplier * landing_quality_power, tuning.bounce_takeoff_speed * 0.45, tuning.max_bounce_takeoff_speed * flow_power * vertical_multiplier)
	body.linear_velocity.y = -takeoff_speed
	body.linear_velocity.x += tuning.bounce_impulse.x * flow_power * horizontal_multiplier + tilt * (tuning.tilt_bounce_impulse + extra_tilt) + surface_slope * 140.0 + signf(tilt) * sketchiness * 120.0

	var bounce := Vector2((tilt * tuning.tilt_bounce_impulse * 0.25 + surface_slope * 45.0) * horizontal_multiplier, tuning.bounce_impulse.y * flow_power * vertical_multiplier * landing_quality_power)
	body.apply_central_impulse(bounce)
	_spring_visual_peak = clampf(impact_speed / 700.0, 0.35, 1.0) * (1.25 if surface == "mushroom" else 1.0)
	_spring_visual_timer = tuning.spring_visual_compression_time * (1.35 if surface == "mushroom" else 1.0)
	_bounce_cooldown_remaining = tuning.bounce_cooldown
	_body_crash_grace_remaining = 0.12
	Input.vibrate_handheld(25)
	request_camera_shake.emit(1.5, 0.12)
	_air_rotation_total = 0.0
	bounced.emit(angle, flip_count)
	if surface != "normal":
		surface_touched.emit(surface)

func _bad_landing_bounce(impact_speed: float, angle_degrees: float, surface: String, surface_slope: float) -> void:
	var tilt_sign := signf(_normalize_angle(body.rotation))
	if tilt_sign == 0.0:
		tilt_sign = 1.0

	var severity := clampf((angle_degrees - tuning.upright_limit_degrees) / 45.0, 0.0, 1.0)
	var vertical_multiplier := 0.38
	var horizontal_multiplier := 0.85
	if surface == "mushroom":
		vertical_multiplier = 0.9
		horizontal_multiplier = 1.15
	elif surface == "ice":
		vertical_multiplier = 0.22
		horizontal_multiplier = 1.65

	var takeoff_speed := clampf((tuning.bounce_takeoff_speed + impact_speed * 0.15) * vertical_multiplier, 240.0, tuning.max_bounce_takeoff_speed * 0.95)
	body.linear_velocity.y = -takeoff_speed
	body.linear_velocity.x += tuning.bounce_impulse.x * horizontal_multiplier + surface_slope * 120.0 + tilt_sign * lerpf(180.0, 360.0, severity)
	body.angular_velocity += tilt_sign * lerpf(2.5, 6.0, severity)
	body.apply_central_impulse(Vector2(surface_slope * 45.0 + tilt_sign * 70.0, tuning.bounce_impulse.y * vertical_multiplier))

	_spring_visual_peak = clampf(impact_speed / 850.0, 0.25, 0.75)
	_spring_visual_timer = tuning.spring_visual_compression_time
	_bounce_cooldown_remaining = tuning.bounce_cooldown * 1.25
	_body_crash_grace_remaining = 0.06 if severity > 0.55 else 0.12
	Input.vibrate_handheld(20)
	request_camera_shake.emit(1.0, 0.1)
	_air_rotation_total = 0.0
	bounced.emit(angle_degrees, 0)
	if surface != "normal":
		surface_touched.emit(surface)

func _absorb_landing(impact_speed: float) -> void:
	body.linear_velocity.y = minf(body.linear_velocity.y * 0.18, 80.0)
	body.linear_velocity.x *= 0.55
	body.angular_velocity *= 0.6
	_spring_visual_peak = clampf(impact_speed / 900.0, 0.2, 0.55)
	_spring_visual_timer = tuning.spring_visual_compression_time * 1.4
	_bounce_cooldown_remaining = tuning.bounce_cooldown * 2.4
	_body_crash_grace_remaining = 0.1

func _get_surface_type(ground_body: Node) -> String:
	if ground_body == null:
		return "normal"
	if ground_body.is_in_group("mushroom"):
		return "mushroom"
	if ground_body.is_in_group("moss"):
		return "moss"
	if ground_body.is_in_group("ice"):
		return "ice"

	return "normal"

func _get_surface_rotation(ground_body: Node) -> float:
	if ground_body is Node2D:
		return (ground_body as Node2D).global_rotation

	return 0.0

func reset_to_spawn(spawn_position: Vector2, spawn_rotation: float = 0.0) -> void:
	rotation = 0.0
	global_position = Vector2.ZERO
	_crashed = false
	_crash_tumble_timer = 0.0
	_crash_shown_retry = false
	set_controls_enabled(true)

	body.global_position = spawn_position
	_last_spawn_position = spawn_position
	body.rotation = spawn_rotation
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.freeze = false
	body.gravity_scale = 3.0
	_last_body_rotation = body.rotation
	_air_rotation_total = 0.0

	_sync_feet_to_body()

	left_contact.reset_contact_state()
	right_contact.reset_contact_state()
	_stop_aiming()

func fail() -> void:
	if _crashed:
		return

	_crashed = true
	set_controls_enabled(false)
	# Funny tumble — don't freeze instantly, let the body ragdoll briefly
	body.linear_velocity *= 0.4
	body.angular_velocity = signf(body.angular_velocity) * maxf(absf(body.angular_velocity), 6.0)
	body.gravity_scale = 2.0
	_crash_tumble_timer = 0.45
	_crash_shown_retry = false
	Input.vibrate_handheld(80)
	request_camera_shake.emit(4.0, 0.25)
	crashed.emit()

func _handle_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and is_grounded_any():
			_start_aiming(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif not event.pressed and _aiming:
			_release_launch(get_global_mouse_position())
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _aiming:
		_drag_current_world = get_global_mouse_position()
		_update_aim_line()
		get_viewport().set_input_as_handled()

	if event is InputEventScreenTouch:
		if event.pressed and is_grounded_any():
			_aim_touch_index = event.index
			_start_aiming(_screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		elif not event.pressed and _aiming and event.index == _aim_touch_index:
			_aim_touch_index = -1
			_release_launch(_screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		elif not is_grounded_any():
			_air_touch_active = event.pressed
			_air_touch_index = event.index if event.pressed else -1
			if event.pressed:
				_air_touch_x = event.position.x

	if event is InputEventScreenDrag and _aiming and event.index == _aim_touch_index:
		_drag_current_world = _screen_to_world(event.position)
		_update_aim_line()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_air_touch_active = true
		_air_touch_index = event.index
		_air_touch_x = event.position.x

func _start_aiming(world_position: Vector2) -> void:
	_aiming = true
	_drag_start_world = world_position
	_drag_current_world = world_position
	_update_aim_line()

func _release_launch(world_position: Vector2) -> void:
	_drag_current_world = world_position
	var drag := _drag_start_world - _drag_current_world
	_stop_aiming()

	if drag.length() < tuning.min_launch_drag:
		return

	var power := minf(drag.length() * tuning.launch_multiplier, tuning.max_launch_power)
	var launch_scale := tuning.grounded_launch_scale if is_grounded_fully() else tuning.partial_launch_scale

	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.apply_central_impulse(drag.normalized() * power * launch_scale)
	_air_rotation_total = 0.0

func _stop_aiming() -> void:
	_aiming = false
	_aim_touch_index = -1
	aim_line.visible = false

func _update_aim_line() -> void:
	var drag := _drag_start_world - _drag_current_world
	aim_line.visible = true
	aim_line.clear_points()
	aim_line.add_point(body.global_position)
	aim_line.add_point(body.global_position + drag)

func _handle_air_control() -> void:
	var angle := _normalize_angle(body.rotation)
	var input_torque := 0.0
	var horizontal := 0.0

	if not is_grounded_any():
		horizontal = _get_air_input()
		input_torque = horizontal * tuning.air_torque

	var balance_scale := tuning.input_balance_relief if absf(horizontal) > 0.0 else 1.0
	var auto_balance := -angle * tuning.balance_torque * balance_scale

	body.apply_torque(auto_balance + input_torque)
	body.angular_velocity = clampf(body.angular_velocity, -tuning.max_angular_velocity, tuning.max_angular_velocity)

func _sync_feet_to_body() -> void:
	left_foot.global_position = body.global_position + left_foot_offset.rotated(body.rotation)
	right_foot.global_position = body.global_position + right_foot_offset.rotated(body.rotation)
	left_foot.global_rotation = body.rotation
	right_foot.global_rotation = body.rotation

func _track_air_rotation() -> void:
	var rotation_delta := _normalize_angle(body.rotation - _last_body_rotation)
	if not is_grounded_any() and not _crashed:
		_air_rotation_total += rotation_delta
	_last_body_rotation = body.rotation

func _get_air_input() -> float:
	var horizontal := 0.0

	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		horizontal -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		horizontal += 1.0

	if horizontal != 0.0:
		return horizontal

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return _screen_x_to_direction(get_viewport().get_mouse_position().x)

	if _air_touch_active:
		return _screen_x_to_direction(_air_touch_x)

	return 0.0

func _screen_x_to_direction(x: float) -> float:
	# Dead zone in center 15% of screen — prevents accidental tilting
	var screen_width := get_viewport_rect().size.x
	var ratio := x / screen_width
	if ratio < 0.425:
		return -1.0
	elif ratio > 0.575:
		return 1.0
	return 0.0

func _handle_crash_tumble(delta: float) -> void:
	_crash_tumble_timer = maxf(_crash_tumble_timer - delta, 0.0)
	if _crash_tumble_timer <= 0.0 and not _crash_shown_retry:
		_crash_shown_retry = true
		body.freeze = true
		body.gravity_scale = 3.0

func _on_body_entered(other_body: Node) -> void:
	if _crashed:
		return
	if other_body == null or not other_body.is_in_group("ground"):
		return
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	# Only crash if CLEARLY head-first — feet-first contact is always a bounce
	if angle <= tuning.upright_limit_degrees * 1.1:
		return
	if _body_crash_grace_remaining > 0.0:
		return
	if get_landing_speed() < tuning.crash_min_impact_speed:
		return

	fail()

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _set_air_input_from_screen(screen_position: Vector2, touch_index: int = -1) -> void:
	if is_grounded_any():
		return

	_air_touch_active = true
	_air_touch_index = touch_index
	_air_touch_x = screen_position.x

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _is_body_near_ground() -> bool:
	if body == null:
		return false

	if absf(body.linear_velocity.y) > 80.0:
		return false

	return body.global_position.distance_to(_last_spawn_position) < 110.0

func _is_near_start_area() -> bool:
	if body == null:
		return false

	return body.global_position.distance_to(_last_spawn_position) < 180.0
