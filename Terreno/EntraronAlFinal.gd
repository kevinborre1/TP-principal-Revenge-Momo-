extends Area3D

signal ambos_pasaron
signal tiempo_agotado

@export var tiempo_limite := 5.0

var pasaron := {}
var timer: Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = tiempo_limite
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("jugadores"):
		return
	if pasaron.has(body):
		return
	pasaron[body] = true

	if pasaron.size() == 1:
		timer.start()  # pasó el primero: empieza la cuenta
	elif pasaron.size() >= 2:
		timer.stop()   # pasó el segundo a tiempo: se cancela
		ambos_pasaron.emit()
		set_deferred("monitoring", false)

func _on_timer_timeout() -> void:
	tiempo_agotado.emit()

func reiniciar() -> void:
	timer.stop()
	pasaron.clear()
	set_deferred("monitoring", true)
