extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")

func _ready() -> void:
	# Solo el host ejecuta la logica de creacion
	if not multiplayer.is_server():
		return

	# El host crea su personaje
	add_player(1)
	
	# El host escucha cuando se unen y desconectan los clientes
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(_disconnected_player)

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	
	if peer_id == 1:
		new_player.position = Vector3(2,5,0)
	else:
		new_player.position = Vector3(-2,5,0)
	
	# Lo a;adimos como hijo directo del mundo
	add_child(new_player)

func _disconnected_player(peer_id: int) -> void:
	var player_deleted = get_node_or_null(str(peer_id))
	if player_deleted:
		player_deleted.queue_free()
