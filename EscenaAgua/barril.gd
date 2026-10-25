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
@rpc("any_peer", "call_local", "reliable")
func _colision_balsa() -> void:
	print("¡Un barril fue chocado por la balsa!")
	# 1. Apagamos la colisión. Usamos set_deferred por seguridad en las físicas de Godot.
	$CollisionShape3D.set_deferred("disabled", true)
	
	# 2. Apagamos el modelo visual (el padre Sketchfab_Scene)
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
	# 1. Desactivamos la colisión para que no choque mientras se encoge
	$CollisionShape3D.set_deferred("disabled", true)

	# 2. Animar la escala hasta achicarse a 0 en 0.15 segundos
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	
	# 3. Esperar a que termine la animación del Tween
	await tween.finished

	# 4. Eliminar el nodo contenedor o el barril
	if get_parent() and get_parent().name != "Terreno" and get_parent().name != "SceneRoot":
		get_parent().queue_free()
	else:
		queue_free()
