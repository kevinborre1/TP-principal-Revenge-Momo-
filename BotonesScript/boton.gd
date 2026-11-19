extends Area3D

signal activado
@export var id_boton: int = 2 # Pon 1 para el primer botón y 2 para el segundo
@export var puerta_destino: Node3D # Arrastra la puerta aquí desde el Inspector

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, true)
		activado.emit() # Un nivel afuera: se emite siempre que un Jugador pisa el botón

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		var sigue_alguien := get_overlapping_bodies().any(func(b): return b != body and b.is_in_group("Jugador"))
		if not sigue_alguien and puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, false)
