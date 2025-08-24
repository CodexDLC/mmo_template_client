# res://ui/session/main/Main.gd
extends Control

@onready var view_root: Control = $ViewRoot
@onready var error_dialog: AcceptDialog = $ErrorDialog

var _current_screen: Node = null

## --- РЕФАКТОРИНГ: Переменные для хранения путей к сценам ---
# Мы будем загружать пути из конфига только один раз при старте
# и хранить их здесь. Это убирает повторы и делает код быстрее.
var _start_scene_path: String
var _register_scene_path: String
var _lobby_scene_path: String
var _playground_scene_path: String


func _ready() -> void:
	Log.info("Main UI Controller is ready. Application started.")
	
	_load_ui_config()
	
	# Подписываемся на глобальные события от EventBus.
	# Эти подключения будут жить всё время, пока существует Main.
	EventBus.net_authenticated.connect(_on_net_authenticated)
	EventBus.net_disconnected.connect(_on_net_disconnected)
	
	# Проверяем, что базовый путь к стартовой сцене существует.
	if _start_scene_path.is_empty():
		Log.error("Start scene path is not defined in 'ui' config section!")
		error_dialog.dialog_text = "Critical Error: Start scene path is not configured."
		error_dialog.popup_centered()
		return
		
	# Запускаем навигацию на стартовый экран.
	_change_screen(_start_scene_path)
	

## --- РЕФАКТОРИНГ: Новая функция для загрузки и кэширования конфига ---
# Эта функция вызывается один раз в _ready(), чтобы заполнить наши переменные.
func _load_ui_config() -> void:
	var ui_config: Dictionary = Config.get_value("ui")
	if ui_config.is_empty():
		Log.error("'ui' section is not defined in config file!")
		return
	
	# Заполняем наши переменные класса
	_start_scene_path = ui_config.get("start_scene", "")
	_register_scene_path = ui_config.get("register_scene", "")
	_lobby_scene_path = ui_config.get("lobby_scene", "")
	_playground_scene_path = ui_config.get("playground_scene", "")
	Log.info("UI scene paths loaded and cached.")


func _change_screen(scene_path: String) -> void:
	if _current_screen != null:
		view_root.remove_child(_current_screen)
		_current_screen.queue_free()
		_current_screen = null

	var scene_resource = load(scene_path)
	if scene_resource == null:
		Log.error("Failed to load scene resource at path: " + scene_path)
		return

	_current_screen = scene_resource.instantiate()
	view_root.add_child(_current_screen)
	Log.info("Screen '%s' loaded and added to ViewRoot." % scene_path)
	
	# --- РЕФАКТОРИНГ: Теперь сравнение идет с переменными класса ---
	# Это чище, чем каждый раз вызывать Config.get_value()
	if scene_path == _start_scene_path:
		_current_screen.request_login.connect(_on_start_screen_request_login)
		_current_screen.request_open_register.connect(_on_start_screen_request_open_register)
		_current_screen.request_open_debug.connect(_on_start_screen_request_open_debug)
	
	elif scene_path == _register_scene_path:
		_current_screen.request_register.connect(_on_register_screen_request_register)
		_current_screen.request_back.connect(_on_register_screen_request_back)
		
	elif scene_path == _lobby_scene_path:
		_current_screen.request_open_debug.connect(_on_lobby_screen_request_open_debug)
		_current_screen.request_logout.connect(_on_lobby_screen_request_logout)

## --- ОБРАБОТЧИКИ СИГНАЛОВ ОТ ЭКРАНОВ ---

func _on_start_screen_request_login(username, password) -> void:
	Log.info("Main: Received login request for user '%s'." % username)
	
	var screen = _current_screen as Control
	if screen and screen.has_method("set_busy"):
		screen.set_status(tr("Logging in..."))
		screen.set_busy(true)
	
	HttpAuth.login_completed.connect(_on_http_login_completed, CONNECT_ONE_SHOT)
	HttpAuth.login({"username": username, "password": password})
	
# --- РЕФАКТОРИНГ: Упрощенная навигация ---
func _on_start_screen_request_open_register() -> void:
	Log.info("Main: Received request to open register screen.")
	# Просто вызываем смену экрана с уже готовым путем.
	_change_screen(_register_scene_path)

func _on_register_screen_request_register(email, username, password) -> void:
	Log.info("Main: Received register request for user '%s' with email '%s'." % [username, email])
	
	var screen = _current_screen as Control
	if screen and screen.has_method("set_busy"):
		screen.set_status(tr("Registering..."))
		screen.set_busy(true)
	
	HttpAuth.register_completed.connect(_on_http_register_completed, CONNECT_ONE_SHOT)
	HttpAuth.register({"email": email, "username": username, "password": password})
	
# --- РЕФАКТОРИНГ: Упрощенная навигация ---
func _on_register_screen_request_back() -> void:
	Log.info("Main: Received request to go back from register screen.")
	# Просто вызываем смену экрана с уже готовым путем.
	_change_screen(_start_scene_path)


## --- ОБРАБОТЧИКИ ОТВЕТОВ ОТ СЕТЕВЫХ МОДУЛЕЙ ---

func _on_http_login_completed(ok: bool, data_or_err) -> void:
	var screen = _current_screen as Control
	# Убеждаемся, что мы все еще на экране входа
	if not screen or screen.scene_file_path != _start_scene_path:
		return

	if ok:
		Log.info("HTTP login successful! Now connecting to WebSocket...")
		screen.set_status(tr("Connecting..."))
		NetWS.connect_to_server()
	else:
		Log.error("HTTP login failed: " + str(data_or_err))
		
		var error_message_text = "Login failed. Please try again."
		
		# --- УЛУЧШЕННОЕ ИСПРАВЛЕНИЕ: ПРОВЕРЯЕМ РЕЗУЛЬТАТ ПАРСИНГА ---
		var parser = JSON.new()
		var parse_result = parser.parse(str(data_or_err))
		
		if parse_result == OK:
			var parsed_error = parser.get_data()
			if parsed_error is Dictionary and parsed_error.has("detail"):
				# Формат ошибки, который приходит с HTTP 401/403
				error_message_text = str(parsed_error.detail)
			elif parsed_error is Array and parsed_error.size() > 0:
				# Формат ошибки валидации (HTTP 422)
				var first_error = parsed_error[0]
				if first_error is Dictionary and first_error.has("msg"):
					error_message_text = str(first_error.msg)
			else:
				# Если не удалось найти понятное сообщение в JSON
				error_message_text = "An unexpected error occurred."
		else:
			# Если парсинг JSON полностью провалился, используем исходный текст
			error_message_text = str(data_or_err)
		
		screen.show_error(error_message_text)
		screen.set_busy(false)
		# --- КОНЕЦ ИСПРАВЛЕНИЯ ---

func _on_http_register_completed(ok: bool, data_or_err) -> void:
	var screen = _current_screen as Control
	if not screen or not screen.is_in_group("g_register_button"):
		return
	
	if ok:
		Log.success("HTTP registration successful!")
		screen.set_status(tr("Success! You can now log in."))
		screen.set_busy(false)
	else:
		Log.error("HTTP registration failed: " + str(data_or_err))
		screen.show_error(str(data_or_err))
		screen.set_busy(false)

# Вызывается, когда EventBus сообщает об успешной аутентификации на WebSocket.
func _on_net_authenticated(_connection_id: String) -> void:
	Log.info("Main: Net authenticated. Navigating to Lobby.")
	_change_screen(_lobby_scene_path)

# Вызывается, когда EventBus сообщает о разрыве соединения.
func _on_net_disconnected(reason: String) -> void:
	Log.warn("Main: Net disconnected. Reason: %s" % reason)
	
	# --- ИСПРАВЛЕННЫЙ КОД ---
	# Используем свойство `scene_file_path`, которое хранит путь к файлу сцены ("res://...").
	# Теперь мы сравниваем две строки (String), что корректно.
	if _current_screen != null and _current_screen.scene_file_path != _start_scene_path:
		_change_screen(_start_scene_path)
	
	var screen = _current_screen as Control
	if screen and screen.has_method("set_status"):
		screen.set_status(tr("Disconnected"))
		screen.set_busy(false)

## --- НОВЫЕ ОБРАБОТЧИКИ ОТ ЭКРАНА ЛОББИ ---

func _on_lobby_screen_request_open_debug() -> void:
	# TODO: реализовать переход в Playground
	Log.info("Main: Request to open debug screen from Lobby.")

func _on_lobby_screen_request_logout() -> void:
	Log.info("Main: Request to log out from Lobby.")
	Session.clear() # Очищаем сессию (токены и т.д.)
	NetWS.close() # Корректно закрываем WebSocket соединение
	_change_screen(_start_scene_path) # Возвращаемся на экран входа
	
func _on_start_screen_request_open_debug() -> void:
	Log.info("Main: Request to open debug screen from Start screen.")
	# Проверяем, есть ли у нас вообще токен, чтобы было с чем работать
	if Session.is_access_valid():
		_change_screen(_playground_scene_path)
	else:
		# Уведомляем пользователя, что без входа это бессмысленно
		var screen = _current_screen as Control
		if screen and screen.has_method("show_error"):
			screen.show_error(tr("You need to log in first."))
