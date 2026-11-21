class_name EstadoBalsa
extends BotState

enum RolBalsa { ARTILLERO, PILOTO }

@export var rango_disparo_barriles: float = 25.0
@export var tiempo_maximo_abordaje: float = 0.85
@export var distancia_abordaje_directo: float = 4.5

var balsa: Node3D = null
var rol_balsa: RolBalsa = RolBalsa.ARTILLERO

var _abordado: bool = false
var _tiempo_intentando_subir: float = 0.0

func enter(datos: Dictionary = {}) -> void:
	balsa = datos.get("balsa", null)
	rol_balsa = datos.get("rol_balsa", RolBalsa.ARTILLERO)
	_abordado = false
	_tiempo_intentando_subir = 0.0
	
	if not is_instance_valid(balsa):
		state_machine.cambiar_estado("Seguir")

func exit() -> void:
	bot.equipar_arma(false)
	bot.salir_de_balsa()
	
	if is_instance_valid(balsa) and "pasajeros" in balsa:
		balsa.pasajeros.erase(bot)
	
	var ref_pos := bot.global_position
	var jugador: Node3D = bot.obtener_jugador_principal()
	if is_instance_valid(jugador):
		ref_pos = jugador.global_position
	elif is_instance_valid(balsa):
		ref_pos = balsa.global_position
	
	bot.global_position = _calcular_punto_desembarco_seguro(ref_pos)
	bot._reiniciar_navegacion()
	
	balsa = null
	_abordado = false

func _calcular_punto_desembarco_seguro(ref_pos: Vector3) -> Vector3:
	if bot.nav_agent:
		var mapa := bot.nav_agent.get_navigation_map()
		if mapa.is_valid() and NavigationServer3D.map_get_iteration_id(mapa) > 0:
			var en_nav := NavigationServer3D.map_get_closest_point(mapa, ref_pos)
			if Vector2(en_nav.x - ref_pos.x, en_nav.z - ref_pos.z).length() < 3.5 and absf(en_nav.y - ref_pos.y) < 2.0:
				# Verificamos con un rayo que no haya una pared invisible entre el jugador y el punto del NavMesh
				var espacio := bot.get_world_3d().direct_space_state
				if espacio:
					var query := PhysicsRayQueryParameters3D.create(
						ref_pos + Vector3(0.0, 1.0, 0.0),
						en_nav + Vector3(0.0, 1.0, 0.0)
					)
					var exclusiones: Array[RID] = [bot.get_rid()]
					var jugador := bot.obtener_jugador_principal()
					if is_instance_valid(jugador) and jugador is CollisionObject3D:
						exclusiones.append(jugador.get_rid())
					query.exclude = exclusiones
					if espacio.intersect_ray(query).is_empty():
						return en_nav + Vector3(0.0, 0.15, 0.0)
	
	# Respaldo 100% seguro: exactamente en la posición validada del jugador (nunca cruza una pared invisible)
	return ref_pos + Vector3(0.0, 0.1, 0.0)

func esta_abordado() -> bool:
	return _abordado

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if not is_instance_valid(balsa) or balsa.get("is_controlled") != true:
		state_machine.cambiar_estado("Seguir")
		return
	
	# Fase 1: Acercarse desde el muelle y subirse a la cubierta
	if not _abordado:
		_tiempo_intentando_subir += delta
		var destino_asiento := _obtener_destino_asiento()
		var dist_horiz := Vector2(bot.global_position.x - destino_asiento.x, bot.global_position.z - destino_asiento.z).length()
		
		# Si está lejos (>4.5 m), cerca (<1.6 m) o la balsa está por arrancar, sube directo antes de zarpar
		if dist_horiz <= 1.6 or dist_horiz > distancia_abordaje_directo or _tiempo_intentando_subir >= tiempo_maximo_abordaje:
			_completar_abordaje(destino_asiento)
		else:
			bot.mover_hacia(destino_asiento, delta, true)
		return
	
	# Fase 2: Ya embarcado, la balsa lo arrastra vía _arrastrar_pasajeros() y Nico dispara parado
	bot.velocity = Vector3.ZERO
	_comportamiento_artillero(delta)

func _obtener_destino_asiento() -> Vector3:
	if balsa.has_method("obtener_asiento_companero"):
		return balsa.obtener_asiento_companero()
	return balsa.to_global(Vector3(0.0, 0.65, 1.35))

func _completar_abordaje(pos_asiento: Vector3) -> void:
	_abordado = true
	bot.velocity = Vector3.ZERO
	
	# Ajustamos la altura exacta sobre la cubierta de la balsa con un raycast vertical
	var pos_final := pos_asiento
	var espacio := bot.get_world_3d().direct_space_state
	if espacio:
		var query := PhysicsRayQueryParameters3D.create(
			pos_asiento + Vector3(0.0, 2.0, 0.0),
			pos_asiento - Vector3(0.0, 2.0, 0.0)
		)
		query.exclude = [bot.get_rid()]
		var hit := espacio.intersect_ray(query)
		if not hit.is_empty():
			pos_final.y = hit.position.y + 0.05
	
	bot.global_position = pos_final
	
	if "pasajeros" in balsa and bot not in balsa.pasajeros:
		balsa.pasajeros.append(bot)
	
	if rol_balsa == RolBalsa.PILOTO:
		bot.prepare_for_raft()
	else:
		bot.salir_de_balsa()
		bot.equipar_arma(true)
		if bot.animation and bot.animation.has_animation("Pistol Idle/mixamo_com"):
			bot.animation.play("Pistol Idle/mixamo_com", 0.2)

func _comportamiento_artillero(delta: float) -> void:
	var barril := _buscar_barril_cercano(rango_disparo_barriles)
	if is_instance_valid(barril):
		bot.disparar_a(barril, delta, 0.5)
	else:
		bot.rotar_hacia(bot.global_position - balsa.transform.basis.z * 5.0, delta)

func _buscar_barril_cercano(rango: float) -> Node3D:
	var mas_cercano: Node3D = null
	var min_dist: float = rango
	var frente_balsa: Vector3 = -balsa.transform.basis.z.normalized()
	
	var candidatos: Array[Node] = get_tree().get_nodes_in_group("Barriles")
	if candidatos.is_empty():
		for nodo in get_tree().current_scene.find_children("*", "CollisionObject3D", true, false):
			if nodo.has_method("_colision_balsa"):
				candidatos.append(nodo)
	
	for b in candidatos:
		var barril := b as Node3D
		if not is_instance_valid(barril) or barril.is_queued_for_deletion():
			continue
		if barril.get("_destruido") == true or barril.get("muriendo") == true:
			continue
		# Si ya recibió un disparo y se puso rojo, Nico sabe que es indestructible y pasa al siguiente
		if barril.get("indestructible_revelado") == true:
			continue
		
		var hacia_barril: Vector3 = barril.global_position - balsa.global_position
		hacia_barril.y = 0.0
		var dist: float = hacia_barril.length()
		if dist >= min_dist or dist < 0.1:
			continue
		
		# Ignoramos barriles que ya quedaron detrás de la balsa
		if frente_balsa.dot(hacia_barril.normalized()) < -0.15:
			continue
		
		min_dist = dist
		mas_cercano = barril
	
	return mas_cercano
