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
@export var head_contact_path: NodePath = ^"HeadContact"
@export var tuning: PlayerTuning
@export var left_foot_offset: Vector2 = Vector2(-15.5, 64.0)
@export var right_foot_offset: Vector2 = Vector2(15.5, 64.0)
@export var head_contact_offset: Vector2 = Vector2(0.0, -38.5)

@onready var body: RigidBody2D = get_node(body_path)
@onready var left_foot: Node2D = get_node(left_foot_path)
@onready var right_foot: Node2D = get_node(right_foot_path)
@onready var left_contact: FootContact2D = get_node(left_contact_path)
@onready var right_contact: FootContact2D = get_node(right_contact_path)
@onready var head_contact: HeadContact2D = get_node_or_null(head_contact_path) as HeadContact2D

# --- State ---
## True before first tap, and after moss landing. Player must tap to launch.
var _waiting_for_tap := true
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
## Side-lying detection: crash if grounded and tilted >72deg for too long
var _grounded_tilt_timer := 0.0
const _SIDE_TILT_LIMIT := 72.0
const _SIDE_TILT_DURATION := 0.38

func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	global_position = Vector2.ZERO
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_body_entered)
	_last_spawn_position = body.global_position
	_last_body_rotation = body.rotation

func _input(event: InputEvent) -> void:
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
		_check_side_lying(_delta)
	else:
		_handle_crash_tumble(_delta)

# --- Public API ---

func is_grounded_any() -> bool:
	return left_contact.is_grounded or right_contact.is_grounded or _is_body_near_ground()

func is_grounded_fully() -> bool:
	return left_contact.is_grounded and right_contact.is_grounded

func has_crashed() -> bool:
	return _crashed

func is_waiting_for_tap() -> bool:
	return _waiting_for_tap and not _crashed

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_air_touch_active = false
		_air_touch_index = -1

func set_flow_boost(value: float) -> void:
	_flow_boost_01 = clampf(value, 0.0, 1.0)

func get_landing_speed() -> float:
	return maxf(body.linear_velocity.y, 0.0)

func get_spring_compression_01() -> float:
	if _spring_visual_timer <= 0.0:
		return 0.0
	return _spring_visual_peak * (_spring_visual_timer / tuning.spring_visual_compression_time)

func is_clean_landing(max_angle_degrees: float, max_vertical_speed: float) -> bool:
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	var upright := angle <= max_angle_degrees
	var stable_y := absf(body.linear_velocity.y) <= max_vertical_speed
	return is_grounded_fully() and upright and stable_y

func try_foot_bounce(impact_speed: float, ground_body: Node = null) -> void:
	if _crashed or _waiting_for_tap:
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
	var takeoff_speed := clampf(
		(tuning.bounce_takeoff_speed + impact_speed * 0.25) * flow_power * vertical_multiplier * landing_quality_power,
		tuning.bounce_takeoff_speed * 0.45,
		tuning.max_bounce_takeoff_speed * flow_power * vertical_multiplier
	)
	body.linear_velocity.y = -takeoff_speed
	body.linear_velocity.x += tuning.bounce_impulse.x * flow_power * horizontal_multiplier \
		+ tilt * (tuning.tilt_bounce_impulse + extra_tilt) \
		+ surface_slope * 140.0 \
		+ signf(tilt) * sketchiness * 120.0

	var bounce := Vector2(
		(tilt * tuning.tilt_bounce_impulse * 0.25 + surface_slope * 45.0) * horizontal_multiplier,
		tuning.bounce_impulse.y * flow_power * vertical_multiplier * landing_quality_power
	)
	body.apply_central_impulse(bounce)
	_spring_visual_peak = clampf(impact_speed / 700.0, 0.35, 1.0) * (1.25 if surface == "mushroom" else 1.0)
	_spring_visual_timer = tuning.spring_visual_compression_time * (1.35 if surface == "mushroom" else 1.0)
	_bounce_cooldown_remaining = tuning.bounce_cooldown
	_body_crash_grace_remaining = 0.12
	Input.vibrate_handheld(25)
	request_camera_shake.emit(1.5, 0.12)
	_play_sfx("bounce" if surface == "normal" else "bounce_" + surface)
	_air_rotation_total = 0.0
	bounced.emit(angle, flip_count)
	if surface != "normal":
		surface_touched.emit(surface)

func try_head_crash(ground_body: Node) -> void:
	if _crashed or _waiting_for_tap:
		return
	if ground_body == null or not ground_body.is_in_group("ground"):
		return

	var speed := body.linear_velocity.length()
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	if speed < 70.0 and angle < 45.0 and is_grounded_any():
		return

	fail()

func reset_to_spawn(spawn_position: Vector2, spawn_rotation: float = 0.0) -> void:
	rotation = 0.0
	global_position = Vector2.ZERO
	_crashed = false
	_waiting_for_tap = true
	_crash_tumble_timer = 0.0
	_crash_shown_retry = false
	_grounded_tilt_timer = 0.0
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
	if head_contact != null:
		head_contact.reset_contact_state()

func fail() -> void:
	if _crashed:
		return
	_crashed = true
	set_controls_enabled(false)
	# Funny ragdoll tumble before freeze
	body.linear_velocity *= 0.4
	body.angular_velocity = signf(body.angular_velocity) * maxf(absf(body.angular_velocity), 6.0)
	body.gravity_scale = 2.0
	_crash_tumble_timer = 0.45
	_crash_shown_retry = false
	Input.vibrate_handheld(80)
	request_camera_shake.emit(4.0, 0.25)
	_play_sfx("crash")
	crashed.emit()

func celebrate() -> void:
	## Joyful jump when level is completed — Flaibai hops and spins!
	set_controls_enabled(false)
	_waiting_for_tap = false
	body.linear_velocity = Vector2(body.linear_velocity.x * 0.3, 0.0)
	body.angular_velocity = 0.0
	# Three quick happy hops via timed impulses
	body.apply_central_impulse(Vector2(0.0, -680.0))
	get_tree().create_timer(0.55).timeout.connect(func():
		if body != null and not body.freeze:
			body.apply_central_impulse(Vector2(0.0, -520.0))
			body.angular_velocity = 8.0
	)
	Input.vibrate_handheld(40)

# --- Input handling ---

func _handle_pointer_input(event: InputEvent) -> void:
	# Keyboard (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mx := get_viewport().get_mouse_position().x
			if _waiting_for_tap or (is_grounded_any() and body.linear_velocity.length() < 60.0):
				_auto_launch()
			else:
				_air_touch_active = true
				_air_touch_x = mx
		else:
			_air_touch_active = false

	if event is InputEventMouseMotion and not is_grounded_any() and not _waiting_for_tap:
		_air_touch_x = get_viewport().get_mouse_position().x

	# Touch
	if event is InputEventScreenTouch:
		if event.pressed:
			if _waiting_for_tap or (is_grounded_any() and body.linear_velocity.length() < 60.0):
				_auto_launch()
				get_viewport().set_input_as_handled()
			else:
				_air_touch_active = true
				_air_touch_index = event.index
				_air_touch_x = event.position.x
		else:
			if event.index == _air_touch_index:
				_air_touch_active = false
				_air_touch_index = -1

	if event is InputEventScreenDrag:
		if not _waiting_for_tap and not is_grounded_any():
			_air_touch_active = true
			_air_touch_index = event.index
			_air_touch_x = event.position.x

# --- Launch ---

func _auto_launch() -> void:
	if _crashed:
		return
	_waiting_for_tap = false
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.apply_central_impulse(tuning.auto_launch_impulse)
	_air_rotation_total = 0.0
	_bounce_cooldown_remaining = tuning.bounce_cooldown
	_play_sfx("launch")

# --- Air control ---

func _handle_air_control() -> void:
	var angle := _normalize_angle(body.rotation)
	var horizontal := 0.0
	var input_torque := 0.0

	if not is_grounded_any() and not _waiting_for_tap:
		horizontal = _get_air_input()
		input_torque = horizontal * tuning.air_torque

	var balance_scale := tuning.input_balance_relief if absf(horizontal) > 0.0 else 1.0
	var auto_balance := -angle * tuning.balance_torque * balance_scale

	body.apply_torque(auto_balance + input_torque)
	body.angular_velocity = clampf(body.angular_velocity, -tuning.max_angular_velocity, tuning.max_angular_velocity)

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
	# Dead zone in center 15% — no accidental tilts
	var ratio := x / get_viewport_rect().size.x
	if ratio < 0.425:
		return -1.0
	elif ratio > 0.575:
		return 1.0
	return 0.0

# --- Bounce helpers ---

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

	var takeoff_speed := clampf(
		(tuning.bounce_takeoff_speed + impact_speed * 0.15) * vertical_multiplier,
		240.0, tuning.max_bounce_takeoff_speed * 0.95
	)
	body.linear_velocity.y = -takeoff_speed
	body.linear_velocity.x += tuning.bounce_impulse.x * horizontal_multiplier \
		+ surface_slope * 120.0 + tilt_sign * lerpf(180.0, 360.0, severity)
	body.angular_velocity += tilt_sign * lerpf(2.5, 6.0, severity)
	body.apply_central_impulse(Vector2(
		surface_slope * 45.0 + tilt_sign * 70.0,
		tuning.bounce_impulse.y * vertical_multiplier
	))
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
	# Moss: full stop, wait for tap
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	_spring_visual_peak = clampf(impact_speed / 900.0, 0.2, 0.55)
	_spring_visual_timer = tuning.spring_visual_compression_time * 1.4
	_bounce_cooldown_remaining = tuning.bounce_cooldown * 2.4
	_body_crash_grace_remaining = 0.1
	_play_sfx("moss_stop")
	_waiting_for_tap = true

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

# --- Side-lying crash detection ---

func _check_side_lying(delta: float) -> void:
	## If grounded and tilted sideways for too long, it's a crash.
	## Grace period after bounce suppresses this so a 'just saved' tilt still works.
	if _body_crash_grace_remaining > 0.0 or _waiting_for_tap:
		_grounded_tilt_timer = 0.0
		return
	if not is_grounded_any():
		# Decay timer faster when airborne so a partial tilt resets
		_grounded_tilt_timer = maxf(_grounded_tilt_timer - delta * 2.5, 0.0)
		return
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	if angle > _SIDE_TILT_LIMIT:
		_grounded_tilt_timer += delta
		if _grounded_tilt_timer >= _SIDE_TILT_DURATION:
			fail()
	else:
		# Recover: timer decays at 2x rate so small tilts fade quickly
		_grounded_tilt_timer = maxf(_grounded_tilt_timer - delta * 2.0, 0.0)

# --- Crash tumble ---

func _handle_crash_tumble(delta: float) -> void:
	_crash_tumble_timer = maxf(_crash_tumble_timer - delta, 0.0)
	if _crash_tumble_timer <= 0.0 and not _crash_shown_retry:
		_crash_shown_retry = true
		body.freeze = true
		body.gravity_scale = 3.0

# --- Body entered (crash detection) ---

func _on_body_entered(other_body: Node) -> void:
	if _crashed:
		return
	if other_body == null or not other_body.is_in_group("ground"):
		return
	var angle := absf(rad_to_deg(_normalize_angle(body.rotation)))
	# Only crash when clearly head-first
	if angle <= tuning.upright_limit_degrees * 1.1:
		return
	if _body_crash_grace_remaining > 0.0:
		return
	if get_landing_speed() < tuning.crash_min_impact_speed:
		return
	fail()

# --- Feet sync ---

func _sync_feet_to_body() -> void:
	left_foot.global_position = body.global_position + left_foot_offset.rotated(body.rotation)
	right_foot.global_position = body.global_position + right_foot_offset.rotated(body.rotation)
	left_foot.global_rotation = body.rotation
	right_foot.global_rotation = body.rotation
	if head_contact != null:
		head_contact.global_position = body.global_position + head_contact_offset.rotated(body.rotation)
		head_contact.global_rotation = body.rotation

# --- Air rotation tracking ---

func _track_air_rotation() -> void:
	var rotation_delta := _normalize_angle(body.rotation - _last_body_rotation)
	if not is_grounded_any() and not _crashed:
		_air_rotation_total += rotation_delta
	_last_body_rotation = body.rotation

# --- Utilities ---

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

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

func _play_sfx(name: String, pitch: float = 1.0) -> void:
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am != null:
		am.play_sfx(name, pitch)

func _is_near_start_area() -> bool:
	if body == null:
		return false
	return body.global_position.distance_to(_last_spawn_position) < 180.0
