extends Node3D

signal host_cerro_partida
signal escena_distinta_del_host(ruta: String)

var quiero_ser_host: bool = false
var codigo_para_unirse: String = ""
var mensaje_error_conexion: String = ""
var escena_menu_en_linea: String = ""

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
	var active_players = get_tree().get_nodes_in_group("jugadores")
	
	for player in active_players:
		if player.name == str(id):
			player.queue_free()
			break
			
# cliente
func _on_server_disconnected() -> void:
	disconnect_game()
	host_cerro_partida.emit()

# logica global 
func disconnect_game() -> void:
	if is_instance_valid(tube_client) and tube_client.state != TubeClient.State.IDLE:
		tube_client.leave_session()
