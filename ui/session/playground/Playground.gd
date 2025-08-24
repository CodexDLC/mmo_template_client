# res://ui/session/playground/playground.gd
# (Новая, переработанная версия для модульной архитектуры)
extends Control

## --- СИГНАЛЫ (Контракт: Сцена -> Main) ---
# Эти сигналы сообщают Main.gd о намерениях пользователя.
signal request_send_command(data: Dictionary)
# Запрос на переподключение к WebSocket.
signal request_reconnect
# Запрос на экспорт логов в файл.
signal request_export_logs

## --- ССЫЛКИ НА УЗЛЫ (Контракт: Поиск по группам) ---
@onready var json_input: TextEdit
@onready var send_button: Button
@onready var reconnect_button: Button
@onready var clear_button: Button
@onready var export_logs_button: Button
@onready var presets_container: VBoxContainer
@onready var event_log: RichTextLabel
@onready var status_label: Label
@onready var counters_label: Label
# Временное решение для кнопки-пресета, пока нет динамической логики
@onready var preset1_button: Button

# _ready() вызывается один раз при создании узла.
func _ready() -> void:
	# Добавляем лог о готовности скрипта
	Log.info("Playground.gd is ready.")

	if not _validate_scene_contract():
		set_process(false)
		return
	
	# Подключаем сигналы от кнопок к нашим функциям.
	send_button.pressed.connect(_on_send_pressed)
	reconnect_button.pressed.connect(request_reconnect.emit)
	clear_button.pressed.connect(event_log.clear)
	export_logs_button.pressed.connect(request_export_logs.emit)
	preset1_button.pressed.connect(_on_preset1_pressed)

	# Настройка горячих клавиш (остается здесь, так как это логика UI)
	var send_shortcut = Shortcut.new()
	var send_event = InputEventKey.new()
	send_event.keycode = KEY_ENTER
	send_event.ctrl_pressed = true
	send_shortcut.events = [send_event]
	send_button.shortcut = send_shortcut
	
	_on_preset1_pressed()

## --- ПУБЛИЧНЫЕ МЕТОДЫ (Контракт: Main -> Сцена) ---
# Эти функции будет вызывать Main.gd, чтобы управлять этим экраном.
func set_status(text: String) -> void:
	status_label.text = text

func set_counters(in_flight_requests: int) -> void:
	counters_label.text = "In-flight: %d" % in_flight_requests
	
func log_message(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	event_log.append_text("[%s] %s\n" % [timestamp, message])

func set_busy(is_busy: bool) -> void:
	send_button.disabled = is_busy

func set_auth_state(is_authenticated: bool) -> void:
	send_button.disabled = not is_authenticated
	reconnect_button.disabled = not is_authenticated

func show_error(text: String) -> void:
	log_message("[color=red]ERROR: %s[/color]" % text)

## --- ВНУТРЕННИЕ ФУНКЦИИ ---

# Вызывается при нажатии кнопки "Send".
func _on_send_pressed() -> void:
	Log.info("Send button pressed.")
	var text = json_input.text
	var data = JSON.parse_string(text)
	
	if data == null:
		show_error(tr("Invalid JSON"))
		Log.error("Attempt to send invalid JSON.")
		return
		
	var is_command_frame = data is Dictionary and data.has("domain") and data.has("command")
	var is_special_frame = data is Dictionary and data.has("type")
	
	if not (is_command_frame or is_special_frame):
		show_error(tr("JSON must be a dictionary with 'domain' and 'command' keys, or a 'type' key."))
		Log.error("JSON validation failed.")
		return
	
	Log.info("Sending command: " + str(data))
	request_send_command.emit(data)

# Заполняет поле ввода "ping" командой.
func _on_preset1_pressed() -> void:
	Log.info("Ping Command preset loaded.")
	var ping_command = {
		"type": "ping"
	}
	json_input.text = JSON.stringify(ping_command, "  ")


## --- ПРОВЕРКА КОНТРАКТА ---
# Убеждаемся, что все узлы с нужными группами существуют в сцене.
func _validate_scene_contract() -> bool:
	var required_nodes = {
		"json_input": "g_json_input",
		"send_button": "g_send_button",
		"reconnect_button": "g_reconnect_button",
		"clear_button": "g_clear_button",
		"export_logs_button": "g_export_logs_button",
		"presets_container": "g_presets_container",
		"event_log": "g_event_log",
		"status_label": "g_status_label",
		"counters_label": "g_counters_label",
	}
	
	for var_name in required_nodes:
		var node = get_tree().get_first_node_in_group(required_nodes[var_name])
		if node:
			set(var_name, node)
		else:
			Log.error("Scene contract validation failed for Playground.tscn! Group '%s' not found." % required_nodes[var_name])
			return false
			
	# Находим кнопку пресета внутри контейнера по имени.
	preset1_button = presets_container.get_node_or_null("Preset1Button")
	if not preset1_button:
		Log.error("Preset1Button not found inside PresetsContainer!")
		return false
		
	Log.info("Scene contract for Playground.tscn validated successfully.")
	return true
