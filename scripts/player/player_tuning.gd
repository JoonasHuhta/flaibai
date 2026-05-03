extends Resource
class_name PlayerTuning

@export_category("Launch")
@export var max_launch_power: float = 1250.0
@export var min_launch_drag: float = 10.0
@export var launch_multiplier: float = 8.0
@export var grounded_launch_scale: float = 1.0
@export var partial_launch_scale: float = 0.65

@export_category("Air Control")
@export var air_torque: float = 9000.0
@export var balance_torque: float = 6500.0
@export var max_angular_velocity: float = 9.0
@export var input_balance_relief: float = 0.35

@export_category("Bounce")
@export var bounce_impulse: Vector2 = Vector2(260.0, -260.0)
@export var tilt_bounce_impulse: float = 520.0
@export var bounce_takeoff_speed: float = 930.0
@export var max_bounce_takeoff_speed: float = 1180.0
@export var upright_limit_degrees: float = 60.0
@export var min_bounce_impact_speed: float = 85.0
@export var bounce_cooldown: float = 0.12
@export var spring_visual_compression_time: float = 0.16
@export var crash_min_impact_speed: float = 90.0

@export_category("Goal Landing")
@export var goal_upright_limit_degrees: float = 30.0
@export var goal_max_vertical_speed: float = 170.0
@export var goal_hold_time: float = 0.6

@export_category("Visuals")
@export var visual_charge_distance: float = 260.0
