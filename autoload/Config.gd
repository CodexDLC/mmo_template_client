# res://autoload/Config.gd
extends Node

var _config: Dictionary = {}
const CONFIG_PATH = "user://config.json"

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	# 1. Загружаем дефолтный конфиг из res://
	var default_file = FileAccess.open("res://config/default_config.json", FileAccess.READ)
	if not default_file:
		Log.error("Default config file is missing at res://config/default_config.json!")
		return

	var default_content = default_file.get_as_text()
	var parse_result = JSON.parse_string(default_content)
	if parse_result != null:
		_config = parse_result
	else:
		Log.error("Failed to parse default_config.json")
		return

	# 2. Пытаемся загрузить пользовательский конфиг из user://
	if FileAccess.file_exists(CONFIG_PATH):
		var user_file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var user_content = user_file.get_as_text()
		var user_config = JSON.parse_string(user_content)
		if user_config is Dictionary:
			# Объединяем конфиги, пользовательские значения имеют приоритет
			_config.merge(user_config, true)

	Log.info("Configuration loaded.")
	# Сохраняем объединенный конфиг, чтобы добавить новые ключи, если они появились в default_config
	_save_config()

func get_value(key: String, default: Variant = null) -> Variant:
	return _config.get(key, default)

func set_value(key: String, value: Variant) -> void:
	_config[key] = value
	_save_config()

func _save_config() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		# Используем встроенный JSON.stringify с отступом для читаемости
		file.store_string(JSON.stringify(_config, "\t"))
		file.close()
