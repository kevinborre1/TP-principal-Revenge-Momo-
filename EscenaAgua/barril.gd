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
	# 1. Apagamos la colisión. Usamos set_deferred por seguridad en las físicas de Godot.
	$CollisionShape3D.set_deferred("disabled", true)
	
	# 2. Apagamos el modelo visual (el padre Sketchfab_Sce)
	var nodo_padre = get_parent()
	if nodo_padre:
		nodo_padre.visible = false
		
	# 3. Pausamos la ejecución de esta función por 6 segundos sin congelar el juego
	await get_tree().create_timer(6.0).timeout
	
	# 4. Reactivamos la colisión y la visibilidad
	$CollisionShape3D.set_deferred("disabled", false)
	if nodo_padre:
		nodo_padre.visible = true

@rpc("any_peer", "call_local", "reliable")
func _destruir_barril() -> void:
	if get_parent() and get_parent().name != "Terreno" and get_parent().name != "SceneRoot":
		# Solo borramos el padre si es el nodo contenedor del barril visual (ej: Sketchfab_Scene)
		get_parent().queue_free()
	else:
		queue_free()
