# res://ui/session/start/start.gd
extends Control

## --- СИГНАЛЫ (Контракт: Сцена -> Main) ---
# Сигналы — это способ, которым этот узел сообщает внешнему миру (в нашем случае Main.gd),
# что произошло какое-то важное событие. Main.gd подпишется на эти сигналы.

# Сигнал срабатывает, когда пользователь нажимает кнопку "Войти".
# Он передает введенные имя пользователя и пароль.
signal request_login(username, password)

# Сигнал для перехода на экран регистрации.
signal request_open_register

# Сигнал для перехода на экран отладки (Playground).
signal request_open_debug

# @onready означает, что переменная будет заполнена прямо перед вызовом _ready(),
# когда дерево сцены уже полностью готово.

@onready var username_input: LineEdit
@onready var password_input: LineEdit
@onready var login_button: Button
@onready var register_button: Button
@onready var debug_button: Button
@onready var status_label: RichTextLabel 
@onready var toggle_password_button: CheckBox


# --- ВСТРОЕННЫЕ ФУНКЦИИ GODOT ---

# _ready() вызывается один раз при создании узла.
# Идеальное место для первоначальной настройки.
func _ready() -> void:
	# Шаг 1: Проверяем контракт — убеждаемся, что все нужные узлы существуют.
	# Эта функция (мы напишем её ниже) вернет true, если все на месте.
	if not _validate_scene_contract():
		# Если проверка провалилась, дальнейшая работа невозможна.
		# Мы отключаем всю сцену, чтобы избежать вылетов игры.
		set_process(false)
		set_physics_process(false)
		return

	# Шаг 2: Подключаем сигналы от кнопок к нашим функциям-обработчикам.
	# Когда сигнал "pressed" у кнопки login_button сработает,
	# будет вызвана наша функция _on_login_button_pressed.
	login_button.pressed.connect(_on_login_button_pressed)
	register_button.pressed.connect(_on_register_button_pressed)
	debug_button.pressed.connect(_on_debug_button_pressed)
	toggle_password_button.toggled.connect(_on_toggle_password)

# _input() вызывается каждый раз, когда происходит любое действие ввода (клавиша, мышь).
func _input(event: InputEvent) -> void:
	# Проверяем, было ли нажато действие "ui_accept" (обычно это клавиша Enter).
	if event.is_action_pressed("ui_accept"):
		# Если да, то имитируем нажатие на кнопку входа.
		_on_login_button_pressed()
		# "Съедаем" событие, чтобы оно не обрабатывалось дальше.
		get_viewport().set_input_as_handled()


## --- ПУБЛИЧНЫЕ МЕТОДЫ (Контракт: Main -> Сцена) ---
# Эти функции может вызывать внешний код (наш Main.gd), чтобы управлять состоянием этого экрана.

# Устанавливает текст в статус-лейбле.
func set_status(text: String) -> void:
	if status_label:
		status_label.clear()
		status_label.append_text(text)


# Блокирует или разблокирует интерактивные элементы на время занятости (например, во время запроса).
func set_busy(is_busy: bool) -> void:
	if username_input: username_input.editable = not is_busy
	if password_input: password_input.editable = not is_busy
	if login_button: login_button.disabled = is_busy
	if register_button: register_button.disabled = is_busy
	if debug_button: debug_button.disabled = is_busy

# Показывает ошибку. В нашем случае просто выводит её в статус красным цветом.
# В будущем можно будет подключить более красивое окно ошибки.
func show_error(text: String) -> void:
	if status_label:
		# У RichTextLabel эти теги добавлять в код не нужно,
		# так как мы используем методы push_color/pop
		status_label.clear()
		status_label.push_color(Color.RED)
		status_label.append_text(text)
		status_label.pop()


## --- ВНУТРЕННИЕ ФУНКЦИИ (Обработчики сигналов кнопок) ---

# Вызывается при нажатии на кнопку входа.
func _on_login_button_pressed() -> void:
	# ИСПРАВЛЕНИЕ: Убедитесь, что эта строка присутствует.
	set_status("") # Сбрасываем статус перед новой попыткой.

	var username := username_input.text.strip_edges()
	var password := password_input.text

	if username.is_empty() or password.is_empty():
		show_error("Username and password cannot be empty.")
		return

	request_login.emit(username, password)

# Вызывается при нажатии на кнопку регистрации.
func _on_register_button_pressed() -> void:
	# Просто сообщаем наверх о желании пользователя.
	request_open_register.emit()

# Вызывается при нажатии на кнопку отладки.
func _on_debug_button_pressed() -> void:
	request_open_debug.emit()

func _on_toggle_password(is_button_pressed: bool) -> void:
	if password_input:
		# У LineEdit есть свойство `secret`, которое превращает текст в точки.
		# Если галочка стоит (is_button_pressed = true), мы отключаем секретность.
		# Если галочки нет (is_button_pressed = false), мы включаем секретность.
		password_input.secret = not is_button_pressed
		

## --- ПРОВЕРКА КОНТРАКТА ---

# Эта функция — наша "страховка". Она проверяет, что художник или дизайнер,
# который делал сцену, не забыл проставить все необходимые группы.
func _validate_scene_contract() -> bool:
	# Мы создаем словарь, где ключ - это имя переменной,
	# а значение - это имя группы, которую мы ожидаем найти.
	var required_nodes = {
		"username_input": "g_username_input",
		"password_input": "g_password_input",
		"login_button": "g_login_button",
		"register_button": "g_register_button",
		"debug_button": "g_debug_button",
		"status_label": "g_status_label",
		"toggle_password_button": "g_toggle_password_button",
	}

	# Проходимся по словарю.
	for var_name in required_nodes:
		var group_name = required_nodes[var_name]
		var node = get_tree().get_first_node_in_group(group_name)
		if node:
			set(var_name, node)
		else:
			Log.error("Scene contract validation failed! Group '%s' not found." % group_name)
			return false
			
	Log.info("Scene contract for Start.tscn validated successfully.")
	return true
