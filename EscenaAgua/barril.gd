extends StaticBody3D

func _ready() -> void:
	# Añadimos todos los barriles al grupo para que la balsa los reconozca
	add_to_group("Barriles")

@rpc("any_peer", "call_local", "reliable")
func _daniar(danio: int) -> void:
	print("¡El barril recibió un disparo!")
	SaveAndLoad.sumar_estadistica("barrilesRotos")
	_destruir_barril()

# Esta es la función que llama la balsa al chocar
func _colision_balsa() -> void:
	print("¡Un barril fue chocado por la balsa!")
	# Si estás en multijugador online, le avisa a todos que se destruya
	if Global.modo_multijugador == "linea":
		rpc("_destruir_barril")
	else:
		_destruir_barril()

@rpc("any_peer", "call_local", "reliable")
func _destruir_barril() -> void:
	if get_parent() and get_parent().name != "Terreno" and get_parent().name != "SceneRoot":
		# Solo borramos el padre si es el nodo contenedor del barril visual (ej: Sketchfab_Scene)
		get_parent().queue_free()
	else:
		queue_free()
