extends BotState

@export var grupo_enemigos: String = "Enemigos"
@export var rango_combate: float = 25.0
@export var distancia_segura: float = 7.0

var jefe_actual: Node3D = null
var boton_escudo_jefe: Node3D = null

func enter(datos: Dictionary = {}) -> void:
	jefe_actual = datos.get("jefe", null)
	boton_escudo_jefe = datos.get("boton_escudo", null)

func physics_update(delta: float) -> void:
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

	# 2. Buscar mejor blanco según el rol (papitas primero, o jefe si es vulnerable)
	var objetivo := _buscar_mejor_objetivo()
	if not is_instance_valid(objetivo):
		# Si no hay enemigos activos y no hay jefe vivo, volver a seguir al jugador
		if not is_instance_valid(jefe_actual):
			state_machine.cambiar_estado("Seguir")
		else:
			bot.detener_movimiento(delta)
		return

	# 3. Mantener distancia de tiro y disparar
	var dist := bot.global_position.distance_to(objetivo.global_position)
	if dist > rango_combate * 0.7:
		bot.mover_hacia(objetivo.global_position, delta, false)
	elif dist < distancia_segura:
		# Retrocede un poco para no quedar pegado al enemigo
		var dir_escape := (bot.global_position - objetivo.global_position).normalized()
		bot.mover_hacia(bot.global_position + dir_escape * 4.0, delta, false)
	else:
		bot.detener_movimiento(delta)
	
	bot.disparar_a(objetivo, delta)

func _buscar_mejor_objetivo() -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := rango_combate
	
	for enemigo in get_tree().get_nodes_in_group(grupo_enemigos):
		if not is_instance_valid(enemigo) or enemigo.get("muerto") == true:
			continue
		if not _es_objetivo_valido_para_mi_rol(enemigo):
			continue
		var d := bot.global_position.distance_to(enemigo.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = enemigo
	
	# Si no quedan papitas válidas, dispararle al jefe si está sin escudo
	if mejor == null and is_instance_valid(jefe_actual):
		if jefe_actual.get("escudo_activo") != true and jefe_actual.get("muerto") != true:
			return jefe_actual
	return mejor

func _es_objetivo_valido_para_mi_rol(enemigo: Node3D) -> bool:
	var tiene_escudo: bool = enemigo.get("tiene_escudo") == true
	match bot.rol:
		"rompe_escudo":
			return tiene_escudo
		"letal":
			return not tiene_escudo
		_:
			return true
