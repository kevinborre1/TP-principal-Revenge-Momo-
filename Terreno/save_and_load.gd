extends Node

@export var rutaUtilizada: String = ""

func _ready() -> void:
	# Detecta automáticamente cuando el Cliente aparece en el árbol de escena (incluso si tarda en cargar)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not multiplayer.is_server():
		return
	# Esperamos un frame para que el nodo termine de configurar su nombre/autoridad y esté en el grupo "Jugador"
	await get_tree().process_frame
	if is_instance_valid(node) and node.is_in_group("Jugador"):
		# Si ya hay una partida cargada, ubicamos a este jugador recién conectado en su posición guardada
		posicionar_jugador_individual(node)

# Identifica si el nodo es el Host (ID 1) o el Cliente
func _es_jugador_host(jugador: Node) -> bool:
	if jugador.name == "1" or jugador.name == "Host":
		return true
	if jugador.name.is_valid_int() and jugador.name.to_int() != 1:
		return false
	return jugador.get_multiplayer_authority() == 1

func _obtener_todos_los_enemigos() -> Array[Node]:
	var lista: Array[Node] = []
	for e in get_tree().get_nodes_in_group("papitas"):
		if is_instance_valid(e) and not lista.has(e):
			lista.append(e)
	if get_tree().current_scene:
		var contenedor = get_tree().current_scene.find_child("Enemigos VictorBars", true, false)
		if contenedor:
			for hijo in contenedor.get_children():
				if hijo is CharacterBody3D and not lista.has(hijo):
					lista.append(hijo)
	return lista

func save_game() -> void:
	if not multiplayer.is_server():
		return
		
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	if jugadores.is_empty():
		return

	var data: SaveData
	if ResourceLoader.exists(rutaUtilizada):
		data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null:
		data = SaveData.new()
		
	data.escena_actual = get_tree().current_scene.scene_file_path
	
	# 1. Buscar al Host primero
	for jugador in jugadores:
		if _es_jugador_host(jugador):
			data.pos_host = jugador.global_position
			break
			
	# 2. Buscar al Cliente (si está jugando solo, queda a 2 metros del Host)
	data.pos_cliente = data.pos_host + Vector3(2, 0, 0)
	for jugador in jugadores:
		if not _es_jugador_host(jugador):
			data.pos_cliente = jugador.global_position
			break

	# 3. Guardar estado de enemigos
	data.papas_atacan = GameManager.papas_atacan
	data.estado_enemigos_guardado = true
	data.enemigos_vivos.clear()
	for enemigo in _obtener_todos_los_enemigos():
		if not enemigo.is_queued_for_deletion() and enemigo.vida_actual > 0:
			data.enemigos_vivos.append(str(enemigo.get_path()))

	var err = ResourceSaver.save(data, rutaUtilizada)
	if err == OK:
		print("Guardado exitoso -> Host: ", data.pos_host, " | Cliente: ", data.pos_cliente)

func load_game() -> void:
	if not multiplayer.is_server() or not ResourceLoader.exists(rutaUtilizada):
		return
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return
		
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		posicionar_jugador_individual(jugador, data)

	if data.estado_enemigos_guardado:
		_sincronizar_estado_enemigos.rpc(data.papas_atacan, data.enemigos_vivos)

func posicionar_jugador_individual(jugador: Node, data: SaveData = null) -> void:
	if not multiplayer.is_server() or rutaUtilizada == "" or not ResourceLoader.exists(rutaUtilizada):
		return
		
	if data == null:
		data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return
		
	# Verificamos que estemos en la escena guardada 
	if data.escena_actual != "" and get_tree().current_scene and data.escena_actual != get_tree().current_scene.scene_file_path:
		return

	var offset_altura = Vector3(0, 0.5, 0)
	var es_host = _es_jugador_host(jugador)
	var pos_cliente_base = data.pos_cliente if data.pos_cliente != Vector3.ZERO else data.pos_host + Vector3(2, 0, 0)
	var destino = (data.pos_host if es_host else pos_cliente_base) + offset_altura
	
	# Espera que el Cliente termine de inicializar su MultiplayerSynchronizer
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(jugador):
		return
		
	if jugador is CharacterBody3D:
		jugador.velocity = Vector3.ZERO
	jugador.global_position = destino
	
	# Obtenemos el ID de red del dueño del personaje (de su nombre o autoridad)
	var peer_id = jugador.name.to_int() if jugador.name.is_valid_int() else jugador.get_multiplayer_authority()
	
	# Enviamos la posición tanto por mover_a como por RPC directo de respaldo
	if jugador.has_method("mover_a") and peer_id > 0:
		jugador.mover_a.rpc_id(peer_id, destino)
	_forzar_posicion_en_todos.rpc(jugador.get_path(), destino)

@rpc("any_peer", "call_local", "reliable")
func _forzar_posicion_en_todos(ruta_jugador: NodePath, nueva_pos: Vector3) -> void:
	var jugador = get_node_or_null(ruta_jugador)
	if jugador:
		if jugador is CharacterBody3D:
			jugador.velocity = Vector3.ZERO
		jugador.global_position = nueva_pos

@rpc("authority", "call_local", "reliable")
func _sincronizar_estado_enemigos(atacan: bool, rutas_vivos: Array) -> void:
	GameManager.papas_atacan = atacan
	for enemigo in _obtener_todos_los_enemigos():
		var ruta = str(enemigo.get_path())
		if not rutas_vivos.has(ruta):
			enemigo.queue_free()
			

# Para asegurar posicionamiento correcto en partida guardada
func solicitar_posicion_guardada_al_servidor() -> void:
	_servidor_enviar_posicion_a_jugador.rpc_id(1, multiplayer.get_unique_id())


# El Servidor recibe el pedido, lee el archivo de guardado en su PC y le manda la coordenada exacta al Cliente
@rpc("any_peer", "call_local", "reliable")
func _servidor_enviar_posicion_a_jugador(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if rutaUtilizada == "" or not ResourceLoader.exists(rutaUtilizada):
		return
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return
		
	var offset_altura = Vector3(0, 0.5, 0)
	var destino: Vector3
	
	if peer_id == 1:
		destino = data.pos_host + offset_altura
	else:
		# Si pos_cliente quedó en (0,0,0), lo ponemos al lado del Host sí o sí
		var base_cliente = data.pos_cliente if data.pos_cliente != Vector3.ZERO else (data.pos_host + Vector3(2, 0, 0))
		destino = base_cliente + offset_altura
		
	print("Servidor enviando posición guardada al jugador ID ", peer_id, " -> ", destino)
	_cliente_aplicar_posicion_guardada.rpc_id(peer_id, peer_id, destino)

@rpc("authority", "call_local", "reliable")
func _cliente_aplicar_posicion_guardada(peer_id: int, nueva_pos: Vector3) -> void:
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		var id_nodo = jugador.name.to_int() if jugador.name.is_valid_int() else jugador.get_multiplayer_authority()
		if id_nodo == peer_id or (peer_id == 1 and jugador.get_multiplayer_authority() == 1) or (peer_id != 1 and jugador.get_multiplayer_authority() != 1):
			if jugador is CharacterBody3D:
				jugador.velocity = Vector3.ZERO
			jugador.global_position = nueva_pos
			print("¡Jugador ", peer_id, " teletransportado con éxito en su propio PC a: ", nueva_pos, "!")
