extends Node3D

signal host_cerro_partida
signal escena_distinta_del_host(ruta: String)

# Escenas donde se juega en línea (un cliente puede seguir al host hasta ellas)
const ESCENAS_ONLINE := [
	"res://Tutorial/Tutorial.tscn",
	"res://Terreno/terreno.tscn",
]

const ESCENA_VIDEO := "res://videos/apertura.tscn"
const ESCENAS_TRANSICION := [ESCENA_VIDEO]   # escenas de paso, sin red

var quiero_ser_host: bool = false
var codigo_para_unirse: String = ""
var mensaje_error_conexion: String = ""
var escena_menu_en_linea: String = ""
var _siguiendo_al_host: bool = false   # NUEVO

@onready var tube_client: TubeClient = $TubeClient

func _ready() -> void:
	# el host escucha cuando un cliente se va
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# el cliente escucha cuando el host se va
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# el host le avisa al cliente que escena tiene cargada
	multiplayer.peer_connected.connect(_on_peer_connected)
	
func red_conectada() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# host
func _on_peer_connected(id: int) -> void:
	if Global.modo_multijugador != "linea" or not multiplayer.is_server():
		return
	if get_tree().current_scene == null:
		return
	var ruta := get_tree().current_scene.scene_file_path
	print("[Red] Cliente ", id, " conectado. Escena del host: ", ruta)
	rpc_id(id, "rpc_escena_del_host", ruta)

# cliente
@rpc("authority", "call_remote", "reliable")
func rpc_escena_del_host(ruta: String) -> void:
	if get_tree().current_scene == null:
		return
	var actual := get_tree().current_scene.scene_file_path
	print("[Red] Escena del host: ", ruta, " | escena local: ", actual)
	if _ruta_normalizada(ruta) != _ruta_normalizada(actual):
		escena_distinta_del_host.emit(ruta)

func _ruta_normalizada(ruta: String) -> String:
	if ruta.begins_with("uid://"):
		return ResourceUID.get_id_path(ResourceUID.text_to_id(ruta))
	return ruta

func notify_disconnection() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			rpc("rpc_host_shutting_down") 
		else:
			rpc_id(1, "rpc_client_leaving", multiplayer.get_unique_id())

@rpc("any_peer", "call_remote", "reliable")
func rpc_client_leaving(id: int) -> void:
	if multiplayer.is_server():
		_on_peer_disconnected(id)

@rpc("authority", "call_remote", "reliable")
func rpc_host_shutting_down() -> void:
	_on_server_disconnected()

# host 
func _on_peer_disconnected(id: int) -> void:
	# si se fue el compañero, el host vuelve a abrir la sala
	if is_instance_valid(tube_client) and tube_client.is_server:
		tube_client.refuse_new_connections = false
		
	var active_players = get_tree().get_nodes_in_group("jugadores")
	
	for player in active_players:
		if player.name == str(id):
			player.queue_free()
			break
			
# cliente
func _on_server_disconnected() -> void:
	disconnect_game()
	if _siguiendo_al_host:   # Nos fuimos nosotros a propósito, no cerró el host
		return
	host_cerro_partida.emit()

# logica global 
func disconnect_game() -> void:
	if is_instance_valid(tube_client) and tube_client.state != TubeClient.State.IDLE:
		tube_client.leave_session()

func sesion_host_activa() -> bool:
	return is_instance_valid(tube_client) and tube_client.is_server \
			and tube_client.state != TubeClient.State.IDLE

func puede_seguir_al_host(ruta: String) -> bool:
	return _ruta_normalizada(ruta) in ESCENAS_ONLINE

# CLIENTE: se une a la sesión esperando a que la anterior termine de cerrarse
func unirse_a_sesion(codigo: String) -> void:
	var intentos := 0
	while tube_client.state != TubeClient.State.IDLE and intentos < 50:
		await get_tree().create_timer(0.1).timeout
		intentos += 1
	tube_client.join_session(codigo)

# CLIENTE: nos vamos a la escena del host y nos conectamos de nuevo desde ahí,
# así el MultiplayerSpawner del host nos manda a los jugadores que ya existen
func seguir_al_host(ruta: String) -> void:
	print("[Red] Siguiendo al host a: ", ruta)
	_siguiendo_al_host = true
	get_tree().create_timer(3.0).timeout.connect(func(): _siguiendo_al_host = false)
	disconnect_game()
	get_tree().change_scene_to_file(ruta)

# HOST: lleva a todos los jugadores a otra escena
func host_cambia_escena(ruta: String) -> void:
	if sesion_host_activa() and not multiplayer.get_peers().is_empty():
		rpc("rpc_host_cambio_escena", ruta)
	get_tree().change_scene_to_file(ruta)

# CLIENTE
@rpc("authority", "call_remote", "reliable")
func rpc_host_cambio_escena(ruta: String) -> void:
	print("[Red] El host cambió a: ", ruta) 
	if puede_seguir_al_host(ruta) or es_escena_transicion(ruta):
		seguir_al_host(ruta)
		
func es_escena_transicion(ruta: String) -> bool:
	return _ruta_normalizada(ruta) in ESCENAS_TRANSICION

# CLIENTE: el host todavía está en una escena de paso (el video).
# Nos desconectamos y reintentamos en unos segundos
func reintentar_union(espera: float = 3.0) -> void:
	print("[Red] El host sigue en el video, reintento en ", espera, " s")
	_siguiendo_al_host = true
	disconnect_game()
	await get_tree().create_timer(espera).timeout
	_siguiendo_al_host = false
	unirse_a_sesion(codigo_para_unirse)
