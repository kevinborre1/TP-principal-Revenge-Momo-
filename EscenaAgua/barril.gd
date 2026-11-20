extends StaticBody3D

var _destruido: bool = false
#sonidos
const SFX_BARRIL_CRASH = preload("res://sonidos/barril_crash.wav")


func _ready() -> void:
	# Añadimos todos los barriles al grupo para que la balsa los reconozca
	add_to_group("BarrilesMapa")
	add_to_group("Barriles")

@rpc("any_peer", "call_local", "reliable")
func _daniar(danio: int) -> void:
	if _destruido:
		return
	print("¡El barril recibió un disparo!")
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0 or sender_id == multiplayer.get_unique_id():
		SaveAndLoad.sumar_estadistica("barrilesRotos")
	
	# 2. Propagamos la destrucción a TODOS los jugadores por red
	if Global.modo_multijugador == "linea" and sender_id == 0:
		_destruir_barril.rpc()
	else:
		_destruir_barril()

# Esta es la función que llama la balsa al chocar
@rpc("any_peer", "call_local", "reliable")
func _colision_balsa() -> void:
	if Global.modo_multijugador == "linea":
		_sincronizar_colision_balsa.rpc()
	else:
		_sincronizar_colision_balsa()

@rpc("any_peer", "call_local", "reliable")
func _sincronizar_colision_balsa() -> void:
	print("¡Un barril fue chocado por la balsa!")
	# 1. Apagamos la colisión. Usamos set_deferred por seguridad en las físicas de Godot.
	$CollisionShape3D.set_deferred("disabled", true)
	
	reproducir_sfx_3d(SFX_BARRIL_CRASH)
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
	if _destruido:
		return
	_destruido = true
	
	reproducir_sfx_3d(SFX_BARRIL_CRASH)
	
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

# Sonidos en 3D independientes del nodo del barril para que no se corten al destruirse
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
		
	var escena_actual := get_tree().current_scene
	if escena_actual:
		escena_actual.add_child(player_3d)
	else:
		add_child(player_3d)
		
	player_3d.global_position = global_position
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
