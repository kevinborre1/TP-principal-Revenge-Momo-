extends Node
class_name VidaCompartidaManager

var corazones_maximos: int = 3
var corazones_actuales: int = 3
var procesando_muerte: bool = false # Evita que se resten 2 vidas si mueren a la vez

signal corazones_actualizados(cantidad)

func iniciar_modo() -> void:
	corazones_actuales = corazones_maximos
	if Global.modo_multijugador == "linea" and multiplayer.is_server():
		_sincronizar_corazones.rpc(corazones_actuales, Global.modo_de_juego)

# --- SINCRONIZACIÓN DE RED ---
@rpc("any_peer", "call_remote", "reliable")
func _pedir_estado_al_host() -> void:
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		_sincronizar_corazones.rpc_id(peer_id, corazones_actuales, Global.modo_de_juego)

@rpc("authority", "call_local", "reliable")
func _sincronizar_corazones(corazones: int, modo: String) -> void:
	corazones_actuales = corazones
	Global.modo_de_juego = modo # ¡ESTO FALTABA! Ahora el Cliente sabe a qué está jugando
	corazones_actualizados.emit(corazones_actuales)

# --- LÓGICA DE MUERTE COMPARTIDA ---
func procesar_muerte_jugador() -> void:
	if Global.modo_multijugador == "linea":
		# Sintaxis moderna y segura de Godot 4 para que el Cliente hable con el Host
		_servidor_procesar_muerte.rpc_id(1)
	else:
		_servidor_procesar_muerte()

@rpc("any_peer", "call_local", "reliable")
func _servidor_procesar_muerte() -> void:
	if not multiplayer.is_server() and Global.modo_multijugador == "linea":
		return
		
	# Si ya estamos procesando una muerte, ignoramos la otra por 2 segundos
	if procesando_muerte: return
	procesando_muerte = true
	
	corazones_actuales -= 1
	print("¡Un jugador murió! Corazones restantes: ", corazones_actuales)
	
	if corazones_actuales > 0:
		_ejecutar_respawn_compartido.rpc(corazones_actuales)
		# Esperamos a que revivan para poder volver a perder corazones
		await get_tree().create_timer(2.0).timeout
		procesando_muerte = false
	else:
		if multiplayer.is_server():
			SaveAndLoad.destruir_partida_y_limpiar()
		_ejecutar_game_over.rpc()

@rpc("call_local", "reliable")
func _ejecutar_respawn_compartido(corazones_restantes: int) -> void:
	corazones_actuales = corazones_restantes
	corazones_actualizados.emit(corazones_actuales)
	print("Respawn compartido para ambos. Corazones: ", corazones_actuales)
	
	# Buscamos a TODOS los jugadores y los obligamos a revivir
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	for jugador in jugadores:
		if jugador.has_method("respawnear"):
			jugador.saludActual = jugador.saludMax
			jugador.actualizar_barraDeVida()
			jugador.respawnear()

@rpc("call_local", "reliable")
func _ejecutar_game_over() -> void:
	Global.motivo_derrota = "se acabaron las vidas"
	print("¡Se acabaron los corazones compartidos! GAME OVER")
	get_tree().change_scene_to_file("res://Menu/derrota.tscn")
