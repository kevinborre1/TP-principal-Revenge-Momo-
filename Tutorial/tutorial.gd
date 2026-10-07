extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")

func _ready() -> void:
	# Como es cooperativo en línea, solo el servidor spawnea a los jugadores
	if Global.modo_multijugador == "linea":
		if not multiplayer.is_server():
			return

		add_player(1) # Spawnea al Host
		
		# Conectar señales para cuando se una el cliente
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(_disconnected_player)

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id) 
	
	# La posición inicial se definirá desde el script del Player o puedes setearla aquí
	add_child(new_player)
	
func _disconnected_player(peer_id: int) -> void:
	var player_deleted = get_node_or_null(str(peer_id))
	if player_deleted:
		player_deleted.queue_free()
