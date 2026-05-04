extends Node

const SAVE_PATH := "user://flaibai_records.cfg"

const LEVEL_CATALOG: Array[Dictionary] = [
	{
		"scene": "res://scenes/levels/level_01.tscn",
		"name": "First Steps",
		"concept": "Basic bounce, first mushroom, wide finish",
	},
	{
		"scene": "res://scenes/levels/level_02.tscn",
		"name": "Soft Step",
		"concept": "Safe moss recovery and short controlled hops",
	},
	{
		"scene": "res://scenes/levels/level_03.tscn",
		"name": "Flow Ridge",
		"concept": "Mixed surfaces and rhythm",
	},
	{
		"scene": "res://scenes/levels/level_04.tscn",
		"name": "Long Hop",
		"concept": "Longer air control, ice, moss and late-game recovery",
	},
]

var current_level_index: int = 0

var level_scenes: Array[String] = []
var level_names: Array[String] = []
var level_concepts: Array[String] = []

var unlocked_level_count: int = 1
var best_times: Array[float] = []
var best_clean_streaks: Array[int] = []
var top_times: Array = []

func _ready() -> void:
	_sync_level_catalog()
	_ensure_record_arrays()
	load_records()

func get_current_scene() -> String:
	return level_scenes[current_level_index]

func get_level_count() -> int:
	return level_scenes.size()

func advance_level() -> void:
	unlock_level(current_level_index + 1)
	current_level_index = (current_level_index + 1) % level_scenes.size()

func get_next_scene() -> String:
	var next := (current_level_index + 1) % level_scenes.size()
	return level_scenes[next]

func is_last_level() -> bool:
	return current_level_index >= level_scenes.size() - 1

func reset() -> void:
	current_level_index = 0

func start_level(index: int) -> void:
	current_level_index = clampi(index, 0, level_scenes.size() - 1)

func is_level_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_level_count

func unlock_level(index: int) -> void:
	if index < 0:
		return
	unlocked_level_count = clampi(maxi(unlocked_level_count, index + 1), 1, level_scenes.size())
	save_records()

func record_level_result(index: int, time_seconds: float, clean_streak: int) -> bool:
	var result := record_level_time(index, time_seconds, clean_streak)
	return bool(result.get("new_record", false))

func record_level_time(index: int, time_seconds: float, clean_streak: int) -> Dictionary:
	_ensure_record_arrays()
	if index < 0 or index >= level_scenes.size():
		return {
			"qualified": false,
			"new_record": false,
			"rank": -1,
			"previous_best": -1.0,
			"time": time_seconds,
			"entries": [],
		}

	var previous_best: float = best_times[index]
	var entries: Array = top_times[index].duplicate(true)
	var entry := {
		"time": time_seconds,
		"date": Time.get_datetime_string_from_system(false, true),
	}
	entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 999999.0)) < float(b.get("time", 999999.0))
	)

	var rank := -1
	for i in entries.size():
		if entries[i] == entry:
			rank = i + 1
			break

	var qualified := rank > 0 and rank <= 10
	if entries.size() > 10:
		entries.resize(10)
	top_times[index] = entries

	var new_record := qualified and rank == 1
	if entries.size() > 0:
		best_times[index] = float(entries[0].get("time", -1.0))
	best_clean_streaks[index] = maxi(best_clean_streaks[index], clean_streak)
	unlock_level(index + 1)
	save_records()

	return {
		"qualified": qualified,
		"new_record": new_record,
		"rank": rank if qualified else -1,
		"previous_best": previous_best,
		"time": time_seconds,
		"entries": entries.duplicate(true),
	}

func get_best_time(index: int) -> float:
	_ensure_record_arrays()
	if index < 0 or index >= best_times.size():
		return -1.0
	return best_times[index]

func get_best_clean_streak(index: int) -> int:
	_ensure_record_arrays()
	if index < 0 or index >= best_clean_streaks.size():
		return 0
	return best_clean_streaks[index]

func get_level_top_times(index: int) -> Array:
	_ensure_record_arrays()
	if index < 0 or index >= top_times.size():
		return []
	return top_times[index].duplicate(true)

func get_level_name(index: int) -> String:
	if index >= 0 and index < level_names.size():
		return level_names[index]
	return "Level %d" % (index + 1)

func get_level_concept(index: int) -> String:
	if index >= 0 and index < level_concepts.size():
		return level_concepts[index]
	return ""

func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "--.--"
	var total_milliseconds := int(round(seconds * 1000.0))
	var minutes := total_milliseconds / 60000
	var remaining := total_milliseconds % 60000
	var whole_seconds := remaining / 1000
	var milliseconds := remaining % 1000
	return "%d:%02d.%03d" % [minutes, whole_seconds, milliseconds]

func load_records() -> void:
	_ensure_record_arrays()
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return

	unlocked_level_count = int(config.get_value("progress", "unlocked_level_count", 1))
	unlocked_level_count = clampi(unlocked_level_count, 1, level_scenes.size())
	for i in level_scenes.size():
		var section := "level_%d" % (i + 1)
		best_times[i] = float(config.get_value(section, "best_time", -1.0))
		best_clean_streaks[i] = int(config.get_value(section, "best_clean_streak", 0))
		var entries: Array = []
		for rank in 10:
			var key := "time_%d" % rank
			if not config.has_section_key(section, key):
				continue
			entries.append({
				"time": float(config.get_value(section, key, -1.0)),
				"date": str(config.get_value(section, "date_%d" % rank, "")),
			})
		if entries.is_empty() and best_times[i] >= 0.0:
			entries.append({"time": best_times[i], "date": ""})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("time", 999999.0)) < float(b.get("time", 999999.0))
		)
		if entries.size() > 10:
			entries.resize(10)
		top_times[i] = entries
		if entries.size() > 0:
			best_times[i] = float(entries[0].get("time", best_times[i]))

func save_records() -> void:
	_ensure_record_arrays()
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level_count", unlocked_level_count)
	for i in level_scenes.size():
		var section := "level_%d" % (i + 1)
		config.set_value(section, "best_time", best_times[i])
		config.set_value(section, "best_clean_streak", best_clean_streaks[i])
		var entries: Array = top_times[i]
		for rank in entries.size():
			var entry: Dictionary = entries[rank]
			config.set_value(section, "time_%d" % rank, float(entry.get("time", -1.0)))
			config.set_value(section, "date_%d" % rank, str(entry.get("date", "")))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save Flaibai records.")

func _ensure_record_arrays() -> void:
	if level_scenes.is_empty():
		_sync_level_catalog()
	while best_times.size() < level_scenes.size():
		best_times.append(-1.0)
	while best_clean_streaks.size() < level_scenes.size():
		best_clean_streaks.append(0)
	while top_times.size() < level_scenes.size():
		top_times.append([])
	if best_times.size() > level_scenes.size():
		best_times.resize(level_scenes.size())
	if best_clean_streaks.size() > level_scenes.size():
		best_clean_streaks.resize(level_scenes.size())
	if top_times.size() > level_scenes.size():
		top_times.resize(level_scenes.size())

func _sync_level_catalog() -> void:
	level_scenes.clear()
	level_names.clear()
	level_concepts.clear()
	for raw_entry in LEVEL_CATALOG:
		var entry: Dictionary = raw_entry
		var scene_path: String = str(entry.get("scene", ""))
		if scene_path.is_empty():
			continue
		level_scenes.append(scene_path)
		level_names.append(str(entry.get("name", "Level %d" % level_scenes.size())))
		level_concepts.append(str(entry.get("concept", "")))
