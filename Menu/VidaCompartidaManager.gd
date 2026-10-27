extends Node
class_name VidaCompartidaManager

var corazones_maximos: int = 1
var corazones_actuales: int = 1
var procesando_muerte: bool = false # Evita que se resten 2 vidas si mueren a la vez

var salud_maxima: int = 100
var salud_compartida: int = 100

signal corazones_actualizados(cantidad)

func iniciar_modo() -> void:
	corazones_actuales = corazones_maximos
	salud_compartida = salud_maxima
	if Global.modo_multijugador == "linea" and multiplayer.is_server():
		_sincronizar_corazones.rpc(corazones_actuales, Global.modo_de_juego)
		_sincronizar_salud.rpc(salud_compartida)

# --- SINCRONIZACIÓN DE RED ---
@rpc("any_peer", "call_remote", "reliable")
func _pedir_estado_al_host() -> void:
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		_sincronizar_corazones.rpc_id(peer_id, corazones_actuales, Global.modo_de_juego)
		_sincronizar_salud.rpc_id(peer_id, salud_compartida)

@rpc("authority", "call_local", "reliable")
func _sincronizar_corazones(corazones: int, modo: String) -> void:
	corazones_actuales = corazones
	Global.modo_de_juego = modo # Ahora el Cliente sabe a qué está jugando
	corazones_actualizados.emit(corazones_actuales)
	
func cambiar_salud_compartida(cantidad: int) -> void:
	if multiplayer.is_server():
		_servidor_cambiar_salud(cantidad)
	else:
		_servidor_cambiar_salud.rpc_id(1, cantidad)

@rpc("any_peer", "call_remote", "reliable")
func _servidor_cambiar_salud(cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	if procesando_muerte:
		return
	
	salud_compartida = clampi(salud_compartida + cantidad, 0, salud_maxima)
	print("[VidaCompartida] Cambio de salud ", cantidad, " -> ", salud_compartida)
	_sincronizar_salud.rpc(salud_compartida)
	
	if salud_compartida <= 0:
		_servidor_procesar_muerte()
		
@rpc("authority", "call_local", "reliable")
func _sincronizar_salud(salud: int) -> void:
	salud_compartida = salud
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		if "saludActual" in jugador:
			jugador.saludActual = salud
			jugador.actualizar_barraDeVida()
	if not multiplayer.is_server():
		print("[VidaCompartida] Salud recibida del host: ", salud)

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
