extends Node
const RUTA_LOGROS = "user://Logros.tres"

var logros: DataClassLogros

@export var rutaUtilizada: String = ""
@export var datos_logros: DataClassLogros = DataClassLogros.new()
var cache_inventario_host: Array = [null, null, null, null, null]
var cache_inventario_cliente: Array = [null, null, null, null, null]

func _es_jugador_host(jugador: Node) -> bool:
	if jugador.name == "1" or jugador.name == "Host":
		return true
	if jugador.name.is_valid_int() and jugador.name.to_int() != 1:
		return false
	return jugador.get_multiplayer_authority() == 1

func _obtener_activador_oleadas() -> Node:
	var nodos = get_tree().get_nodes_in_group("ActivadorOleadas")
	return nodos[0] if not nodos.is_empty() else null

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
	
	# 1. Guardar posición del Host
	for jugador in jugadores:
		if _es_jugador_host(jugador):
			data.pos_host = jugador.global_position
			if jugador.has_method("actualizar_respawn"):
				jugador.actualizar_respawn(data.pos_host)
			if jugador.has_node("Inventario"):
				cache_inventario_host = jugador.get_node("Inventario").items.duplicate(true)
			break
			
	# 2. Guardar posición del Cliente
	data.pos_cliente = data.pos_host + Vector3(2, 0, 0)
	for jugador in jugadores:
		if not _es_jugador_host(jugador):
			data.pos_cliente = jugador.global_position
			break
	
	data.inventario_host = cache_inventario_host.duplicate(true)
	data.inventario_cliente = cache_inventario_cliente.duplicate(true)
	data.cantidad_pepitas = _obtener_pepitas_actuales()
	
	data.estado_pepitas_mapa_guardado = true
	data.pepitas_restantes_en_mapa.clear()
	for p in get_tree().get_nodes_in_group("PepitasMapa"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			data.pepitas_restantes_en_mapa.append(str(p.get_path()))

	# 3. Guardar estado de las oleadas
	data.papas_atacan = GameManager.papas_atacan
	var activador = _obtener_activador_oleadas()
	if activador:
		data.ataque_iniciado = activador.ataque_iniciado
		data.fase_oleada = activador.fase_actual

	var err = ResourceSaver.save(data, rutaUtilizada)
	if err == OK:
		print("Guardado exitoso -> Pepitas: ", data.cantidad_pepitas, " | Fase oleada: ", data.fase_oleada)

func load_game() -> void:
	if not multiplayer.is_server() or not ResourceLoader.exists(rutaUtilizada):
		return
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return
	
	cache_inventario_host = data.inventario_host.duplicate(true)
	cache_inventario_cliente = data.inventario_cliente.duplicate(true)
		
	var activador = _obtener_activador_oleadas()
	if activador:
		activador.restaurar_oleada_guardada.rpc(data.ataque_iniciado, data.fase_oleada, data.papas_atacan)

# Llamado por cada jugador al terminar su _ready() en player.gd
func solicitar_posicion_guardada_al_servidor() -> void:
	_servidor_enviar_posicion_a_jugador.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func _servidor_enviar_posicion_a_jugador(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if rutaUtilizada == "" or not ResourceLoader.exists(rutaUtilizada):
		return
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return
		
	cache_inventario_host = data.inventario_host.duplicate(true)
	cache_inventario_cliente = data.inventario_cliente.duplicate(true)
		
	var offset_altura = Vector3(0, 0.5, 0)
	var destino: Vector3
	var inv_jugador: Array
	
	if peer_id == 1:
		destino = data.pos_host + offset_altura
		inv_jugador = data.inventario_host
	else:
		var base_cliente = data.pos_cliente if data.pos_cliente != Vector3.ZERO else (data.pos_host + Vector3(2, 0, 0))
		destino = base_cliente + offset_altura
		inv_jugador = data.inventario_cliente
		
	_cliente_aplicar_datos_guardados.rpc_id(
		peer_id,
		peer_id,
		destino,
		inv_jugador,
		data.cantidad_pepitas,
		data.estado_pepitas_mapa_guardado,
		data.pepitas_restantes_en_mapa
	)
	
	# Sincronizar las oleadas con el jugador que acaba de cargar
	var activador = _obtener_activador_oleadas()
	if activador:
		activador.restaurar_oleada_guardada.rpc_id(peer_id, data.ataque_iniciado, data.fase_oleada, data.papas_atacan)
		# Y si algún enemigo sigue vivo en la fase actual, lo hacemos visible en la pantalla del Cliente
		if data.ataque_iniciado and data.fase_oleada >= 1 and data.fase_oleada <= 3:
			activador.iniciar_fase(data.fase_oleada)

@rpc("authority", "call_local", "reliable")
func _cliente_aplicar_datos_guardados(
	peer_id: int, 
	nueva_pos: Vector3, 
	inv_guardado: Array, 
	pepitas_guardadas: int, 
	tiene_estado_pepitas: bool,
	pepitas_vivas_mapa: Array
) -> void:
	_aplicar_pepitas_en_juego(pepitas_guardadas)
	
	#Borrar del mapa pepitas ya recogidas
	if tiene_estado_pepitas:
		for p in get_tree().get_nodes_in_group("PepitasMapa"):
			var ruta_p = str(p.get_path())
			if not pepitas_vivas_mapa.has(ruta_p):
				p.queue_free()
	
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		var id_nodo = jugador.name.to_int() if jugador.name.is_valid_int() else jugador.get_multiplayer_authority()
		if id_nodo == peer_id or (peer_id == 1 and jugador.get_multiplayer_authority() == 1) or (peer_id != 1 and jugador.get_multiplayer_authority() != 1):
			if jugador is CharacterBody3D:
				jugador.velocity = Vector3.ZERO
			jugador.global_position = nueva_pos
			if jugador.has_method("actualizar_respawn"):
				jugador.actualizar_respawn(nueva_pos)
				
			if jugador.has_node("Inventario"):
				jugador.get_node("Inventario").cargar_datos_guardados(inv_guardado, jugador)
			print("¡Datos, inventario y pepitas (", pepitas_guardadas, ") restaurados para el jugador ", peer_id, "!")

func actualizar_logro(nombre_logro: String) -> void:
	if logros == null:
		cargar_logros()

	for propiedad in logros.get_property_list():
		if propiedad.name == nombre_logro:
			logros.set(nombre_logro, true)
			guardar_logros()
			print("Logro desbloqueado: ", nombre_logro)
			return

	push_warning("No existe el logro: " + nombre_logro)

func cargar_logros() -> void:
	if ResourceLoader.exists(RUTA_LOGROS):
		logros = ResourceLoader.load(
			RUTA_LOGROS,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		) as DataClassLogros

	if logros == null:
		logros = DataClassLogros.new()
		guardar_logros()

func sumar_estadistica(nombre: String) -> void:
	if logros == null:
		cargar_logros()

	# Verificar que exista la estadística
	var valor_actual = logros.get(nombre)

	if valor_actual == null:
		push_warning("No existe la estadística: " + nombre)
		return

	# Incrementar el contador
	logros.set(nombre, valor_actual + 1)

	# Comprobar si se desbloquea algún logro
	match nombre:
		"muertes":
			if logros.muertes >= 10:
				actualizar_logro("Moriste10Veces")

		"enemigosAsesinados":
			if logros.enemigosAsesinados >= 10:
				actualizar_logro("AsesinasteA10Enemigos")

		"barrilesRotos":
			if logros.barrilesRotos >= 15:
				actualizar_logro("Rompiste15Barriles")

	guardar_logros()

func guardar_logros() -> void:
	
	if logros == null:
		return

	var error := ResourceSaver.save(logros, RUTA_LOGROS)

	if error != OK:
		push_error("No se pudieron guardar los logros.")
		
@rpc("any_peer", "call_local", "reliable")
func registrar_inventario_jugador(peer_id: int, items_actualizados: Array) -> void:
	if not multiplayer.is_server():
		return
	if peer_id == 1:
		cache_inventario_host = items_actualizados.duplicate(true)
	else:
		cache_inventario_cliente = items_actualizados.duplicate(true)
		
func _obtener_pepitas_actuales() -> int:
	if GameManager.current_mode == GameManager.GameMode.RECOLECCION:
		return GameManager.current_count
	return 0

func _aplicar_pepitas_en_juego(cantidad: int) -> void:
	if GameManager.current_mode == GameManager.GameMode.RECOLECCION:
		GameManager._actualizar_conteo_red(cantidad)

# --- NUEVA FUNCIÓN MODULAR ---
# Devuelve la posición del último guardado oficial (o Vector3.ZERO si no existe)
func obtener_ultimo_checkpoint(soy_host: bool) -> Vector3:
	if rutaUtilizada == "" or not ResourceLoader.exists(rutaUtilizada):
		return Vector3.ZERO
		
	var data = ResourceLoader.load(rutaUtilizada, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null or data.pos_host == Vector3.ZERO:
		return Vector3.ZERO
		
	if soy_host:
		return data.pos_host
	else:
		return data.pos_cliente
