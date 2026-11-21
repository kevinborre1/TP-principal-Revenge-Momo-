extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.5
@export var angulo_maximo_giro: float = 45.0  # grados a cada lado del rumbo inicial
@export var retraso_inicio: float = 1.0       # segundos hasta que arranca después de subirse
@export var asiento_companero: Marker3D       # Opcional: Marker3D sobre la cubierta para ubicar a Nico
@export var punto_desembarco: Marker3D        # Opcional: Marker3D fijo en el muelle de llegada

@onready var zona_cubierta: Area3D = get_node_or_null("ZonaCubierta")

@export var vida_balsa: int = 1

var is_controlled = false
var player_is_near = false
var player_node: Node3D = null      # jugador humano que está cerca (para abordar)
var piloto: Node3D = null           # jugador que la maneja
var pasajeros: Array[Node3D] = []   # jugadores y bot sobre la cubierta
var _transform_previa: Transform3D
var _rotacion_inicial: float = 0.0
var _inicio_marcha_ms: int = 0

var punto_spawn: Vector3
@export var tiempo_para_reiniciar: float = 3.0 # Segundos de espera antes de que vuelva sola
var _tiempo_vacia: float = 0.0

func _ready() -> void:
	add_to_group("Balsa")
	punto_spawn = global_transform.origin
	_rotacion_inicial = rotation.y
	_transform_previa = global_transform

	if zona_cubierta:
		zona_cubierta.body_entered.connect(_on_cubierta_body_entered)
		zona_cubierta.body_exited.connect(_on_cubierta_body_exited)
	else:
		push_warning("Falta el Area3D 'ZonaCubierta' en la balsa: los pasajeros no se moverán con ella.")

func _physics_process(delta: float) -> void:
	if Global.modo_multijugador == "linea" and not NetworkManager.red_conectada():
		return
	
	# ABORDAR / BAJAR (solo el piloto humano; el otro jugador o Nico van como pasajeros)
	if Input.is_action_just_pressed("Abordar"):
		if is_controlled:
			if is_multiplayer_authority():
				rpc_abordar_balsa.rpc(1, false)
		elif player_is_near and player_node != null:
			if player_node.name == str(multiplayer.get_unique_id()):
				rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), true)

	# 2. MOVIMIENTO: avanza sola; el piloto solo puede girar un poco a cada lado
	var en_marcha := is_controlled and Time.get_ticks_msec() >= _inicio_marcha_ms

	if is_multiplayer_authority():
		if en_marcha:
			var turn_input := Input.get_axis("Derecha", "Izquierda")
			var limite := deg_to_rad(angulo_maximo_giro)
			var giro := wrapf(rotation.y - _rotacion_inicial, -PI, PI)
			giro = clampf(giro + turn_input * turn_speed * delta, -limite, limite)
			rotation.y = _rotacion_inicial + giro
			velocity = -transform.basis.z * speed
		else:
			velocity = Vector3.ZERO

		move_and_slide()

		# --- LÓGICA DE COLISIÓN CON BARRILES (Solo el Host la procesa) ---
		if en_marcha:
			for i in get_slide_collision_count():
				var colision = get_slide_collision(i)
				var collider = colision.get_collider()

				if collider and collider.has_method("_colision_balsa"):
					collider._colision_balsa.rpc()
					rpc("_recibir_danio")
					break

	# ARRASTRAR PASAJEROS (corre en todas las PC)
	_arrastrar_pasajeros()

	# 4. VERIFICAR SI ESTÁ ABANDONADA PARA REINICIARLA (Solo la autoridad)
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if piloto == null and _sin_jugadores_humanos_en_cubierta():
			if global_transform.origin.distance_to(punto_spawn) > 1.0:
				_tiempo_vacia += delta
				if _tiempo_vacia >= tiempo_para_reiniciar:
					_tiempo_vacia = 0.0
					rpc_eliminar_balsa.rpc()
		else:
			_tiempo_vacia = 0.0

func _sin_jugadores_humanos_en_cubierta() -> bool:
	for p in pasajeros:
		if is_instance_valid(p) and not p.is_in_group("BotCompanero"):
			return false
	return true

func _arrastrar_pasajeros() -> void:
	var cambio := global_transform * _transform_previa.affine_inverse()
	_transform_previa = global_transform

	for p in pasajeros:
		if not is_instance_valid(p) or p == piloto:
			continue
		if Global.modo_multijugador == "linea" and not p.is_multiplayer_authority():
			continue
		p.global_position = cambio * p.global_position

func obtener_asiento_companero() -> Vector3:
	if is_instance_valid(asiento_companero):
		return asiento_companero.global_position
	# X = 0.0 (centro exacto), Z = 1.35 (bien atrás en la popa, detrás del piloto)
	return to_global(Vector3(0.0, 0.65, 1.35))

# Evalúa las direcciones alrededor de la balsa con raycasts para nunca atravesar paredes invisibles ni caer al vacío
func _obtener_posicion_desembarco_segura(separacion_extra: float = 0.0) -> Vector3:
	if is_instance_valid(punto_desembarco) and global_position.distance_to(punto_desembarco.global_position) < 15.0:
		return punto_desembarco.global_position
	
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return global_position + Vector3(0.0, 1.2, 0.0)
	
	var exclusiones := _obtener_exclusiones_fisicas()
	var origen_pared := global_position + Vector3(0.0, 1.0, 0.0)
	var distancia := 2.5 + separacion_extra
	
	# Probamos costados, frente, diagonales y atrás; si un lado tiene pared invisible, pasa al siguiente
	var direcciones: Array[Vector3] = [
		transform.basis.x,
		-transform.basis.x,
		-transform.basis.z,
		(transform.basis.x - transform.basis.z).normalized(),
		(-transform.basis.x - transform.basis.z).normalized(),
		transform.basis.z
	]
	
	var mapa: RID = get_world_3d().get_navigation_map()
	var tiene_nav := mapa.is_valid() and NavigationServer3D.map_get_iteration_id(mapa) > 0
	var respaldo_suelo_firme := Vector3.INF
	
	for dir in direcciones:
		var dir_plana := Vector3(dir.x, 0.0, dir.z).normalized()
		if dir_plana.length_squared() < 0.001:
			continue
		
		var candidato := global_position + dir_plana * distancia
		
		# 1. ¿Hay una pared (invisible o sólida) entre la balsa y este punto?
		var query_pared := PhysicsRayQueryParameters3D.create(origen_pared, candidato + Vector3(0.0, 1.0, 0.0))
		query_pared.exclude = exclusiones
		if not espacio.intersect_ray(query_pared).is_empty():
			continue
		
		# 2. ¿Hay suelo firme debajo y no el vacío o agua?
		var query_suelo := PhysicsRayQueryParameters3D.create(candidato + Vector3(0.0, 2.5, 0.0), candidato - Vector3(0.0, 4.5, 0.0))
		query_suelo.exclude = exclusiones
		var hit_suelo := espacio.intersect_ray(query_suelo)
		if hit_suelo.is_empty():
			continue
		
		var colisionador = hit_suelo.get("collider")
		if colisionador and "agua" in colisionador.name.to_lower():
			continue
		
		var pos_aterrizaje: Vector3 = hit_suelo.position + Vector3(0.0, 0.15, 0.0)
		
		# 3. Priorizamos puntos que además estén sobre el NavMesh (tierra firme / muelle)
		if tiene_nav:
			var en_nav := NavigationServer3D.map_get_closest_point(mapa, pos_aterrizaje)
			if Vector2(en_nav.x - pos_aterrizaje.x, en_nav.z - pos_aterrizaje.z).length() < 2.0 and absf(en_nav.y - pos_aterrizaje.y) < 1.5:
				return en_nav + Vector3(0.0, 0.15, 0.0)
		
		if respaldo_suelo_firme == Vector3.INF:
			respaldo_suelo_firme = pos_aterrizaje
	
	if respaldo_suelo_firme != Vector3.INF:
		return respaldo_suelo_firme
	
	# Último recurso: queda sobre la cubierta de la balsa sin atravesar ninguna pared
	return global_position + Vector3(0.0, 1.2, 0.0)

func _obtener_exclusiones_fisicas() -> Array[RID]:
	var exclusiones: Array[RID] = [get_rid()]
	if is_instance_valid(piloto) and piloto is CollisionObject3D:
		exclusiones.append(piloto.get_rid())
	for p in pasajeros:
		if is_instance_valid(p) and p is CollisionObject3D:
			exclusiones.append(p.get_rid())
	for bot in get_tree().get_nodes_in_group("BotCompanero"):
		if is_instance_valid(bot) and bot is CollisionObject3D:
			exclusiones.append(bot.get_rid())
	return exclusiones

@rpc("any_peer", "call_local", "reliable")
func rpc_abordar_balsa(id_jugador: int, subiendo: bool) -> void:
	if subiendo and is_controlled:
		return  # ya tiene piloto

	var jugador_objetivo: Node = null
	for j in get_tree().get_nodes_in_group("Jugador"):
		if j.name == str(id_jugador):
			jugador_objetivo = j
			break

	if subiendo and jugador_objetivo and jugador_objetivo.has_method("estoy_muerto") and not jugador_objetivo.estoy_muerto():
		set_multiplayer_authority(id_jugador)
		is_controlled = true
		_inicio_marcha_ms = Time.get_ticks_msec() + int(retraso_inicio * 1000.0)

		piloto = jugador_objetivo
		if "input_bloqueado" in piloto:
			piloto.input_bloqueado = true

		piloto.reparent(self, false)
		piloto.set_physics_process(false)
		piloto.position = Vector3(0, 1.0, 0)

		if piloto.has_method("prepare_for_raft"):
			piloto.prepare_for_raft()
		
		_notificar_bot_balsa(true)
	else:
		bajar_piloto()
		set_multiplayer_authority(1)

func _notificar_bot_balsa(subiendo: bool) -> void:
	var bot := get_tree().get_first_node_in_group("BotCompanero")
	if not is_instance_valid(bot) or bot.get("muerto") == true:
		return
	
	if subiendo:
		if bot.has_method("cambiar_estado"):
			bot.cambiar_estado("Balsa", {"balsa": self})
	else:
		if bot.state_machine and bot.state_machine.estado_actual and bot.state_machine.estado_actual.name == "Balsa":
			bot.cambiar_estado("Seguir")

func _on_zona_abordaje_body_entered(body: Node3D) -> void:
	if body.is_in_group("BotCompanero"):
		return
	if body.is_in_group("jugadores") or body.is_in_group("Jugador"):
		player_is_near = true
		player_node = body

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	if body == player_node:
		player_is_near = false
		player_node = null

func _on_cubierta_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador") and body not in pasajeros:
		pasajeros.append(body)

func _on_cubierta_body_exited(body: Node3D) -> void:
	if body.is_in_group("BotCompanero"):
		var sm = body.get("state_machine")
		if sm and sm.estado_actual and sm.estado_actual.has_method("esta_abordado") and sm.estado_actual.esta_abordado():
			return
	pasajeros.erase(body)

func eliminar_balsa() -> void:
	if Global.modo_multijugador == "linea":
		if multiplayer.is_server():
			rpc_eliminar_balsa.rpc()
	else:
		rpc_eliminar_balsa()

@rpc("any_peer", "call_local", "reliable")
func _recibir_danio() -> void:
	vida_balsa -= 1
	print("¡La balsa chocó con un barril! Vidas restantes: ", vida_balsa)

	if vida_balsa <= 0:
		print("¡La balsa se ha destruido!")
		if Global.modo_multijugador == "linea":
			if multiplayer.is_server():
				rpc_eliminar_balsa.rpc()
		else:
			rpc_eliminar_balsa()

@rpc("any_peer", "call_local", "reliable")
func rpc_eliminar_balsa() -> void:
	var piloto_anterior := piloto
	bajar_piloto()
	
	for pasajero in pasajeros:
		if not is_instance_valid(pasajero) or pasajero == piloto_anterior or pasajero.is_in_group("BotCompanero"):
			continue
		var pos_pasajero := _obtener_posicion_desembarco_segura(0.7)
		pasajero.set_deferred("global_position", pos_pasajero)

	pasajeros.clear()
	is_controlled = false
	velocity = Vector3.ZERO

	global_transform.origin = punto_spawn
	rotation.y = _rotacion_inicial
	_transform_previa = global_transform
	force_update_transform()
	vida_balsa = 1

func bajar_piloto() -> void:
	var pos_desembarco := _obtener_posicion_desembarco_segura()
	rotation.y = _rotacion_inicial
	is_controlled = false

	if piloto:
		piloto.reparent(get_tree().current_scene, false)
		piloto.set_physics_process(true)

		if piloto.has_method("salir_de_balsa"):
			piloto.salir_de_balsa()
		
		if "input_bloqueado" in piloto:
			piloto.input_bloqueado = false

		piloto.global_position = pos_desembarco
		piloto = null

	_notificar_bot_balsa(false)
