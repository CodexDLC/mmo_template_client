# res://autoload/HttpAuth.gd
extends Node

signal login_completed(ok: bool, data_or_err)
signal refresh_completed(success, data_or_error)


var _http_request: HTTPRequest
var _refresh_timer: Timer

var _is_refreshing: bool = false
const REFRESH_SKEW_SECONDS = 60

# --- ИСПРАВЛЕНИЕ: Переменная для хранения типа последнего запроса ---
var _last_request_type: String = ""

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	# --- ИСПРАВЛЕНИЕ: Убираем meta из параметров connect ---
	_http_request.request_completed.connect(_on_request_completed)

	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(refresh)
	add_child(_refresh_timer)
	
	Log.info("HttpAuth service ready.")

# --- PUBLIC API ---

func login(credentials: Dictionary) -> void:
	var url = Config.get_value("http_url") + "/auth/login"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(credentials)
	
	Log.info("Sending login request to " + url)
	# --- ИСПРАВЛЕНИЕ: Запоминаем тип запроса перед отправкой ---
	_last_request_type = "login"
	_http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func refresh() -> void:
	if _is_refreshing:
		Log.info("Refresh request is already in progress. Waiting for completion.")
		return
		
	if Session.refresh_token.is_empty():
		Log.warn("No refresh token available. Cannot refresh.")
		EventBus.net_error.emit("auth.no_refresh_token", {"message": "Refresh token is missing."})
		return

	_is_refreshing = true
	var url = Config.get_value("http_url") + "/auth/refresh"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"refresh_token": Session.refresh_token})
	
	Log.info("Sending token refresh request.")
	# --- ИСПРАВЛЕНИЕ: Запоминаем тип запроса перед отправкой ---
	_last_request_type = "refresh"
	_http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func force_expire() -> void:
	Session.expires_at = int(Time.get_unix_time_from_system() + 10)
	_schedule_refresh()
	Log.warn("Access token expiration forced for testing.")

# --- PRIVATE METHODS ---

# --- ИСПРАВЛЕНИЕ: Убираем meta из параметров ---
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var response_body_str = body.get_string_from_utf8()
	var response_data = JSON.parse_string(response_body_str)

	# --- ИСПРАВЛЕНИЕ: Используем переменную, которую сохранили ранее ---
	var request_type = _last_request_type
	_last_request_type = "" # Сбрасываем для чистоты

	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		_handle_http_error(request_type, response_code, response_data)
		return

	var data = response_data.get("data", {})
	if request_type == "login":
		Log.info("Login successful.")
		_update_session_and_schedule_refresh(data)
		login_completed.emit(true, data)
	elif request_type == "refresh":
		Log.info("Token refresh successful.")
		_is_refreshing = false
		_update_session_and_schedule_refresh(data)
		refresh_completed.emit(true, data)


func _handle_http_error(request_type: String, code: int, data: Variant) -> void:
	var error_message: String = "HTTP Error %d for %s" % [code, request_type]
	var detail_text: String = ""
	if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
		detail_text = str(data["detail"])
		error_message += ": " + detail_text

	# спец-ветка refresh
	if request_type == "refresh":
		_is_refreshing = false
		Session.clear()
		refresh_completed.emit(false, error_message)

	# спец-ветка login
	if request_type == "login":
		var msg: String = detail_text if detail_text != "" else error_message
		login_completed.emit(false, msg)

	Log.error(error_message)
	EventBus.net_error.emit("http.%d" % code, {"message": error_message})

func _update_session_and_schedule_refresh(data: Dictionary) -> void:
	var access = data.get("token", "")
	var refresh_tok = data.get("refresh_token", Session.refresh_token)
	var expires_in := int(data.get("expires_in", 0))
	var now_i: int = int(Time.get_unix_time_from_system())
	var exp_abs: int = now_i + expires_in
	Session.set_tokens(access, refresh_tok, exp_abs)
	_schedule_refresh()

func _schedule_refresh() -> void:
	_refresh_timer.stop()
	
	if not Session.is_access_valid():
		Log.info("Access token is already invalid, not scheduling refresh.")
		return

	var now_i: int = int(Time.get_unix_time_from_system())
	var time_to_expiry: int = Session.expires_at - now_i
	var time_to_refresh: int = time_to_expiry - REFRESH_SKEW_SECONDS

	if time_to_refresh > 0:
		_refresh_timer.wait_time = float(time_to_refresh)
		_refresh_timer.start()
	else:
		refresh()
