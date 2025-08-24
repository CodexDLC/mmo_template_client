# res://autoload/Log.gd
extends Node

const MAX_LOG_ENTRIES = 1000
var log_buffer: Array = []

enum LogLevel { INFO, WARN, ERROR }

func info(message: String) -> void:
	_add_entry(LogLevel.INFO, message)
	print("[INFO] " + message)

func warn(message: String) -> void:
	_add_entry(LogLevel.WARN, message)
	push_warning("[WARN] " + message)

func error(message: String) -> void:
	_add_entry(LogLevel.ERROR, message)
	push_error("[ERROR] " + message)

func _add_entry(level: LogLevel, message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system(true)
	log_buffer.push_back({
		"ts": timestamp,
		"level": LogLevel.keys()[level].to_lower(),
		"msg": message
	})
	if log_buffer.size() > MAX_LOG_ENTRIES:
		log_buffer.pop_front()

func export_to_file(path: String = "user://game_log.txt") -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		error("Failed to open log file for writing at: " + path)
		return false

	for entry in log_buffer:
		# Используем встроенный JSON.stringify
		file.store_line(JSON.stringify(entry))

	file.close()
	info("Log buffer exported to " + path)
	return true
