extends Resource
class_name PlayerTuning

@export_category("Launch")
## Fixed impulse for tap-to-launch (x = forward, y = upward negative)
@export var auto_launch_impulse: Vector2 = Vector2(520.0, -860.0)

@export_category("Air Control")
@export var air_torque: float = 19500.0
@export var balance_torque: float = 6800.0
@export var max_angular_velocity: float = 20.5
@export var input_balance_relief: float = 0.03

@export_category("Bounce")
@export var bounce_impulse: Vector2 = Vector2(260.0, -260.0)
@export var tilt_bounce_impulse: float = 650.0
@export var bounce_takeoff_speed: float = 980.0
@export var max_bounce_takeoff_speed: float = 1280.0
@export var upright_limit_degrees: float = 58.0
@export var min_bounce_impact_speed: float = 85.0
@export var bounce_cooldown: float = 0.12
@export var spring_visual_compression_time: float = 0.16
@export var crash_min_impact_speed: float = 80.0

@export_category("Goal Landing")
@export var goal_upright_limit_degrees: float = 34.0
@export var goal_max_vertical_speed: float = 220.0
@export var goal_hold_time: float = 0.45
