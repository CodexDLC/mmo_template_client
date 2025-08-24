# Документация по API аутентификации (клиент)

## Обзор

Клиент взаимодействует с сервером по двум протоколам для аутентификации:
1.  **HTTP API** для входа, регистрации и обновления токенов.
2.  **WebSocket** для подключения к игровому серверу после получения токена.

---

### 1. HTTP API (Аутентификация)

Все HTTP-запросы отправляются методом `POST` с заголовком `Content-Type: application/json`.

#### A. Регистрация нового пользователя

* **Endpoint**: `POST {http_url}/auth/register`
* **Назначение**: Создание новой учетной записи.

* **Отправляемый JSON (Запрос)**:
	```json
	{
	  "email": "user@example.com",
	  "username": "my_username",
	  "password": "my_secure_password"
	}
	```
	* `email`: string. Валидный адрес электронной почты.
	* `username`: string. Минимум 3 символа.
	* `password`: string. Минимум 8 символов.

* **Ожидаемый JSON (Успешный ответ)**:
	* Код состояния: `200 OK`
	```json
	{
	  "success": true,
	  "data": {
		"account_id": 12345,
		"email": "user@example.com",
		"username": "my_username"
	  }
	}
	```
* **Ожидаемый JSON (Ответ с ошибкой)**:
	* Код состояния: `409 Conflict` (если пользователь уже существует) или `400 Bad Request` (если неверные данные).
	```json
	{
	  "success": false,
	  "detail": "User with this username or email already exists."
	}
	```

#### B. Вход пользователя

* **Endpoint**: `POST {http_url}/auth/login`
* **Назначение**: Вход в систему и получение токенов сессии.

* **Отправляемый JSON (Запрос)**:
	```json
	{
	  "username": "my_username",
	  "password": "my_secure_password"
	}
	```
* **Ожидаемый JSON (Успешный ответ)**:
	* Код состояния: `200 OK`
	```json
	{
	  "success": true,
	  "data": {
		"token": "JWT_access_token_goes_here",
		"refresh_token": "refresh_token_string_goes_here",
		"expires_in": 3600
	  }
	}
	```
	* `token`: string. Токен доступа (Access Token).
	* `refresh_token`: string. Токен обновления (Refresh Token).
	* `expires_in`: int. Срок действия токена доступа в секундах.
* **Ожидаемый JSON (Ответ с ошибкой)**:
	* Код состояния: `401 Unauthorized`.
	```json
	{
	  "success": false,
	  "detail": "Invalid username or password."
	}
	```

#### C. Обновление токена

* **Endpoint**: `POST {http_url}/auth/refresh`
* **Назначение**: Автоматическое обновление токена доступа.

* **Отправляемый JSON (Запрос)**:
	```json
	{
	  "refresh_token": "refresh_token_string_goes_here"
	}
	```
* **Ожидаемый JSON (Успешный ответ)**:
	* Код состояния: `200 OK`
	* Ответ идентичен успешному ответу на запрос входа.
* **Ожидаемый JSON (Ответ с ошибкой)**:
	* Код состояния: `401 Unauthorized`.
	```json
	{
	  "success": false,
	  "detail": "Refresh token is invalid or has expired."
	}
	```
---

### 2. WebSocket API

После успешного входа клиент устанавливает соединение с WebSocket-сервером.

#### A. Подключение

* **URL**: `ws://{ws_url}/v1/connect`
* **Аутентификация**: Клиент должен отправить заголовок `Authorization: Bearer <access_token>` или использовать параметр запроса `token=<access_token>`.

#### B. Сообщение от сервера (HELLO Frame)

* **Назначение**: Сервер отправляет это сообщение после успешной аутентификации WebSocket-соединения.
* **Ожидаемый JSON**:
	```json
	{
	  "type": "hello",
	  "v": 1,
	  "connection_id": "unique_connection_id",
	  "heartbeat_sec": 30
	}
	```
	* `connection_id`: string. Уникальный ID, присвоенный вашему WS-соединению.
	* `heartbeat_sec`: int. Интервал в секундах для отправки ping-сообщений.

#### C. Отправка команд на сервер

* **Назначение**: Клиент отправляет команды в формате JSON.
* **Пример JSON-запроса (Команда `ping`)**:
	```json
	{
	  "type": "command",
	  "v": 1,
	  "request_id": "req_a1b2c3d4e5f6...",
	  "domain": "system",
	  "command": "ping",
	  "payload": {
		"sent_at": 1735689600
	  }
	}
	```
	* `request_id`: string. Уникальный идентификатор запроса (UUID).
	* `domain`: string. Домен команды (например, `system`, `game`, `chat`).
	* `command`: string. Название команды.
	* `payload`: dictionary. Данные, специфичные для команды.
