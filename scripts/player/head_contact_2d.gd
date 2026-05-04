extends Area2D
class_name HeadContact2D

@export var player_path: NodePath = ^".."

var _player: PlayerController2D
var _active_contacts: Dictionary = {}

func _ready() -> void:
	monitoring = true
	monitorable = true
	_player = get_node_or_null(player_path) as PlayerController2D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if _is_ground(body):
			_register_contact(body)

func reset_contact_state() -> void:
	_active_contacts.clear()

func _on_body_entered(body: Node) -> void:
	if not _is_ground(body):
		return

	_register_contact(body)

func _on_body_exited(body: Node) -> void:
	if _active_contacts.has(body):
		_active_contacts.erase(body)

func _register_contact(body: Node) -> void:
	_active_contacts[body] = true
	if _player != null:
		_player.try_head_crash(body)

func _is_ground(body: Node) -> bool:
	return body != null and body.is_in_group("ground")
