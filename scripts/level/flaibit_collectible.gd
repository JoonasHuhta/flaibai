extends Area2D
class_name FlaibitCollectible

@export var game_manager_path: NodePath = ^"../GameManager"
@export var spin_speed: float = 2.4
@export var bob_amount: float = 7.0
@export var collect_radius: float = 30.0

var collected := false

var _game_manager: GameManager
var _base_position := Vector2.ZERO
var _time := 0.0
var _visual_root: Node2D

func _ready() -> void:
	add_to_group("flaibit")
	monitoring = true
	monitorable = false
	_game_manager = get_node_or_null(game_manager_path) as GameManager
	_base_position = position
	_ensure_shape()
	_ensure_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if collected:
		return
	_time += delta
	position = _base_position + Vector2(0.0, sin(_time * 3.2) * bob_amount)
	if _visual_root != null:
		_visual_root.rotation += delta * spin_speed
		var pulse := 1.0 + sin(_time * 5.5) * 0.08
		_visual_root.scale = Vector2(pulse, pulse)

func reset_collectible() -> void:
	collected = false
	visible = true
	set_deferred("monitoring", true)
	position = _base_position
	if _visual_root != null:
		_visual_root.scale = Vector2.ONE
		_visual_root.rotation = 0.0

func collect() -> void:
	if collected:
		return
	collected = true
	visible = false
	set_deferred("monitoring", false)
	if _game_manager != null:
		_game_manager.collect_flaibit(self)

func _on_body_entered(body: Node) -> void:
	if _is_player_node(body):
		collect()

func _on_area_entered(area: Area2D) -> void:
	if _is_player_node(area):
		collect()

func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if node is PlayerController2D:
		return true
	var parent := node.get_parent()
	return parent is PlayerController2D

func _ensure_shape() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = collect_radius
	shape_node.shape = circle
	add_child(shape_node)

func _ensure_visuals() -> void:
	if get_node_or_null("VisualRoot") != null:
		_visual_root = get_node("VisualRoot") as Node2D
		return

	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.z_index = -1
	glow.color = Color(1.0, 0.93, 0.30, 0.22)
	glow.polygon = _regular_polygon(34.0, 16)
	_visual_root.add_child(glow)

	var outline := Polygon2D.new()
	outline.name = "Outline"
	outline.color = Color(0.05, 0.06, 0.12, 1.0)
	outline.polygon = _diamond(21.0)
	_visual_root.add_child(outline)

	var core := Polygon2D.new()
	core.name = "Core"
	core.z_index = 1
	core.color = Color(1.0, 0.86, 0.16, 1.0)
	core.polygon = _diamond(16.0)
	_visual_root.add_child(core)

	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.z_index = 2
	shine.color = Color(1.0, 1.0, 0.86, 0.95)
	shine.polygon = PackedVector2Array([
		Vector2(-4, -12), Vector2(4, -12), Vector2(2, -3), Vector2(-6, -2),
	])
	_visual_root.add_child(shine)

func _diamond(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius * 0.82, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius * 0.82, 0.0),
	])

func _regular_polygon(radius: float, points: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in points:
		var angle := TAU * float(i) / float(points)
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon
