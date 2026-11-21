class_name EstadoCombate
extends BotState

@export var grupo_enemigos: String = "Enemigos"
@export var rango_combate: float = 22.0
@export var distancia_segura: float = 6.5
@export var distancia_maxima_jugador: float = 30.0

var jefe_actual: Node3D = null
var boton_escudo_jefe: Node3D = null

var _tiempo_strafe: float = 0.0
var _direccion_strafe: float = 1.0

func enter(datos: Dictionary = {}) -> void:
	jefe_actual = datos.get("jefe", null)
	boton_escudo_jefe = datos.get("boton_escudo", null)
	_tiempo_strafe = randf_range(1.2, 2.2)
	_direccion_strafe = 1.0 if randf() > 0.5 else -1.0
	bot.equipar_arma(true)

func exit() -> void:
	bot.equipar_arma(false)

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
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
	
	# 2. Buscar mejor blanco activo según el rol actual
	var objetivo := _buscar_mejor_objetivo()
	if not is_instance_valid(objetivo):
		if not is_instance_valid(jefe_actual):
			state_machine.cambiar_estado("Seguir")
		else:
			bot.detener_movimiento(delta)
		return
	
	# 3. Actualizar temporizador de desplazamiento lateral evasivo (strafe)
	_tiempo_strafe -= delta
	if _tiempo_strafe <= 0.0 or bot.is_on_wall():
		_direccion_strafe *= -1.0
		_tiempo_strafe = randf_range(1.4, 2.4)
	
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
