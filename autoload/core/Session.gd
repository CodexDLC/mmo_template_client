# res://autoload/Session.gd
extends Node

var access_token: String = ""
var refresh_token: String = ""
var expires_at: int = 0  # UNIX timestamp
var connection_id: String = ""

func set_tokens(new_access: String, new_refresh: String, expires_in_sec: int) -> void:
	self.access_token = new_access
	self.refresh_token = new_refresh
	if expires_in_sec > 0:
		# Явно преобразуем в int, чтобы убрать предупреждение
		self.expires_at = int(Time.get_unix_time_from_system() + expires_in_sec)
	else:
		self.expires_at = 0
	Log.info("Session tokens updated.")

func is_access_valid() -> bool:
	if access_token.is_empty() or expires_at == 0:
		return false
	# Проверяем, что токен истекает не раньше, чем через 10 секунд
	return Time.get_unix_time_from_system() < (expires_at - 10)

func clear() -> void:
	access_token = ""
	refresh_token = ""
	expires_at = 0
	connection_id = ""
	Log.info("Session cleared.")
