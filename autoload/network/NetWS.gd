# res://autoload/network/NetWS.gd
extends Node

enum State { DISCONNECTED, CONNECTING, AUTHENTICATED }

var _ws_peer: WebSocketPeer = WebSocketPeer.new()
var _current_state: State = State.DISCONNECTED
var _backoff: Backoff
var _reconnect_timer: Timer
var _hello_timer: Timer
@warning_ignore("unused_private_class_variable")
var _heartbeat_timer: Timer # Оставляем для будущей реализации пингов

var _idempotent_queue: Array = []

func _ready() -> void:
	_backoff = Backoff.new(
		Config.get_value("backoff_base_ms", 500),
		Config.get_value("backoff_max_ms", 15000)
	)
	
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_on_reconnect_timeout)
	add_child(_reconnect_timer)
	
	_hello_timer = Timer.new()
	_hello_timer.one_shot = true
	_hello_timer.timeout.connect(_on_hello_timeout)
	add_child(_hello_timer)
	
	HttpAuth.refresh_completed.connect(_on_refresh_completed)

func _process(_delta: float) -> void:
	if _ws_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws_peer.poll()
		var state = _ws_peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _ws_peer.get_available_packet_count() > 0:
				_process_message(_ws_peer.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			var code = _ws_peer.get_close_code()
			var reason = _ws_peer.get_close_reason()
			_handle_disconnect(reason, code)

func connect_to_server() -> void:
	if _current_state != State.DISCONNECTED:
		return
	_current_state = State.CONNECTING
	_attempt_connection()
	
func close_connection() -> void:
	if _ws_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		Log.info("Closing WebSocket connection by client request.")
		_ws_peer.close()
		
func _attempt_connection() -> void:
	if _current_state != State.CONNECTING:
		return

	if not Session.is_access_valid():
		Log.warn("Cannot connect: access token is not valid. Attempting refresh.")
		HttpAuth.refresh()
		return

	EventBus.net_disconnected.emit("Connecting...")

	var url: String = Config.get_value("ws_url")

	# ВАЖНО: в Godot 4 заголовки через handshake_headers (а НЕ custom_headers)
	_ws_peer.handshake_headers = PackedStringArray([
		"Authorization: Bearer %s" % Session.access_token
	])
	# при необходимости:
	# _ws_peer.supported_protocols = PackedStringArray(["your-subprotocol"])

	var tls_opts: TLSOptions = null
	if url.begins_with("wss://"):
		tls_opts = TLSOptions.client()
		# если самоподписанный сертификат:
		# tls_opts = TLSOptions.client_unsafe()

	Log.info("Connecting to WebSocket: " + url)
	var err: int = _ws_peer.connect_to_url(url, tls_opts)
	if err != OK:
		Log.error("WebSocket connect error: " + error_string(err))
		_handle_disconnect("Connection error", -1)
		return

	_hello_timer.start(float(Config.get_value("hello_timeout_ms", 5000)) / 1000.0)

func send_command(domain: String, command: String, payload: Dictionary, idempotent: bool = false) -> String:
	var request_id := "req_" + UUID.new_uuid_string()
	
	var frame = {
		"type": "command", "v": 1, "request_id": request_id,
		"domain": domain, "command": command, "payload": payload
	}
	
	if _current_state != State.AUTHENTICATED:
		if idempotent:
			_idempotent_queue.push_back(frame)
			Log.warn("Not connected. Queued idempotent command: " + command)
		else:
			Log.error("Cannot send non-idempotent command while offline: " + command)
			EventBus.net_error.emit("client.offline", {"message": "Cannot send command"})
		return ""

	RequestLedger.register(request_id, Config.get_value("send_timeout_ms", 5000))
	_ws_peer.send_text(JSON.stringify(frame))
	return request_id

func _process_message(msg_str: String) -> void:
	var data = JSON.parse_string(msg_str)
	if data == null:
		Log.error("Failed to parse server message: " + msg_str)
		return

	var msg_type: String = data.get("type", "unknown")
	var request_id: String = data.get("request_id", "")

	if msg_type == "hello":
		_hello_timer.stop()
		_current_state = State.AUTHENTICATED
		Session.connection_id = data.get("connection_id")
		_backoff.reset()
		EventBus.net_authenticated.emit(Session.connection_id)
		# --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
		Log.info("WebSocket Authenticated! Connection ID: " + Session.connection_id)
		_resend_idempotent_queue()
	
	elif msg_type == "event":
		if not request_id.is_empty():
			RequestLedger.complete(request_id, data)
		else:
			EventBus.net_event.emit(data.get("event"), data.get("payload"), null)
			
	elif msg_type == "error":
		if not request_id.is_empty():
			RequestLedger.fail(request_id, data.get("error", {}).get("code"), data)
		else:
			EventBus.net_error.emit(data.get("error", {}).get("code"), data)

func _handle_disconnect(reason: String, code: int) -> void:
	if _current_state == State.DISCONNECTED:
		return
		
	Log.warn("WebSocket disconnected. Reason: %s (code: %d)" % [reason, code])
	_current_state = State.DISCONNECTED
	_hello_timer.stop()
	
	RequestLedger.fail_all_on_disconnect()
	EventBus.net_disconnected.emit(reason)
	
	if code == 4001: # 4001 - наш кастомный код для ошибки авторизации
		Log.info("Auth failed on handshake (401). Refreshing token…")
		HttpAuth.refresh()
	else:
		_schedule_reconnect()

func _schedule_reconnect() -> void:
	var delay := _backoff.get_next_delay_sec()
	Log.info("Scheduling reconnect in %.2f seconds..." % delay)
	_reconnect_timer.wait_time = delay
	_reconnect_timer.start()

func _on_reconnect_timeout() -> void:
	if _current_state == State.DISCONNECTED:
		Log.info("Reconnect timer fired. Attempting to connect.")
		_attempt_connection()

func _on_hello_timeout():
	if _current_state == State.CONNECTING:
		Log.error("Server did not send HELLO frame in time.")
		_ws_peer.close(4000, "Hello timeout")

func _on_refresh_completed(success: bool, _data_or_error):
	if success and _current_state == State.DISCONNECTED:
		Log.info("Tokens refreshed successfully. Re-initiating connection.")
		_attempt_connection()
	elif not success:
		Log.error("Token refresh failed. Cannot reconnect automatically.")
		EventBus.net_error.emit("auth.refresh_failed", {"message": "Could not refresh token."})

func _resend_idempotent_queue():
	if _idempotent_queue.is_empty():
		return
		
	Log.info("Resending %d idempotent commands from queue..." % _idempotent_queue.size())
	var temp_queue = _idempotent_queue.duplicate()
	_idempotent_queue.clear()
	for frame in temp_queue:
		RequestLedger.register(frame["request_id"], Config.get_value("send_timeout_ms", 5000))
		_ws_peer.send_text(JSON.stringify(frame))
