class_name EstadoCartelColor
extends BotState

@export var distancia_maxima_disparo: float = 22.0

var pantalla_objetivo: Node3D = null
var minijuego: Node = null
var jefe: Node3D = null

var _tiempo_apuntado: float = 0.0
var _ya_disparo: bool = false
var _espera_post_disparo: float = 0.0
var _lado_rodeo: float = 1.0

func enter(datos: Dictionary = {}) -> void:
	pantalla_objetivo = datos.get("pantalla", null)
	minijuego = datos.get("minijuego", null)
	jefe = datos.get("jefe", null)
	_tiempo_apuntado = 0.25
	_ya_disparo = false
	_espera_post_disparo = 0.0
	_lado_rodeo = 1.0 if randf() > 0.5 else -1.0
	bot.equipar_arma(true)

func exit() -> void:
	bot.equipar_arma(false)
	pantalla_objetivo = null
	minijuego = null

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if not _ronda_sigue_activa():
		_volver_a_combate_o_seguir()
		return
	
	if _ya_disparo:
		bot.detener_movimiento(delta)
		bot.rotar_hacia(pantalla_objetivo.global_position, delta)
		_espera_post_disparo -= delta
		if _espera_post_disparo <= 0.0:
			_volver_a_combate_o_seguir()
		return
	
	if bot.is_on_wall():
		_lado_rodeo *= -1.0
	
	var pos_bot := Vector2(bot.global_position.x, bot.global_position.z)
	var pos_pantalla := Vector2(pantalla_objetivo.global_position.x, pantalla_objetivo.global_position.z)
	var dist := pos_bot.distance_to(pos_pantalla)
	var tiro_despejado := _tiene_linea_de_vision()
	
	# Si está fuera de rango o el jefe le tapa el tiro/camino, rodea lateralmente hasta tener ángulo limpio
	if dist > distancia_maxima_disparo or not tiro_despejado:
		var destino := _calcular_destino_rodeo(dist > distancia_maxima_disparo)
		bot.mover_hacia(destino, delta, true)
		return
	
	bot.detener_movimiento(delta)
	bot.rotar_hacia(pantalla_objetivo.global_position, delta)
	
	if _tiempo_apuntado > 0.0:
		_tiempo_apuntado -= delta
		return
	
	# offset_altura = 0.0 porque el origen de PantallaColor ya está en el centro del cartel
	if bot.disparar_a(pantalla_objetivo, delta, 0.0):
		_ya_disparo = true
		_espera_post_disparo = 0.4

func _tiene_linea_de_vision() -> bool:
	if not is_instance_valid(pantalla_objetivo):
		return false
	var espacio := bot.get_world_3d().direct_space_state
	if espacio == null:
		return true
	
	var origen := bot.global_position + Vector3(0.0, 1.1, 0.0)
	var destino := pantalla_objetivo.global_position
	var query := PhysicsRayQueryParameters3D.create(origen, destino)
	
	# Ignoramos al propio bot y a los jugadores porque las balas los atraviesan
	var exclusiones: Array[RID] = []
	if bot is CollisionObject3D:
		exclusiones.append(bot.get_rid())
	for j in get_tree().get_nodes_in_group("Jugador"):
		if j is CollisionObject3D:
			exclusiones.append(j.get_rid())
	query.exclude = exclusiones
	
	var resultado := espacio.intersect_ray(query)
	if resultado.is_empty():
		return true
	return resultado.get("collider") == pantalla_objetivo

func _calcular_destino_rodeo(necesita_acercarse: bool) -> Vector3:
	var hacia_pantalla := pantalla_objetivo.global_position - bot.global_position
	hacia_pantalla.y = 0.0
	var dir_frente := hacia_pantalla.normalized() if hacia_pantalla.length_squared() > 0.001 else Vector3.FORWARD
	var dir_lateral := Vector3(-dir_frente.z, 0.0, dir_frente.x) * _lado_rodeo
	
	# Si el jefe está cerca, elegimos el costado que más se aleje del jefe
	if is_instance_valid(jefe) and jefe.get("activo") == true:
		var desde_jefe := bot.global_position - jefe.global_position
		desde_jefe.y = 0.0
		if desde_jefe.length() < 7.0 and dir_lateral.dot(desde_jefe) < 0.0:
			_lado_rodeo *= -1.0
			dir_lateral = -dir_lateral
	
	var dir_combinada := (dir_frente * 0.55 + dir_lateral * 0.85).normalized() if necesita_acercarse else dir_lateral
	var punto_crudo := bot.global_position + dir_combinada * 4.5
	
	if bot.nav_agent:
		var mapa := bot.nav_agent.get_navigation_map()
		if mapa.is_valid() and NavigationServer3D.map_get_iteration_id(mapa) > 0:
			return NavigationServer3D.map_get_closest_point(mapa, punto_crudo)
	return punto_crudo

func _ronda_sigue_activa() -> bool:
	if not is_instance_valid(pantalla_objetivo) or not is_instance_valid(minijuego):
		return false
	if minijuego.get("activo") != true:
		return false
	if minijuego.get("esperando") == true or minijuego.get("en_furia") == true:
		return false
	return true

func _volver_a_combate_o_seguir() -> void:
	if is_instance_valid(jefe) and jefe.get("activo") == true and jefe.get("muriendo") != true:
		state_machine.cambiar_estado("Combate", {"jefe": jefe})
	else:
		state_machine.cambiar_estado("Seguir")
