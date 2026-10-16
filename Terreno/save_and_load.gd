extends Node

@export var rutaUtilizada: String = ""

func save_game() -> void:
	print("Guardando en: ", rutaUtilizada)
	if not multiplayer.is_server():
		return
		
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	if jugadores.is_empty():
		print("Advertencia: No hay jugadores en escena para guardar su posición.")
		return

	# Si ya existe un guardado, lo cargamos primero para no borrar pepitas ni logros
	var data: SaveData
	if ResourceLoader.exists(rutaUtilizada):
		data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null:
		data = SaveData.new()
		
	data.escena_actual = get_tree().current_scene.scene_file_path
	
	# 1. Primero buscamos al Host para tener su posición segura
	for jugador in jugadores:
		if jugador.name == "1" or jugador.get_multiplayer_authority() == 1:
			data.pos_host = jugador.global_position
			break
			
	# 2. Luego buscamos al Cliente (o le damos una posición al lado del Host por defecto)
	data.pos_cliente = data.pos_host + Vector3(2, 0, 0)
	for jugador in jugadores:
		if jugador.name != "1" and jugador.get_multiplayer_authority() != 1:
			data.pos_cliente = jugador.global_position
			break
			
	# 3. Guardar si las papas ya estaban atacando
	data.papas_atacan = GameManager.papas_atacan

	# 4. Guardar cuáles enemigos siguen vivos (no hicieron queue_free)
	data.estado_enemigos_guardado = true
	data.enemigos_vivos.clear()
	for enemigo in _obtener_todos_los_enemigos():
		if not enemigo.is_queued_for_deletion() and enemigo.vida_actual > 0:
			data.enemigos_vivos.append(str(enemigo.get_path()))

	var err = ResourceSaver.save(data, rutaUtilizada)
	if err == OK:
		print("Servidor: Partida guardada correctamente. Host en: ", data.pos_host)
	else:
		print("Error al guardar: ", err)


func load_game() -> void:
	print("Cargando desde: ", rutaUtilizada)
	if not multiplayer.is_server():
		return
		
	if not ResourceLoader.exists(rutaUtilizada):
		print("No existe ningún archivo de guardado.")
		return
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null:
		return
		
	# Si pos_host es (0,0,0), significa que el archivo es nuevo y aún no tocaron un checkpoint
	if data.pos_host == Vector3.ZERO:
		print("Archivo nuevo sin checkpoint previo. Se mantiene el spawn original del mapa.")
		return
		
	# Pequeño offset hacia arriba (0.5m en Y) para evitar que atraviesen el piso al teletransportarse
	var offset_altura = Vector3(0, 0.5, 0)
	var pos_host_segura = data.pos_host + offset_altura
	var pos_cliente_segura = (data.pos_cliente if data.pos_cliente != Vector3.ZERO else data.pos_host + Vector3(2, 0, 0)) + offset_altura
	
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		var id_autoridad = jugador.get_multiplayer_authority()
		var es_host = (jugador.name == "1" or id_autoridad == 1)
		var destino = pos_host_segura if es_host else pos_cliente_segura
		
		# Reseteamos la velocidad de caída antes de moverlo
		if jugador is CharacterBody3D:
			jugador.velocity = Vector3.ZERO
			
		if Global.modo_multijugador == "linea" and jugador.has_method("mover_a"):
			# Le enviamos a CADA jugador su posición correspondiente (Host -> pos_host, Cliente -> pos_cliente)
			jugador.mover_a.rpc_id(id_autoridad, destino)
		else:
			jugador.global_position = destino
			
	if data.estado_enemigos_guardado:
		_sincronizar_estado_enemigos.rpc(data.papas_atacan, data.enemigos_vivos)
				
	print("Servidor: Partida cargada y posiciones aplicadas correctamente (jugador/enemigos)")
	
	# Obtiene a todos los enemigos
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
	
@rpc("authority", "call_local", "reliable")
func _sincronizar_estado_enemigos(atacan: bool, rutas_vivos: Array) -> void:
	GameManager.papas_atacan = atacan
	
	for enemigo in _obtener_todos_los_enemigos():
		var ruta = str(enemigo.get_path())
		if not rutas_vivos.has(ruta):
			enemigo.queue_free()
