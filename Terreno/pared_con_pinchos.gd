extends Node3D

signal jugadores_muertos  # solo se emite en el servidor

@export var entraron: Area3D
@export var velocidad := 3.0
@export var destino: Marker3D

var posicion_inicial: Vector3
var activa := false

func _ready() -> void:
	posicion_inicial = global_position
	# La detección solo corre en el servidor
	if multiplayer.is_server():
		entraron.body_entered.connect(_on_area_muerte_body_entered)
		entraron.ambos_pasaron.connect(_servidor_activar)
		entraron.tiempo_agotado.connect(_fallar)
	else:
		entraron.set_deferred("monitoring", false)
		entraron.set_deferred("monitoring", false)

func _servidor_activar() -> void:
	activar.rpc()

@rpc("authority", "call_local", "reliable")
func activar() -> void:
	activa = true

@rpc("authority", "call_local", "reliable")
func reiniciar() -> void:
	activa = false
	global_position = posicion_inicial

func _physics_process(delta: float) -> void:
	if not activa:
		return
	global_position = global_position.move_toward(destino.global_position, velocidad * delta)
	if global_position.is_equal_approx(destino.global_position):
		activa = false

func _on_area_muerte_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores"):
		_fallar()

func _fallar() -> void:
	reiniciar.rpc()        # todos los peers vuelven la pared al inicio
	entraron.reiniciar()   # la zona solo importa en el servidor
	jugadores_muertos.emit()
