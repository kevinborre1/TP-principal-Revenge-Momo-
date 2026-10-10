extends Node

@export var rutaUtilizada = ""

func save_game() -> void:
	print("Guardando en: ", rutaUtilizada)
	# Solo el Host/Servidor ejecuta y guarda en su PC
	if not multiplayer.is_server():
		return
		
	var data = SaveData.new()
	data.escena_actual = get_tree().current_scene.scene_file_path
	
	# Buscamos a TODOS los jugadores que el MultiplayerSpawner instanció en la escena
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	
	for jugador in jugadores:
		# Identificamos quién es el Host (ID = 1) y quién el Cliente
		if jugador.get_multiplayer_authority() == 1:
			data.pos_host = jugador.global_position
		else:
			data.pos_cliente = jugador.global_position

	# Guardamos el recurso en la PC del Host usando ResourceSaver (como en el video)
	var err = ResourceSaver.save(data, rutaUtilizada)
	if err == OK:
		print("Servidor: Partida guardada correctamente con los datos de ambos jugadores.")
	else:
		print("Error al guardar: ", err)


func load_game() -> void:
	print("Guardando en: ", rutaUtilizada)
	if not multiplayer.is_server():
		return
		
	if not ResourceLoader.exists(rutaUtilizada):
		print("No existe ningún archivo de guardado.")
		return
		
	var data = ResourceLoader.load(rutaUtilizada) as SaveData
	if data == null:
		return
		
	# Buscamos a los jugadores spawneados y les reasignamos la posición guardada
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		if jugador.get_multiplayer_authority() == 1:
			jugador.global_position = data.pos_host
		else:
			# Si nunca se guardó al cliente, aparece al lado del host
			var destino = data.pos_cliente
			if destino == Vector3.ZERO:
				destino = data.pos_host + Vector3(2, 0, 0)
			
			if Global.modo_multijugador == "linea":
				jugador.mover_a.rpc_id(jugador.get_multiplayer_authority(), destino)
			else:
				jugador.global_position = destino
	print("Servidor: Partida cargada y posiciones aplicadas.")
