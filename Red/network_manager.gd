extends Node3D

signal host_cerro_partida

@onready var tube_client: TubeClient = $TubeClient

func _ready() -> void:
	# el host escucha cuando un cliente se va
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# el cliente escucha cuando el host se va
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
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
