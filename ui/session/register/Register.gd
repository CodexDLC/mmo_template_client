# res://ui/session/register/register.gd
# Скрипт управляет сценой регистрации.
# Он собирает данные, проверяет их и сообщает "наверх" (в Main.gd)
# о намерениях пользователя через сигналы.
extends Control

## --- СИГНАЛЫ (Контракт: Сцена -> Main) ---

# Сигнал для отправки запроса на регистрацию с данными пользователя.
signal request_register(email, username, password)
# Сигнал для возврата на предыдущий экран (на экран входа).
signal request_back


## --- ССЫЛКИ НА УЗЛЫ (Контракт: Поиск по группам) ---
@onready var email_input: LineEdit
@onready var username_input: LineEdit
@onready var password_input: LineEdit
@onready var password_confirm_input: LineEdit
@onready var register_button: Button
@onready var back_button: Button
@onready var status_label: Label


# --- ВСТРОЕННЫЕ ФУНКЦИИ GODOT ---

func _ready() -> void:
	# Проверяем, что все узлы на месте, согласно контракту.
	if not _validate_scene_contract():
		set_process(false) # Отключаем сцену, если контракт нарушен.
		return
	
	# Подключаем обработчики к кнопкам.
	register_button.pressed.connect(_on_register_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

# Обработка горячих клавиш
func _input(event: InputEvent) -> void:
	# Enter для основного действия
	if event.is_action_pressed("ui_accept"):
		_on_register_button_pressed()
		get_viewport().set_input_as_handled()
	# Escape для возврата назад
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

## --- ПУБЛИЧНЫЕ МЕТОДЫ (Контракт: Main -> Сцена) ---

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func set_busy(is_busy: bool) -> void:
	# Блокируем/разблокируем все интерактивные элементы.
	email_input.editable = not is_busy
	username_input.editable = not is_busy
	password_input.editable = not is_busy
	password_confirm_input.editable = not is_busy
	register_button.disabled = is_busy
	back_button.disabled = is_busy

func show_error(text: String) -> void:
	if status_label:
		status_label.text = "[color=red]" + text + "[/color]"


## --- ВНУТРЕННИЕ ФУНКЦИИ ---

# Вызывается при нажатии на кнопку "Зарегистрироваться".
func _on_register_button_pressed() -> void:
	# Сбрасываем статус перед новой попыткой.
	set_status("")
	
	# Собираем данные.
	var email = email_input.text.strip_edges()
	var username = username_input.text.strip_edges()
	var password = password_input.text
	var password_confirm = password_confirm_input.text
	
	# --- ИСПРАВЛЕННЫЙ КОД ДЛЯ ПРОВЕРКИ EMAIL ---
	# 1. Создаем объект RegEx.
	var email_regex = RegEx.new()
	# 2. Компилируем шаблон для поиска email. Этот шаблон — стандартный для email.
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	# 3. Ищем совпадение. Если совпадений нет, search() вернет null.
	if email_regex.search(email) == null:
		show_error("Please enter a valid email address.")
		return
	# --- КОНЕЦ ИСПРАВЛЕНИЯ ---

	if username.length() < 3:
		show_error("Username must be at least 3 characters long.")
		return
	if password.length() < 8:
		show_error("Password must be at least 8 characters long.")
		return
	if password != password_confirm:
		show_error("Passwords do not match.")
		return
		
	# Если все проверки пройдены, испускаем сигнал наверх.
	request_register.emit(email, username, password)

# Вызывается при нажатии на кнопку "Назад".
func _on_back_button_pressed() -> void:
	request_back.emit()


## --- ПРОВЕРКА КОНТРАКТА ---
func _validate_scene_contract() -> bool:
	var required_nodes = {
		"email_input": "g_email_input",
		"username_input": "g_username_input",
		"password_input": "g_password_input",
		"password_confirm_input": "g_password_confirm_input",
		"register_button": "g_register_button",
		"back_button": "g_back_button",
		"status_label": "g_status_label",
	}
	
	for var_name in required_nodes:
		var group_name = required_nodes[var_name]
		var node = get_tree().get_first_node_in_group(group_name)
		if node:
			set(var_name, node)
		else:
			Log.error("Scene contract validation failed for Register.tscn! Node with group '%s' not found." % group_name)
			return false
			
	Log.info("Scene contract for Register.tscn validated successfully.")
	return true
