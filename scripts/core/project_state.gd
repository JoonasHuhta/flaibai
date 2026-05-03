extends Node

var current_level_index: int = 0

var level_scenes: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/prototyyppi.tscn",
]

func get_current_scene() -> String:
	return level_scenes[current_level_index]

func advance_level() -> void:
	current_level_index = (current_level_index + 1) % level_scenes.size()

func get_next_scene() -> String:
	var next := (current_level_index + 1) % level_scenes.size()
	return level_scenes[next]

func is_last_level() -> bool:
	return current_level_index >= level_scenes.size() - 1

func reset() -> void:
	current_level_index = 0
