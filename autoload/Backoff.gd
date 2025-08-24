# res://autoload/Backoff.gd
class_name Backoff
extends RefCounted

var _base_delay_ms: float
var _max_delay_ms: float
var _current_delay_ms: float
var _attempts: int = 0

func _init(base_delay_ms: float, max_delay_ms: float):
	self._base_delay_ms = base_delay_ms
	self._max_delay_ms = max_delay_ms
	self._current_delay_ms = base_delay_ms

func get_next_delay_sec() -> float:
	var delay = self._current_delay_ms
	
	# Экспоненциально увеличиваем задержку для следующего раза
	self._current_delay_ms = min(self._current_delay_ms * 2, self._max_delay_ms)
	
	# Добавляем "джиттер" (случайное отклонение), чтобы избежать синхронных реконнектов от толпы клиентов
	var jitter = delay * 0.2
	return (delay + randf_range(-jitter, jitter)) / 1000.0

func reset() -> void:
	self._current_delay_ms = self._base_delay_ms
	self._attempts = 0
