extends Node
class_name LevelVisualTheme

const SKY_COLOR := Color(0.37, 0.62, 0.84, 1.0)
const HILL_BACK := Color(0.27, 0.52, 0.50, 0.24)
const HILL_FRONT := Color(0.20, 0.43, 0.38, 0.20)
const GROUND := Color(0.22, 0.74, 0.58, 1.0)
const NORMAL := Color(0.36, 0.78, 0.40, 1.0)
const MOSS := Color(0.22, 0.60, 0.34, 1.0)
const ICE := Color(0.62, 0.90, 1.00, 1.0)
const MUSHROOM := Color(1.00, 0.34, 0.37, 1.0)
const FINISH := Color(1.00, 0.82, 0.10, 1.0)
const OUTLINE := Color(0.05, 0.07, 0.12, 0.90)

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var root := get_parent() as Node2D
	if root == null:
		return

	_style_background(root)
	_style_hud(root)
	_style_surfaces(root)
	_style_goal(root)

func _style_background(root: Node2D) -> void:
	var max_x := 3200.0
	var camera := root.get_node_or_null("Camera2D") as CameraFollow2D
	if camera != null:
		max_x = camera.max_x + 900.0

	var sky := root.get_node_or_null("SkyPanel") as Polygon2D
	if sky != null:
		sky.color = SKY_COLOR

	if root.get_node_or_null("HillsBack") == null:
		var hills_back := Polygon2D.new()
		hills_back.name = "HillsBack"
		hills_back.z_index = -27
		hills_back.color = HILL_BACK
		hills_back.polygon = PackedVector2Array([
			Vector2(-700, 690), Vector2(250, 520), Vector2(780, 650), Vector2(1360, 500),
			Vector2(2200, 650), Vector2(3100, 500), Vector2(max_x, 670), Vector2(max_x, 900), Vector2(-700, 900),
		])
		root.add_child(hills_back)

	if root.get_node_or_null("HillsFront") == null:
		var hills_front := Polygon2D.new()
		hills_front.name = "HillsFront"
		hills_front.z_index = -26
		hills_front.color = HILL_FRONT
		hills_front.polygon = PackedVector2Array([
			Vector2(-700, 735), Vector2(420, 610), Vector2(1050, 725), Vector2(1740, 595),
			Vector2(2450, 735), Vector2(3400, 610), Vector2(max_x, 735), Vector2(max_x, 900), Vector2(-700, 900),
		])
		root.add_child(hills_front)

func _style_hud(root: Node2D) -> void:
	var retry_layer := root.get_node_or_null("RetryLayer")
	if retry_layer == null:
		return

	_style_label(retry_layer.get_node_or_null("ScoreLabel") as Label, 17, Color(1, 1, 1, 0.95), 3)
	_style_label(retry_layer.get_node_or_null("LandingFeedback") as Label, 24, Color(1, 0.94, 0.38, 1), 4)
	_style_label(retry_layer.get_node_or_null("ControlsHint") as Label, 17, Color(1, 1, 1, 0.92), 3)
	_style_label(retry_layer.get_node_or_null("TapToRetry") as Label, 26, Color(1, 1, 1, 0.96), 4)

	var level_label := retry_layer.get_node_or_null("LevelLabel") as Label
	_style_label(level_label, 13, Color(1.0, 0.88, 0.26, 0.78), 2)
	if level_label != null:
		level_label.offset_top = 22.0

	var flow := retry_layer.get_node_or_null("FlowLabel") as Label
	if flow != null:
		flow.visible = false

func _style_label(label: Label, font_size: int, font_color: Color, outline_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.12, 0.65))
	label.add_theme_constant_override("outline_size", outline_size)

func _style_surfaces(root: Node2D) -> void:
	for node in root.get_children():
		if not (node is StaticBody2D):
			continue
		var body := node as StaticBody2D
		if not body.is_in_group("ground"):
			continue
		var visual := body.get_node_or_null("Visual") as Polygon2D
		if visual == null:
			continue

		visual.color = _surface_color(body)
		_ensure_surface_outline(body, visual)
		_ensure_surface_highlight(body, visual)

func _surface_color(body: StaticBody2D) -> Color:
	if body.name == "FinalPlatform":
		return FINISH
	if body.is_in_group("mushroom"):
		return MUSHROOM
	if body.is_in_group("moss"):
		return MOSS
	if body.is_in_group("ice"):
		return ICE
	if body.name == "Ground":
		return GROUND
	return NORMAL

func _ensure_surface_outline(body: StaticBody2D, visual: Polygon2D) -> void:
	if body.get_node_or_null("VisualOutline") != null:
		return
	var outline := Line2D.new()
	outline.name = "VisualOutline"
	outline.z_index = visual.z_index - 1
	outline.width = 5.0
	outline.closed = true
	outline.default_color = OUTLINE
	for point in visual.polygon:
		outline.add_point(point)
	body.add_child(outline)

func _ensure_surface_highlight(body: StaticBody2D, visual: Polygon2D) -> void:
	if body.get_node_or_null("SurfaceHighlight") != null:
		return
	var highlight := Polygon2D.new()
	highlight.name = "SurfaceHighlight"
	highlight.z_index = visual.z_index + 1
	highlight.color = Color(1.0, 1.0, 1.0, 0.18 if not body.is_in_group("ice") else 0.34)
	highlight.polygon = _top_strip_polygon(visual.polygon)
	if highlight.polygon.size() >= 3:
		body.add_child(highlight)

func _top_strip_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return PackedVector2Array()
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
	return PackedVector2Array([
		Vector2(min_x + 8.0, min_y + 3.0),
		Vector2(max_x - 8.0, min_y + 3.0),
		Vector2(max_x - 18.0, min_y + 9.0),
		Vector2(min_x + 18.0, min_y + 9.0),
	])

func _style_goal(root: Node2D) -> void:
	var goal := root.get_node_or_null("GoalZone") as Node2D
	if goal == null:
		return

	var landing_pad := goal.get_node_or_null("LandingPad") as Polygon2D
	if landing_pad != null:
		landing_pad.color = Color(1.0, 0.82, 0.08, 0.96)
	var pad_stripe := goal.get_node_or_null("PadStripe") as Polygon2D
	if pad_stripe != null:
		pad_stripe.color = Color(0.04, 0.05, 0.10, 0.78)
	var glow := goal.get_node_or_null("GlowZone") as Polygon2D
	if glow != null:
		glow.color = Color(0.25, 1.0, 0.45, 0.16)
	var progress := goal.get_node_or_null("ProgressFill") as Polygon2D
	if progress != null:
		progress.color = Color(1.0, 0.94, 0.20, 0.85)
