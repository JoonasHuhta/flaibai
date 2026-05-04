extends Node2D
class_name PlayerVisuals2D

@export var player_path: NodePath = ^".."
@export var body_path: NodePath = ^"../Body"
@export var left_foot_path: NodePath = ^"../LeftFoot"
@export var right_foot_path: NodePath = ^"../RightFoot"
@export var head_path: NodePath = ^"Head"
@export var head_outline_path: NodePath = ^"HeadOutline"
@export var body_sprite_path: NodePath = ^"BodySprite"
@export var body_outline_path: NodePath = ^"BodyOutline"
@export var body_belly_path: NodePath = ^"BodyBelly"
@export var left_leg_path: NodePath = ^"LeftLeg"
@export var right_leg_path: NodePath = ^"RightLeg"
@export var left_foot_sprite_path: NodePath = ^"LeftFootSprite"
@export var right_foot_sprite_path: NodePath = ^"RightFootSprite"
@export var left_spring_sprite_path: NodePath = ^"LeftShoeSpring"
@export var right_spring_sprite_path: NodePath = ^"RightShoeSpring"
@export var left_eye_path: NodePath = ^"LeftEye"
@export var right_eye_path: NodePath = ^"RightEye"
@export var mouth_path: NodePath = ^"Mouth"
@export var cap_path: NodePath = ^"Head/Cap"
@export var trail_path: NodePath = ^"MotionTrail"
@export var impact_ring_path: NodePath = ^"ImpactRing"

@export var head_height: float = -48.0
@export var leg_body_offset_y: float = 12.0
@export var leg_body_offset_x: float = 18.0
@export var crouch_amount: float = 18.0
@export var spring_height: float = 34.0
@export var spring_width: float = 18.0
@export var spring_coils: int = 4
@export var shoe_visual_gap: float = 4.0

@onready var player: PlayerController2D = get_node_or_null(player_path)
@onready var body: RigidBody2D = get_node(body_path)
@onready var left_foot: Node2D = get_node(left_foot_path)
@onready var right_foot: Node2D = get_node(right_foot_path)
@onready var head: Node2D = get_node(head_path)
@onready var head_outline: Node2D = get_node_or_null(head_outline_path)
@onready var body_sprite: Node2D = get_node(body_sprite_path)
@onready var body_outline: Node2D = get_node_or_null(body_outline_path)
@onready var body_belly: Node2D = get_node_or_null(body_belly_path)
@onready var left_leg: Node2D = get_node(left_leg_path)
@onready var right_leg: Node2D = get_node(right_leg_path)
@onready var left_foot_sprite: Node2D = get_node(left_foot_sprite_path)
@onready var right_foot_sprite: Node2D = get_node(right_foot_sprite_path)
@onready var left_spring_sprite: Line2D = get_node(left_spring_sprite_path)
@onready var right_spring_sprite: Line2D = get_node(right_spring_sprite_path)
@onready var left_eye: Node2D = get_node_or_null(left_eye_path)
@onready var right_eye: Node2D = get_node_or_null(right_eye_path)
@onready var mouth: Line2D = get_node_or_null(mouth_path)
@onready var cap: Node2D = get_node_or_null(cap_path)
@onready var trail: Line2D = get_node_or_null(trail_path)
@onready var impact_ring: Line2D = get_node_or_null(impact_ring_path)

var _trail_points: Array[Vector2] = []
var _impact_timer := 0.0
var _impact_color := Color(1.0, 0.92, 0.5, 0.55)
var _impact_position := Vector2.ZERO
var _camera: CameraFollow2D = null
var _crash_wobble := 0.0
var _idle_time := 0.0
var _cap_base_position := Vector2.ZERO
var _cap_base_rotation := 0.0
var _spring_shards: Array[Dictionary] = []

func _process(_delta: float) -> void:
	var spring_compression := player.get_spring_compression_01() if player != null else 0.0
	var angular_skew := clampf(body.angular_velocity / 14.0, -0.28, 0.28) if body != null else 0.0
	var left_shoe_position := _get_shoe_position(left_foot, _compressed_spring_height(spring_compression + angular_skew))
	var right_shoe_position := _get_shoe_position(right_foot, _compressed_spring_height(spring_compression - angular_skew))
	left_shoe_position += Vector2(-shoe_visual_gap, 0.0).rotated(body.rotation)
	right_shoe_position += Vector2(shoe_visual_gap, 0.0).rotated(body.rotation)

	global_position = body.global_position
	rotation = body.rotation

	# Idle wobble — hahmo heiluu houkuttelevasti ennen ensimmäistä kosketusta
	var idle_sway := 0.0
	var idle_bob := 0.0
	if player != null and player.is_waiting_for_tap():
		_idle_time += _delta
		idle_sway = sin(_idle_time * 2.2) * 5.0
		idle_bob = sin(_idle_time * 4.0) * 2.5
	else:
		_idle_time = 0.0

	body_sprite.position = Vector2(0.0, idle_bob)
	body_sprite.scale = Vector2.ONE
	body_sprite.rotation = deg_to_rad(idle_sway)
	head.position = Vector2(0.0, head_height + idle_bob * 0.4)
	head.scale = Vector2.ONE
	head.rotation = deg_to_rad(idle_sway * 0.5)
	if body_outline != null:
		body_outline.position = body_sprite.position
		body_outline.scale = body_sprite.scale
		body_outline.rotation = body_sprite.rotation
	if body_belly != null:
		body_belly.position = body_sprite.position + Vector2(0.0, 2.0)
		body_belly.scale = body_sprite.scale
		body_belly.rotation = body_sprite.rotation
	if head_outline != null:
		head_outline.position = head.position
		head_outline.scale = head.scale
		head_outline.rotation = head.rotation

	_update_leg(left_leg, left_shoe_position, Vector2(-leg_body_offset_x, leg_body_offset_y))
	_update_leg(right_leg, right_shoe_position, Vector2(leg_body_offset_x, leg_body_offset_y))
	_update_foot(left_foot_sprite, left_foot, left_shoe_position)
	_update_foot(right_foot_sprite, right_foot, right_shoe_position)
	_update_spring(left_spring_sprite, left_shoe_position, left_foot.global_position)
	_update_spring(right_spring_sprite, right_shoe_position, right_foot.global_position)
	_update_cap(_delta)
	_update_face(idle_sway)
	_update_motion_trail(_delta)
	_update_impact_ring(_delta)
	_update_spring_shards(_delta)

func _ready() -> void:
	top_level = true
	z_index = 20
	if player != null:
		player.bounced.connect(_on_player_bounced)
		player.surface_touched.connect(_on_player_surface_touched)
		player.crashed.connect(_on_player_crashed)
		player.request_camera_shake.connect(_on_camera_shake_requested)
	# Find camera in tree
	_camera = get_tree().get_first_node_in_group(&"camera") as CameraFollow2D
	if _camera == null:
		var cam_node := get_viewport().get_camera_2d()
		if cam_node is CameraFollow2D:
			_camera = cam_node
	if trail != null:
		trail.top_level = true
		trail.global_position = Vector2.ZERO
		trail.clear_points()
	if impact_ring != null:
		impact_ring.top_level = true
		impact_ring.visible = false
	if cap != null:
		_cap_base_position = cap.position
		_cap_base_rotation = cap.rotation

func _update_leg(leg: Node2D, foot_position: Vector2, local_hip: Vector2) -> void:
	var hip := body.global_position + local_hip.rotated(body.rotation)
	var delta := foot_position - hip
	leg.global_position = hip + delta * 0.5
	leg.global_rotation = delta.angle()
	leg.scale.x = maxf(delta.length() / 80.0, 0.05)

func _update_foot(sprite: Node2D, foot: Node2D, shoe_position: Vector2) -> void:
	sprite.global_position = shoe_position
	sprite.global_rotation = foot.global_rotation

func _get_shoe_position(foot: Node2D, height: float) -> Vector2:
	return foot.global_position + Vector2(0.0, -height).rotated(foot.global_rotation)

func _compressed_spring_height(compression: float) -> float:
	var amount := clampf(compression, 0.0, 1.25)
	var height := spring_height * (1.0 - amount * 0.55)
	return maxf(height, spring_height * 0.35)

func _update_spring(spring: Line2D, top_position: Vector2, bottom_position: Vector2) -> void:
	var span := bottom_position - top_position
	var height := span.length()
	if height <= 1.0:
		return

	var along := span / height
	var side := along.orthogonal()
	var point_count := spring_coils * 2 + 3
	var compression_01 := clampf(1.0 - height / maxf(spring_height, 1.0), 0.0, 1.0)
	var coil_width := spring_width * (1.0 + compression_01 * 0.35)

	spring.clear_points()
	for index in point_count:
		var t := float(index) / float(point_count - 1)
		var side_amount := 0.0
		if index > 0 and index < point_count - 1:
			side_amount = coil_width * (0.5 if index % 2 == 0 else -0.5)
		var point := top_position + span * t + side * side_amount
		spring.add_point(spring.to_local(point))

func _update_cap(delta: float) -> void:
	if cap == null or player == null or body == null:
		return
	if not cap.visible:
		return

	var speed := body.linear_velocity.length()
	var flying := not player.is_grounded_any() and not player.is_waiting_for_tap()
	var lift := clampf(speed / 950.0, 0.0, 1.0) if flying else 0.0
	var wobble := sin(Time.get_ticks_msec() * 0.012) * lift
	var target_position := _cap_base_position + Vector2(wobble * 1.6, -lift * 4.5)
	var target_rotation := _cap_base_rotation + body.angular_velocity * 0.018 * lift + wobble * 0.08
	var follow := 1.0 - pow(0.001, delta)
	cap.position = cap.position.lerp(target_position, follow)
	cap.rotation = lerp_angle(cap.rotation, target_rotation, follow)

func _update_face(idle_sway: float) -> void:
	if left_eye == null or right_eye == null or mouth == null or player == null:
		return

	var flying := not player.is_grounded_any()
	var crashed := player.has_crashed()
	var idle := player.is_waiting_for_tap()
	var velocity := body.linear_velocity if body != null else Vector2.ZERO
	var speed := velocity.length()
	var wobble := clampf(absf(body.angular_velocity) / 12.0, 0.0, 1.0)
	var panic := not crashed and not idle and (velocity.y > 520.0 or wobble > 0.72)

	# Eyes track velocity in flight; look at camera during idle
	var look_dir := Vector2.ZERO
	if idle:
		# Curious look toward camera — slight inward + down
		look_dir = Vector2(sin(idle_sway * 0.05) * 1.5, 1.5)
	elif speed > 50.0 and not crashed:
		var local_vel := velocity.rotated(-body.rotation)
		look_dir = local_vel.normalized() * 2.5

	var eye_base_y := -6.0
	var mouth_y := 7.0
	var smile := 0.65 if idle else (1.0 if flying else 0.2)

	if crashed:
		_crash_wobble += 12.0 * get_process_delta_time()
		var dizzy_x := sin(_crash_wobble * 8.0) * 2.0
		look_dir = Vector2(dizzy_x, 2.0)
		eye_base_y = -4.0
		smile = -1.0
	elif panic:
		look_dir.y += 1.0
		eye_base_y = -7.0
		smile = -0.35
	elif flying and not idle:
		smile = 0.65 + wobble * 0.45
		eye_base_y = -6.5

	left_eye.position = head.position + Vector2(-8.0 + look_dir.x, eye_base_y + look_dir.y * 0.5)
	right_eye.position = head.position + Vector2(8.0 + look_dir.x, eye_base_y + look_dir.y * 0.5)

	if crashed:
		left_eye.scale = Vector2(1.3, 0.35)
		right_eye.scale = Vector2(1.3, 0.35)
	elif panic:
		left_eye.scale = Vector2(1.25, 1.45)
		right_eye.scale = left_eye.scale
	elif idle:
		# Gentle blink effect — eyes slightly taller when waiting
		var blink := 1.0 + sin(_idle_time * 0.7) * 0.12
		left_eye.scale = Vector2(1.0, blink)
		right_eye.scale = left_eye.scale
	else:
		var excitement := 1.0 + (0.3 if flying else 0.0) + wobble * 0.15
		left_eye.scale = Vector2(1.0 + wobble * 0.15, excitement)
		right_eye.scale = left_eye.scale

	mouth.position = head.position + Vector2(0.0, mouth_y)
	mouth.clear_points()
	if crashed:
		mouth.add_point(Vector2(-7.0, 2.0))
		mouth.add_point(Vector2(-3.0, -2.0))
		mouth.add_point(Vector2(3.0, 2.0))
		mouth.add_point(Vector2(7.0, -1.0))
	elif panic:
		for index in 13:
			var angle := TAU * float(index) / 12.0
			mouth.add_point(Vector2(cos(angle) * 4.8, sin(angle) * 5.8))
	else:
		mouth.add_point(Vector2(-8.0, 0.0))
		mouth.add_point(Vector2(0.0, 5.5 * smile))
		mouth.add_point(Vector2(8.0, 0.0))

func _update_motion_trail(_delta: float) -> void:
	if trail == null or player == null:
		return

	var speed := body.linear_velocity.length()
	if speed > 240.0 and not player.is_grounded_any() and not player.has_crashed():
		_trail_points.push_front(body.global_position)
	while _trail_points.size() > 7:
		_trail_points.pop_back()
	if speed <= 160.0 or player.is_grounded_any() or player.has_crashed():
		if not _trail_points.is_empty():
			_trail_points.pop_back()

	trail.clear_points()
	trail.global_position = Vector2.ZERO
	for point in _trail_points:
		trail.add_point(point)
	trail.default_color = Color(1.0, 0.92, 0.5, clampf(float(_trail_points.size()) / 12.0, 0.0, 0.45))

func _update_impact_ring(delta: float) -> void:
	if impact_ring == null:
		return

	_impact_timer = maxf(_impact_timer - delta, 0.0)
	if _impact_timer <= 0.0:
		impact_ring.visible = false
		return

	var t := 1.0 - _impact_timer / 0.28
	var radius := lerpf(8.0, 34.0, t)
	impact_ring.visible = true
	impact_ring.global_position = _impact_position
	impact_ring.default_color = Color(_impact_color.r, _impact_color.g, _impact_color.b, (1.0 - t) * _impact_color.a)
	impact_ring.clear_points()
	for index in 17:
		var angle := TAU * float(index) / 16.0
		impact_ring.add_point(Vector2(cos(angle), sin(angle)) * radius)

func _on_player_bounced(_angle_degrees: float, _flip_count: int) -> void:
	_show_impact_ring(Color(1.0, 0.92, 0.5, 0.45))

func _on_player_surface_touched(surface_type: String) -> void:
	if surface_type == "mushroom":
		_show_impact_ring(Color(1.0, 0.35, 0.38, 0.7))
	elif surface_type == "moss":
		_show_impact_ring(Color(0.45, 0.9, 0.42, 0.55))
	elif surface_type == "ice":
		_show_impact_ring(Color(0.62, 0.92, 1.0, 0.6))

func _on_player_crashed() -> void:
	_show_impact_ring(Color(0.08, 0.08, 0.12, 0.45))
	_trail_points.clear()
	_crash_wobble = 0.0
	_spawn_spring_shards()

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	if _camera != null:
		_camera.shake(intensity, duration)

func _show_impact_ring(color: Color) -> void:
	_impact_position = body.global_position + Vector2(0.0, 50.0).rotated(body.rotation)
	_impact_color = color
	_impact_timer = 0.28

func _spawn_spring_shards() -> void:
	for shard in _spring_shards:
		var line := shard.get("line") as Line2D
		if is_instance_valid(line):
			line.queue_free()
	_spring_shards.clear()

	_add_spring_shard(left_spring_sprite.global_position, -1.0)
	_add_spring_shard(right_spring_sprite.global_position, 1.0)

func _add_spring_shard(origin: Vector2, side_sign: float) -> void:
	var line := Line2D.new()
	line.top_level = true
	line.z_index = 24
	line.width = 4.0
	line.default_color = Color(1.0, 0.92, 0.62, 0.95)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for index in spring_coils * 2 + 3:
		var t := float(index) / float(spring_coils * 2 + 2)
		var x := spring_width * 0.45 if index % 2 == 0 else -spring_width * 0.45
		if index == 0 or index == spring_coils * 2 + 2:
			x = 0.0
		line.add_point(Vector2(x, lerpf(-spring_height * 0.45, spring_height * 0.45, t)))
	add_child(line)

	_spring_shards.append({
		"line": line,
		"position": origin,
		"velocity": Vector2(120.0 * side_sign + randf_range(-35.0, 35.0), randf_range(-260.0, -150.0)),
		"rotation": body.rotation + randf_range(-0.4, 0.4),
		"angular_velocity": randf_range(-9.0, 9.0),
		"age": 0.0,
	})

func _update_spring_shards(delta: float) -> void:
	for index in range(_spring_shards.size() - 1, -1, -1):
		var shard := _spring_shards[index]
		var line := shard.get("line") as Line2D
		if not is_instance_valid(line):
			_spring_shards.remove_at(index)
			continue

		var age := float(shard["age"]) + delta
		var velocity := shard["velocity"] as Vector2
		var position := shard["position"] as Vector2
		var rotation_value := float(shard["rotation"])
		var angular_velocity := float(shard["angular_velocity"])
		velocity.y += 760.0 * delta
		position += velocity * delta
		rotation_value += angular_velocity * delta

		var alpha := clampf(1.0 - age / 0.85, 0.0, 1.0)
		line.global_position = position
		line.global_rotation = rotation_value
		line.default_color = Color(1.0, 0.92, 0.62, alpha)

		shard["age"] = age
		shard["velocity"] = velocity
		shard["position"] = position
		shard["rotation"] = rotation_value
		_spring_shards[index] = shard

		if age >= 0.85:
			line.queue_free()
			_spring_shards.remove_at(index)
