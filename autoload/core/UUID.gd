# res://core/UUID.gd
class_name UUID
extends RefCounted

# Генерирует новый случайный UUID v4 в виде строки
static func new_uuid_string() -> String:
	var crypto = Crypto.new()
	# Генерируем 16 случайных байт
	var bytes = crypto.generate_random_bytes(16)
	
	# Устанавливаем биты версии 4 и варианта 1, как требует стандарт UUID v4
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	
	var hex = bytes.hex_encode()
	
	# Форматируем в стандартный вид 8-4-4-4-12
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]
