class_name EstadoCombate
extends BotState

@export var grupo_enemigos: String = "Enemigos"
@export var grupo_jefe: String = "JefeFinal"
@export var rango_combate: float = 22.0
@export var distancia_segura: float = 6.5
@export var distancia_segura_jefe: float = 9.5
@export var distancia_maxima_jugador: float = 30.0

var jefe_actual: Node3D = null
var boton_escudo_jefe: Node3D = null

var _tiempo_strafe: float = 0.0
var _direccion_strafe: float = 1.0

func enter(datos: Dictionary = {}) -> void:
	jefe_actual = datos.get("jefe", null)
	boton_escudo_jefe = datos.get("boton_escudo", null)
	if not is_instance_valid(jefe_actual):
		jefe_actual = _buscar_jefe_activo()
	_tiempo_strafe = randf_range(1.2, 2.2)
	_direccion_strafe = 1.0 if randf() > 0.5 else -1.0
	bot.equipar_arma(true)

func exit() -> void:
	bot.equipar_arma(false)

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if not is_instance_valid(jefe_actual) or jefe_actual.get("muriendo") == true:
		jefe_actual = _buscar_jefe_activo()
	
	# 1. Prioridad máxima en nivel de jefe: si el jefe activó su escudo, ir al botón
	if is_instance_valid(jefe_actual) and is_instance_valid(boton_escudo_jefe):
		if jefe_actual.get("escudo_activo") == true:
			state_machine.cambiar_estado("CooperarBoton", {
				"tipo": 3, # DESACTIVAR_ESCUDO_JEFE
				"boton": boton_escudo_jefe,
				"objetivo_estado": jefe_actual,
				"estado_siguiente": "Combate",
				"datos_siguiente": {"jefe": jefe_actual, "boton_escudo": boton_escudo_jefe}
			})
			return
	
	# Si el jugador avanzó muy lejos a otra sala y no estamos en pelea de jefe, volvemos a seguirlo
	var jugador: Node3D = bot.obtener_jugador_principal()
	if not is_instance_valid(jefe_actual) and is_instance_valid(jugador):
		if bot.global_position.distance_to(jugador.global_position) > distancia_maxima_jugador:
			state_machine.cambiar_estado("Seguir")
			return
	
	# 2. Actualizar temporizador de desplazamiento lateral evasivo (strafe)
	_tiempo_strafe -= delta
	if _tiempo_strafe <= 0.0 or bot.is_on_wall():
		_direccion_strafe *= -1.0
		_tiempo_strafe = randf_range(1.4, 2.4)
	
	# 3. Buscar mejor blanco activo según el rol actual
	var objetivo := _buscar_mejor_objetivo()
	if not is_instance_valid(objetivo):
		if is_instance_valid(jefe_actual) and jefe_actual.get("activo") == true:
			_evadir_jefe(delta, jugador)
		else:
			state_machine.cambiar_estado("Seguir")
		return
	
	var hacia_objetivo := objetivo.global_position - bot.global_position
	hacia_objetivo.y = 0.0
	var dist := hacia_objetivo.length()
	var dir_frente := hacia_objetivo.normalized() if dist > 0.01 else Vector3.FORWARD
	var dir_lateral := Vector3(-dir_frente.z, 0.0, dir_frente.x) * _direccion_strafe
	
	# 4. Posicionamiento táctico + disparo simultáneo
	if dist > rango_combate * 0.75:
		bot.mover_hacia(objetivo.global_position, delta, false)
	elif dist < distancia_segura:
		var dir_evasion := (-dir_frente + dir_lateral * 0.6).normalized()
		bot.mover_tactico(objetivo.global_position, dir_evasion, delta)
	else:
		bot.mover_tactico(objetivo.global_position, dir_lateral, delta)
	
	bot.disparar_a(objetivo, delta)

func _evadir_jefe(delta: float, jugador: Node3D) -> void:
	var en_furia: bool = jefe_actual.get("en_furia") == true
	var margen_seguro: float = distancia_segura_jefe + (4.0 if en_furia else 0.0)
	var dist_jefe: float = Vector2(
		bot.global_position.x - jefe_actual.global_position.x,
		bot.global_position.z - jefe_actual.global_position.z
	).length()
	
	if dist_jefe < margen_seguro:
		var destino_escape: Vector3 = _calcular_destino_escape_jefe(jefe_actual)
		bot.mover_hacia(destino_escape, delta, true)
	elif is_instance_valid(jugador) and bot.global_position.distance_to(jugador.global_position) > 10.0:
		bot.mover_hacia(jugador.global_position, delta, false)
	else:
		bot.detener_movimiento(delta)
		bot.rotar_hacia(jefe_actual.global_position, delta)

func _calcular_destino_escape_jefe(jefe: Node3D) -> Vector3:
	var origen: Vector3 = bot.global_position
	var desde_jefe: Vector3 = origen - jefe.global_position
	desde_jefe.y = 0.0
	var dir_base: Vector3 = desde_jefe.normalized() if desde_jefe.length_squared() > 0.001 else Vector3.BACK
	
	# Si toca una pared o puerta, priorizamos deslizar lateralmente en vez de insistir hacia atrás de ella
	if bot.is_on_wall():
		var normal_pared: Vector3 = bot.get_wall_normal()
		normal_pared.y = 0.0
		if normal_pared.length_squared() > 0.001:
			normal_pared = normal_pared.normalized()
			var tangente := Vector3(-normal_pared.z, 0.0, normal_pared.x)
			if tangente.dot(dir_base) < 0.0:
				tangente = -tangente
			dir_base = (tangente * 0.9 + normal_pared * 0.25).normalized()
	
	var angulos: Array[float] = [
		0.0,
		0.75 * _direccion_strafe,
		-0.75 * _direccion_strafe,
		1.45 * _direccion_strafe,
		-1.45 * _direccion_strafe,
		2.2 * _direccion_strafe,
		-2.2 * _direccion_strafe
	]
	var mejor_punto: Vector3 = origen
	var mejor_puntaje: float = -INF
	
	var mapa: RID = bot.nav_agent.get_navigation_map() if bot.nav_agent else RID()
	var tiene_mapa: bool = mapa.is_valid() and NavigationServer3D.map_get_iteration_id(mapa) > 0
	var espacio: PhysicsDirectSpaceState3D = bot.get_world_3d().direct_space_state
	
	var exclusiones: Array[RID] = [bot.get_rid()]
	if jefe is CollisionObject3D:
		exclusiones.append((jefe as CollisionObject3D).get_rid())
	var jugador: Node3D = bot.obtener_jugador_principal()
	if is_instance_valid(jugador) and jugador is CollisionObject3D:
		exclusiones.append((jugador as CollisionObject3D).get_rid())
	
	for angulo in angulos:
		var dir_cand: Vector3 = dir_base.rotated(Vector3.UP, angulo)
		var punto_crudo: Vector3 = origen + dir_cand * 4.5
		var punto_nav: Vector3 = NavigationServer3D.map_get_closest_point(mapa, punto_crudo) if tiene_mapa else punto_crudo
		
		# Evita puntos que caen en otro nivel/escalera o saltan del otro lado de una barrera
		if absf(punto_nav.y - origen.y) > 1.2:
			continue
		
		var desplazamiento: float = Vector2(punto_nav.x - origen.x, punto_nav.z - origen.z).length()
		if desplazamiento < 1.2 or desplazamiento > 6.5:
			continue
		
		# Si hay una puerta o pared bloqueando el tramo directo hacia punto_nav, descartamos este candidato
		if espacio:
			var query := PhysicsRayQueryParameters3D.create(
				origen + Vector3(0.0, 0.85, 0.0),
				punto_nav + Vector3(0.0, 0.85, 0.0)
			)
			query.exclude = exclusiones
			if not espacio.intersect_ray(query).is_empty():
				continue
		
		var dist_al_jefe: float = Vector2(punto_nav.x - jefe.global_position.x, punto_nav.z - jefe.global_position.z).length()
		var puntaje: float = dist_al_jefe + desplazamiento * 0.35
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_punto = punto_nav
	
	return mejor_punto

func _buscar_jefe_activo() -> Node3D:
	for jefe in get_tree().get_nodes_in_group(grupo_jefe):
		if is_instance_valid(jefe) and jefe.get("activo") == true and jefe.get("muriendo") != true:
			return jefe
	return null

func _buscar_mejor_objetivo() -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := rango_combate
	
	for enemigo in get_tree().get_nodes_in_group(grupo_enemigos):
		if not _es_objetivo_valido(enemigo):
			continue
		var d := bot.global_position.distance_to(enemigo.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = enemigo
	
	if mejor == null and is_instance_valid(jefe_actual):
		if jefe_actual.get("activo") == true and jefe_actual.get("muriendo") != true:
			if jefe_actual.get("escudo_activo") != true and jefe_actual.get("solo_danio_por_pantallas") != true:
				return jefe_actual
	return mejor

func _es_objetivo_valido(enemigo: Node3D) -> bool:
	if not is_instance_valid(enemigo):
		return false
	if enemigo.get("activo") != true or enemigo.get("muriendo") == true:
		return false
	if enemigo.get("solo_danio_por_pantallas") == true:
		return false
	
	var tiene_escudo_activo: bool = enemigo.get("escudo_activo") == true
	match bot.rol:
		"rompe_escudo":
			return tiene_escudo_activo
		"letal":
			return not tiene_escudo_activo
		_:
			return true
