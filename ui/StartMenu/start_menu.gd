# res://ui/StartMenu.gd
extends Control

@onready var username_input: LineEdit = $VBoxContainer/UsernameInput
@onready var password_input: LineEdit = $VBoxContainer/PasswordInput
@onready var login_button: Button = $VBoxContainer/LoginButton
@onready var debug_button: Button = $VBoxContainer/DebugButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var error_dialog: AcceptDialog = $VBoxContainer/ErrorDialog
@onready var NetWS: Node = get_node("/root/NetWS")

func _ready() -> void:
	# Подписки на глобальные события
	EventBus.net_authenticated.connect(_on_net_authenticated)
	EventBus.net_disconnected.connect(_on_net_disconnected)
	EventBus.net_error.connect(_on_net_error)

	# Кнопки
	login_button.pressed.connect(_on_login_button_pressed)
	debug_button.pressed.connect(_on_debug_button_pressed)

	# Стартовые значения (удобно для теста)
	username_input.text = "testuser"
	password_input.text = "password123"
	status_label.text = "Status: Offline"

func _on_login_button_pressed() -> void:
	var username := username_input.text.strip_edges()
	var password := password_input.text
	if username.is_empty() or password.is_empty():
		_show_error("Username and password cannot be empty.")
		return

	status_label.text = "Status: Logging in..."
	login_button.disabled = true

	# Один раз ждём результат логина
	HttpAuth.login_completed.connect(_on_login_completed, CONNECT_ONE_SHOT)
	HttpAuth.login({"username": username, "password": password})

func _on_login_completed(ok: bool, data_or_err) -> void:
	if ok:
		status_label.text = "Status: Connecting..."
		NetWS.connect_to_server()
	else:
		var msg := String(data_or_err) if typeof(data_or_err) == TYPE_STRING else "Login failed."
		_show_error(msg)
	login_button.disabled = false

func _on_debug_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/Playground.tscn")

# --- EventBus handlers ---

func _on_net_authenticated(_connection_id: String) -> void:
	status_label.text = "Status: Authenticated!"
	Log.success("Authentication successful, changing scene to Playground.")
	get_tree().change_scene_to_file("res://ui/Playground.tscn")

func _on_net_disconnected(reason: String) -> void:
	status_label.text = "Status: %s" % reason
	login_button.disabled = false

func _on_net_error(code: String, details: Dictionary) -> void:
	status_label.text = "Status: Error"
	login_button.disabled = false
	var message: String = str(details.get("message", "Unknown error."))
	_show_error("Error (%s): %s" % [code, message])

	# Если HTTP-логин прошёл, но WS не коннектится — пробуем подключиться
	if code.begins_with("http.") == false and Session.is_access_valid():
		status_label.text = "Status: Connecting..."
		NetWS.connect_to_server()

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()
