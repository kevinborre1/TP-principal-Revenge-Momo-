extends Area3D

@export var id_boton: int = 1
@export var puerta_destino: Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:

	if body.is_in_group("Jugador"):

		print("Jugador pisó el botón")

		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, true)


func _on_body_exited(body: Node3D) -> void:

	if body.is_in_group("Jugador"):

		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, false)
