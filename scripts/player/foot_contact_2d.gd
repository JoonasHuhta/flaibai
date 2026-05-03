extends Area2D
class_name FootContact2D

@export var player_path: NodePath = ^".."

var is_grounded: bool = false

var _player: PlayerController2D
var _ground_contacts: Dictionary = {}

func _ready() -> void:
	monitoring = true
	monitorable = true
	_player = get_node_or_null(player_path) as PlayerController2D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	var current_ground_contacts := {}
	for body in get_overlapping_bodies():
		if not _is_ground(body):
			continue
		current_ground_contacts[body] = true
		if not _ground_contacts.has(body):
			_register_ground_contact(body)

	for body in _ground_contacts.keys():
		if not current_ground_contacts.has(body):
			_ground_contacts.erase(body)

	is_grounded = not _ground_contacts.is_empty()
	if is_grounded and _player != null:
		_player.try_foot_bounce(_player.get_landing_speed(), _get_primary_ground())

func _on_body_entered(body: Node) -> void:
	if not _is_ground(body):
		return

	_register_ground_contact(body)

func _register_ground_contact(body: Node) -> void:
	_ground_contacts[body] = true
	is_grounded = true

	if _player != null:
		var impact_speed := _player.get_landing_speed()
		_player.try_foot_bounce(impact_speed, body)

func _on_body_exited(body: Node) -> void:
	if not _ground_contacts.has(body):
		return

	_ground_contacts.erase(body)
	is_grounded = not _ground_contacts.is_empty()

func reset_contact_state() -> void:
	_ground_contacts.clear()
	is_grounded = false

func _is_ground(body: Node) -> bool:
	return body != null and body.is_in_group("ground")

func _get_primary_ground() -> Node:
	for body in _ground_contacts.keys():
		return body

	return null
