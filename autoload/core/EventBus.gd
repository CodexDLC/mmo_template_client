# res://autoload/EventBus.gd
extends Node

# Сигнал после успешного подключения и аутентификации на WS
@warning_ignore("unused_signal")
signal net_authenticated(connection_id)

# Сигнал при разрыве WS соединения
@warning_ignore("unused_signal")
signal net_disconnected(reason)

# Сигнал о получении события от сервера
@warning_ignore("unused_signal")
signal net_event(topic, body, request_id)

# Сигнал об ошибке от сетевого слоя
@warning_ignore("unused_signal")
signal net_error(code, details)
