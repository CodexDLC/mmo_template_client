# res://ui/session/lobby/lobby.gd
# Скрипт управляет сценой Лобби.
extends Control

## --- СИГНАЛЫ (Контракт: Сцена -> Main) ---
signal request_open_debug
signal request_logout

## --- ССЫЛКИ НА УЗЛЫ ---
@onready var status_label: Label
@onready var play_button: Button
@onready var debug_button: Button
@onready var logout_button: Button

func _ready() -> void:
	if not _validate_scene_contract():
		set_process(false)
		return
	
	debug_button.pressed.connect(request_open_debug.emit)
	logout_button.pressed.connect(request_logout.emit)

## --- ПУБЛИЧНЫЕ МЕТОДЫ ---
func set_status(text: String) -> void:
	if status_label: status_label.text = text

func set_busy(is_busy: bool) -> void:
	play_button.disabled = is_busy
	debug_button.disabled = is_busy
	logout_button.disabled = is_busy

func show_error(text: String) -> void:
	if status_label: status_label.text = "[color=red]" + text + "[/color]"

## --- ПРОВЕРКА КОНТРАКТА ---
func _validate_scene_contract() -> bool:
	var required_nodes = {
		"status_label": "g_status_label",
		"play_button": "g_play_button",
		"debug_button": "g_debug_button",
		"logout_button": "g_logout_button",
	}
	for var_name in required_nodes:
		var node = get_tree().get_first_node_in_group(required_nodes[var_name])
		if node:
			set(var_name, node)
		else:
			Log.error("Scene contract validation failed for Lobby.tscn! Group '%s' not found." % required_nodes[var_name])
			return false
	return true
