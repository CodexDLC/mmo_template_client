# res://ui/Playground.gd
extends Control

@onready var status_label: Label = $VBoxContainer/HBoxContainer/StatusBar/StatusLabel
@onready var counters_label: Label = $VBoxContainer/HBoxContainer/StatusBar/CountersLabel
@onready var json_input: TextEdit = $VBoxContainer/HSplitContainer/VBoxContainer/JsonInput
@onready var send_button: Button = $VBoxContainer/HSplitContainer/VBoxContainer/HBoxContainer/SendButton
@onready var reconnect_button: Button = $VBoxContainer/HSplitContainer/VBoxContainer/HBoxContainer/ReconnectButton
@onready var clear_button: Button = $VBoxContainer/HSplitContainer/VBoxContainer/HBoxContainer/ClearButton
@onready var export_button: Button = $VBoxContainer/HSplitContainer/VBoxContainer/HBoxContainer/ExportButton
@onready var preset1_button: Button = $VBoxContainer/HSplitContainer/VBoxContainer/TabContainer/Presets/Preset1Button
@onready var event_log: RichTextLabel = $VBoxContainer/HSplitContainer/EventLog
@onready var NetWS: Node = get_node("/root/NetWS")

func _ready() -> void:
	# Подписываемся на все события, чтобы логировать их
	EventBus.net_event.connect(_on_net_event)
	EventBus.net_error.connect(_on_net_error)
	EventBus.net_authenticated.connect(func(_cid): _log_message("[color=green]Authenticated![/color]"))
	EventBus.net_disconnected.connect(func(r): _log_message("[color=yellow]Disconnected: %s[/color]" % r))

	send_button.pressed.connect(_on_send_pressed)
	reconnect_button.pressed.connect(NetWS.connect_to_server)
	clear_button.pressed.connect(event_log.clear)
	export_button.pressed.connect(Log.export_to_file)
	preset1_button.pressed.connect(_on_preset1_pressed)
	
	# --- ИСПРАВЛЕНИЕ ЗДЕСЬ: Настройка горячих клавиш ---
	var send_shortcut = Shortcut.new()
	var send_event = InputEventKey.new()
	send_event.keycode = KEY_ENTER
	send_event.ctrl_pressed = true
	send_shortcut.events = [send_event]
	send_button.shortcut = send_shortcut

	var reconnect_shortcut = Shortcut.new()
	var reconnect_event = InputEventKey.new()
	reconnect_event.keycode = KEY_F5
	reconnect_shortcut.events = [reconnect_event]
	reconnect_button.shortcut = reconnect_shortcut

	var export_shortcut = Shortcut.new()
	var export_event = InputEventKey.new()
	export_event.keycode = KEY_L
	export_event.ctrl_pressed = true
	export_shortcut.events = [export_event]
	export_button.shortcut = export_shortcut
	# --- КОНЕЦ ИСПРАВЛЕНИЯ ---
	
	_log_message("[color=aqua]Playground ready.[/color]")
	_on_preset1_pressed()


func _process(_delta: float) -> void:
	# Обновляем счетчики в статус-баре
	var in_flight = RequestLedger._pending_requests.size()
	counters_label.text = "In-flight: %d" % in_flight

func _on_send_pressed() -> void:
	var text = json_input.text
	var data = JSON.parse_string(text)
	
	if data == null:
		_log_message("[color=red]ERROR: Invalid JSON[/color]")
		return
	
	if not data is Dictionary or not data.has("domain") or not data.has("command"):
		_log_message("[color=red]ERROR: JSON must be a dictionary with 'domain' and 'command' keys.[/color]")
		return
		
	var domain = data.get("domain")
	var command = data.get("command")
	var payload = data.get("payload", {})
	
	_log_message("[color=orange]>> SENT:[
	]  Domain: %s, Command: %s, Payload: %s[/color]" % [domain, command, payload])
	NetWS.send_command(domain, command, payload)

# --- Обработчики сигналов ---

func _on_net_event(topic: String, body: Dictionary, request_id: String) -> void:
	var color = "cyan" if request_id else "green" # Ответы на запросы - голубые, бродкасты - зеленые
	var msg = "[color=%s]<< RECV (Event):[
	]  Topic: %s, Body: %s, ReqID: %s[/color]" % [color, topic, body, request_id]
	_log_message(msg)

func _on_net_error(code: String, details: Dictionary) -> void:
	var msg = "[color=red]<< RECV (Error):[
	]  Code: %s, Details: %s[/color]" % [code, details]
	_log_message(msg)

# --- Пресеты ---

func _on_preset1_pressed() -> void:
	var ping_command = {
		"domain": "system",
		"command": "ping",
		"payload": { "sent_at": Time.get_unix_time_from_system() }
	}
	json_input.text = JSON.stringify(ping_command, "  ")

# --- Утилиты ---

func _log_message(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	event_log.append_text("[%s] %s\n" % [timestamp, message])
