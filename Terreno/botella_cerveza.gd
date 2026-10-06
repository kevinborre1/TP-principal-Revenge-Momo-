extends Area3D

@export var textura_icono: Texture2D
@export var nombre_item: String = "Botella de Cerveza"

func _on_body_entered(body: Node3D) -> void:
	# Verificamos si el que tocó la botella es el jugador
	if body.is_in_group("Jugador") and body.has_method("recolectar_item"):
		
		# Intentamos guardar la botella en el inventario
		var exito = body.recolectar_item(nombre_item, textura_icono)
		
		# Si hubo espacio y se recogió con éxito, eliminamos la botella del mundo 3D
		if exito:
			queue_free()


func _on_body_exited(body: Node3D) -> void:
	pass # Replace with function body.
