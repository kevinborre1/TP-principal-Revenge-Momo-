extends Node
const RUTA_LOGROS = "user://Logros.tres"
const RUTA_CONFIGURACION = "user://Configuracion.tres"

var configuracion: DataClassConfiguracion
var logros: DataClassLogros

@export var rutaUtilizada: String = ""
@export var datos_logros: DataClassLogros = DataClassLogros.new()
var cache_inventario_host: Array = [null, null, null, null, null]
var cache_inventario_cliente: Array = [null, null, null, null, null]
var ranking_compartido: Array = []
signal ranking_actualizado(nuevo_ranking: Array)
var posicion_segura_host: Vector3 = Vector3.ZERO
var posicion_segura_cliente: Vector3 = Vector3.ZERO

func _ready() -> void:
	cargar_configuracion()
	MenuOpciones.aplicar_guardados()
# Llama a esta función desde el Area3D (Checkpoint) pasándole la posición del Marker3D
func establecer_posicion_predeterminada(posicion_base: Vector3) -> void:
	posicion_segura_host = posicion_base
	# Le damos un offset al cliente para que no aparezca exactamente dentro del host
	posicion_segura_cliente = posicion_base + Vector3(4, 0, 0)

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
	
	# Guardar posiciones del Host y Cliente en un solo bucle (Principio DRY)
	for jugador in jugadores:
		if _es_jugador_host(jugador):
			# Lógica del Host
			data.pos_host = posicion_segura_host if posicion_segura_host != Vector3.ZERO else jugador.global_position
			#Nos aseguramos de que si el host llega solo a un punto importante, si el cliente se une despues, este con el
			data.pos_cliente = posicion_segura_cliente if posicion_segura_cliente != Vector3.ZERO else jugador.global_position + Vector3(4, 0, 0)
			
			if jugador.has_method("actualizar_respawn"):
				jugador.actualizar_respawn(data.pos_host)
			if jugador.has_node("Inventario"):
				cache_inventario_host = jugador.get_node("Inventario").items.duplicate(true)
		else:
			print("Guardando cliente")
			# Lógica del Cliente
			if jugador.has_method("actualizar_respawn"):
				jugador.actualizar_respawn(data.pos_cliente)
			
	data.inventario_host = cache_inventario_host.duplicate(true)
	data.inventario_cliente = cache_inventario_cliente.duplicate(true)
	data.cantidad_pepitas = _obtener_pepitas_actuales()
	
	data.estado_pepitas_mapa_guardado = true
	data.pepitas_restantes_en_mapa.clear()
	for p in get_tree().get_nodes_in_group("PepitasMapa"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			data.pepitas_restantes_en_mapa.append(str(p.get_path()))
	
	# AQUÍ VA EL PASO 3: Guardar items base del mapa
	data.estado_items_mapa_guardado = true
	data.items_restantes_en_mapa.clear()
	for item in get_tree().get_nodes_in_group("ItemBaseMapa"):
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			data.items_restantes_en_mapa.append(str(item.get_path()))
	
	#Guardamos los objetos que fueron soltados en otra zona del mapa
	data.items_soltados.clear()
	for item in get_tree().get_nodes_in_group("ItemsSoltadosGuardables"):
		if is_instance_valid(item):
			data.items_soltados.append({
				"ruta": item.scene_file_path,
				"pos": item.global_position
		})		
	# 4. Guardar estado de las oleadas
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
	#Si el cliente se une luego de el juego empezado se le da una copia del inventario del cliente 
	if not data.inventario_cliente.is_empty():
		cache_inventario_cliente = data.inventario_cliente.duplicate(true)
	else:
		cache_inventario_cliente = data.inventario_host.duplicate(true)
		
	var activador = _obtener_activador_oleadas()
	if activador:
		activador.restaurar_oleada_guardada.rpc(data.ataque_iniciado, data.fase_oleada, data.papas_atacan)
	# Dentro de load_game(), exclusivo del Host
	var contenedor = get_tree().current_scene.get_node_or_null("ContenedorItemsSoltados")
	if contenedor:
		for item_data in data.items_soltados:
			var nuevo_item = load(item_data["ruta"]).instantiate()
			nuevo_item.global_position = item_data["pos"]
			contenedor.add_child(nuevo_item)
		
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
		data.pepitas_restantes_en_mapa,
		data.estado_items_mapa_guardado, # NUEVO
		data.items_restantes_en_mapa     # NUEVO
		
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
	pepitas_vivas_mapa: Array,
	tiene_estado_items: bool, # NUEVO
	items_vivos_mapa: Array   # NUEVO
) -> void:
	_aplicar_pepitas_en_juego(pepitas_guardadas)
	
	# 1. Aseguramos que solo el servidor elimine los nodos si usas MultiplayerSpawner
	if multiplayer.is_server():
		
		# Borrar pepitas ya recogidas
		if tiene_estado_pepitas:
			for p in get_tree().get_nodes_in_group("PepitasMapa"):
				var ruta_p = str(p.get_path())
				if not pepitas_vivas_mapa.has(ruta_p):
					# Usamos call_deferred() para evitar el error del spawner
					p.queue_free.call_deferred()
					
		# Borrar items ya recogidos
		if tiene_estado_items:
			for item in get_tree().get_nodes_in_group("ItemBaseMapa"):
				var ruta_item = str(item.get_path())
				if not items_vivos_mapa.has(ruta_item):
					# Usamos call_deferred() para evitar el error del spawner
					item.queue_free.call_deferred()
	
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
		
func _obtener_ruta_puntajes() -> String:
	# Default: puntajes.json
	if rutaUtilizada != "":
		var base = rutaUtilizada.get_file().get_basename() 
		return "user://puntajes_" + base + ".json"
	return "user://puntajes.json"

# Cuando un jugador termina el minijuego
func registrar_puntaje_minijuego(nombre_jugador: String, puntaje: int) -> void:
	if Global.modo_multijugador == "linea":
		rpc_id(1, "_servidor_guardar_puntaje", nombre_jugador, puntaje)
	else:
		_servidor_guardar_puntaje(nombre_jugador, puntaje)

# Llamar a esta función al abrir el minijuego para pedir la tabla actualizada al Host
func solicitar_ranking_minijuego() -> void:
	if Global.modo_multijugador == "linea":
		rpc_id(1, "_servidor_enviar_ranking", multiplayer.get_unique_id())
	else:
		_servidor_cargar_archivo_puntajes()
		ranking_actualizado.emit(ranking_compartido)

@rpc("any_peer", "call_local", "reliable")
func _servidor_guardar_puntaje(nombre_jugador: String, puntaje: int) -> void:
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
		
	_servidor_cargar_archivo_puntajes()
	
	# Agregamos el nuevo puntaje
	ranking_compartido.append({
		"nombre": nombre_jugador,
		"puntaje": puntaje
	})
	
	# Ordenamos de mayor a menor puntaje 
	ranking_compartido.sort_custom(func(a, b): return a.get("puntaje", 0) > b.get("puntaje", 0))
	
	# Guardamos en el JSON oficial del Host
	var ruta = _obtener_ruta_puntajes()
	var file = FileAccess.open(ruta, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(ranking_compartido, "\t"))
		file.close()
		
	# Enviamos la lista unificada a TODOS los jugadores (Host y Cliente)
	if Global.modo_multijugador == "linea":
		rpc("_cliente_recibir_ranking", ranking_compartido)
	else:
		_cliente_recibir_ranking(ranking_compartido)
		
@rpc("any_peer", "call_local", "reliable")
func _servidor_enviar_ranking(peer_id: int) -> void:
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	_servidor_cargar_archivo_puntajes()
	rpc_id(peer_id, "_cliente_recibir_ranking", ranking_compartido)
	
func _servidor_cargar_archivo_puntajes() -> void:
	var ruta = _obtener_ruta_puntajes()
	if FileAccess.file_exists(ruta):
		var file = FileAccess.open(ruta, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				ranking_compartido = parsed
			file.close()

@rpc("authority", "call_local", "reliable")
func _cliente_recibir_ranking(lista_ranking: Array) -> void:
	ranking_compartido = lista_ranking
	# También guardamos una copia local en user://puntajes.json por si el cliente quiere tenerlo
	var file = FileAccess.open("user://puntajes.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(ranking_compartido, "\t"))
		file.close()
	ranking_actualizado.emit(ranking_compartido)

# 1. El jugador nuevo llama a esto al aparecer
func solicitar_sincronizacion_mapa_al_servidor() -> void:
	_servidor_enviar_estado_vivo_mapa.rpc_id(1, multiplayer.get_unique_id())

# 2. El servidor revisa qué hay VIVO AHORA MISMO en su mapa
@rpc("any_peer", "call_local", "reliable")
func _servidor_enviar_estado_vivo_mapa(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var pepitas_vivas: Array = []
	for p in get_tree().get_nodes_in_group("PepitasMapa"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			pepitas_vivas.append(str(p.get_path()))
			
	var items_vivos: Array = []
	for item in get_tree().get_nodes_in_group("ItemBaseMapa"):
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			items_vivos.append(str(item.get_path()))
			
	 #NUEVO: Recopilar el inventario exacto que tienen los jugadores en este momento
	var inventarios_vivos: Dictionary = {}
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		if jugador.has_node("Inventario") and int(jugador.get_multiplayer_authority()) != peer_id :
			inventarios_vivos[jugador.name] = jugador.get_node("Inventario").items.duplicate(true)
			print("Linea 417 save_and_load.gb El nombre del jugador en el mapa vivo es: "+jugador.name +" y el id: "+ str(peer_id))
	 #Le manda la lista exclusivamente al jugador que acaba de entrar
	_cliente_sincronizar_mapa_vivo.rpc_id(peer_id, pepitas_vivas, items_vivos, inventarios_vivos)

# 3. El cliente nuevo recibe la lista y destruye lo que sobra
@rpc("authority", "call_local", "reliable")
func _cliente_sincronizar_mapa_vivo(pepitas_vivas: Array, items_vivos: Array, inventarios_vivos: Dictionary) -> void:
	# Como son objetos base del mapa (no creados por un Spawner), el cliente DEBE borrarlos localmente
	for p in get_tree().get_nodes_in_group("PepitasMapa"):
		if not pepitas_vivas.has(str(p.get_path())):
			p.queue_free()
			
	for item in get_tree().get_nodes_in_group("ItemBaseMapa"):
		if not items_vivos.has(str(item.get_path())):
			item.queue_free()
			
	 #NUEVO: Inyectar los ítems recibidos en los inventarios de los jugadores correspondientes
	for nombre_jugador in inventarios_vivos.keys():
		var jugador = get_tree().current_scene.find_child(nombre_jugador, true, false)
		if jugador and jugador.has_node("Inventario"):
			var inv_manager = jugador.get_node("Inventario")
			#inv_manager.cargar_datos_guardados(inventarios_vivos[nombre_jugador], jugador)
			
	print("Mapa sincronizado con el estado en vivo del servidor.")
func cargar_configuracion() -> void:
	if ResourceLoader.exists(RUTA_CONFIGURACION):
		configuracion = ResourceLoader.load(
			RUTA_CONFIGURACION,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		) as DataClassConfiguracion

	if configuracion == null:
		configuracion = DataClassConfiguracion.new()
		guardar_configuracion()
		return

	# Si más adelante agregás acciones nuevas, completa las que falten con los defaults
	var base := DataClassConfiguracion.new()
	for accion in base.controles:
		if not configuracion.controles.has(accion):
			configuracion.controles[accion] = base.controles[accion]

func guardar_configuracion() -> void:
	if configuracion == null:
		return

	var error := ResourceSaver.save(configuracion, RUTA_CONFIGURACION)

	if error != OK:
		push_error("No se pudo guardar la configuración.")

func destruir_partida_y_limpiar() -> void:
	# Borrar el archivo físico si existe
	if rutaUtilizada != "" and FileAccess.file_exists(rutaUtilizada):
		var err := DirAccess.remove_absolute(rutaUtilizada)
		if err == OK:
			print("Guardado borrado exitosamente: ", rutaUtilizada)
		else:
			push_warning("Error al borrar el archivo: ", err)
			
	# Limpiar la memoria (para evitar que se mezclen datos)
	rutaUtilizada = ""
	cache_inventario_host.clear()
	cache_inventario_cliente.clear()
	posicion_segura_host = Vector3.ZERO
	posicion_segura_cliente = Vector3.ZERO
