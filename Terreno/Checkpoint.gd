extends Area3D

@export var punto_de_aparicion: Marker3D
@export var puerta: Door
@export var animacion_momo: AnimationPlayer      # opcional: arrastralo cuando lo tengas
@export var nombre_animacion_momo: String = "intro"
@export var duracion_provisoria: float = 3.0     # lo que dura la cinemática mientras no hay animación

var puerta_cerrada := false
var _jugadores_dentro: Array[Node3D] = []


func _soy_host() -> bool:
	return Global.modo_multijugador != "linea" or multiplayer.is_server()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
	
	# Cada jugador que entra guarda su propio respawn
	if punto_de_aparicion:
		body.punto_respawn = punto_de_aparicion.global_position
	
	if not _jugadores_dentro.has(body):
		_jugadores_dentro.append(body)
	
	_revisar_puerta()


func _on_body_exited(body: Node3D) -> void:
	if puerta_cerrada:
		return
	_jugadores_dentro.erase(body)


func _revisar_puerta() -> void:
	if puerta_cerrada or not _soy_host():
		return
	_jugadores_dentro = _jugadores_dentro.filter(func(j): return is_instance_valid(j))
	var total := get_tree().get_nodes_in_group("Jugador").size()
	if total >= 2 and _jugadores_dentro.size() >= total:
		if Global.modo_multijugador == "linea":
			_cerrar_puerta.rpc()
		else:
			_cerrar_puerta()


@rpc("authority", "call_local", "reliable")
func _cerrar_puerta() -> void:
	if puerta_cerrada:
		return
	puerta_cerrada = true
	if puerta:
		puerta.cerrar_puerta()
@rpc("call_local", "any_peer", "reliable")
func reproducir_cinematica() -> void:
	# 1. Bloquea los controles de todos
	get_tree().call_group("Jugador", "bloquear_controles", true)
	
	# 2. Teletransporta a los dos al marker
	if punto_de_aparicion:
		var jugadores := get_tree().get_nodes_in_group("Jugador")
		for i in range(jugadores.size()):
			jugadores[i].global_position = punto_de_aparicion.global_position + Vector3(i * 1.5, 0, 0)
	
	# 3. Cinemática: animación de Momo > video > espera provisoria
	if animacion_momo and animacion_momo.has_animation(nombre_animacion_momo):
		animacion_momo.play(nombre_animacion_momo)
		await animacion_momo.animation_finished
	elif video_player and video_player.stream:
		video_player.visible = true
		video_player.play()
		await video_player.finished
		video_player.visible = false
	else:
		await get_tree().create_timer(duracion_provisoria).timeout
	
	# 4. Fin de la cinemática
	GameManager.papas_atacan = true
	get_tree().call_group("Jugador", "bloquear_controles", false)
