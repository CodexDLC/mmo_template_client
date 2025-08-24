# res://autoload/RequestLedger.gd
extends Node

# Сигнал, когда запрос успешно выполнен
signal request_completed(request_id, payload)
# Сигнал, когда запрос провалился (ошибка от сервера или таймаут)
signal request_failed(request_id, error_code, details)

# Словарь для хранения "подвисших" запросов
# Формат: { "request_id": { "timeout_at": unix_timestamp } }
var _pending_requests: Dictionary = {}

func _process(_delta: float) -> void:
	# Проверяем таймауты каждый кадр. Для большого кол-ва запросов лучше использовать таймер.
	var now = Time.get_unix_time_from_system()
	var timed_out_ids: Array = []
	
	for request_id in _pending_requests:
		if now >= _pending_requests[request_id]["timeout_at"]:
			timed_out_ids.append(request_id)
			
	for request_id in timed_out_ids:
		fail(request_id, "client.request_timeout", {"message": "Request timed out after TTL."})

## Регистрирует новый запрос в "книге"
func register(request_id: String, timeout_ms: int) -> bool:
	var cap = Config.get_value("ledger_cap", 256)
	if _pending_requests.size() >= cap:
		Log.error("RequestLedger is full (cap: %d). Rejecting new request." % cap)
		return false
		
	var timeout_sec = timeout_ms / 1000.0
	_pending_requests[request_id] = {
		"timeout_at": Time.get_unix_time_from_system() + timeout_sec
	}
	return true

## Завершает запрос как успешный
func complete(request_id: String, payload: Dictionary) -> void:
	if _pending_requests.has(request_id):
		_pending_requests.erase(request_id)
		request_completed.emit(request_id, payload)
		Log.info("Request completed: " + request_id)

## Завершает запрос как проваленный
func fail(request_id: String, code: String, details: Dictionary) -> void:
	if _pending_requests.has(request_id):
		_pending_requests.erase(request_id)
		request_failed.emit(request_id, code, details)
		Log.warn("Request failed: %s (code: %s)" % [request_id, code])

## Очищает все "подвисшие" запросы при разрыве соединения
func fail_all_on_disconnect() -> void:
	var all_ids = _pending_requests.keys()
	Log.warn("Failing all %d pending requests due to disconnect." % all_ids.size())
	for request_id in all_ids:
		fail(request_id, "client.connection_lost", {"message": "Connection was lost."})
