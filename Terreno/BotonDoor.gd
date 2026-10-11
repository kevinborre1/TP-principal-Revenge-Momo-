extends Area3D

@export var id_boton: int = 1
@export var puerta_destino: Node # Asigná la puerta desde el Inspector

var jugador_cerca: bool = false
var esta_activado: bool = false

func _ready() -> void:
	add_to_group("BotonesPuerta")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and event.is_action_pressed("interactuar"):
		presionar_boton()

func presionar_boton() -> void:
	esta_activado = !esta_activado
	if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
		puerta_destino.actualizar_estado_boton(id_boton, esta_activado)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		jugador_cerca = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		jugador_cerca = false
