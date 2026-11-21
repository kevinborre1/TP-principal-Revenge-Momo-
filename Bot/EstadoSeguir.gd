class_name EstadoSeguir
extends BotState

@export var distancia_minima: float = 2.8
@export var distancia_correr: float = 7.0
@export var detectar_combate: bool = true
@export var rango_deteccion_combate: float = 22.0
@export var grupo_enemigos: String = "Enemigos"
@export var grupo_jefe: String = "JefeFinal"

var _timer_escaneo: float = 0.0

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if detectar_combate:
		_timer_escaneo -= delta
		if _timer_escaneo <= 0.0:
			_timer_escaneo = 0.25
			var jefe := _buscar_jefe_cerca()
			if is_instance_valid(jefe):
				state_machine.cambiar_estado("Combate", {"jefe": jefe})
				return
			if _hay_objetivo_valido_cerca():
				state_machine.cambiar_estado("Combate")
				return
	
	var jugador: Node3D = bot.obtener_jugador_principal()
	if not is_instance_valid(jugador):
		bot.detener_movimiento(delta)
		return
	
	var dist := bot.global_position.distance_to(jugador.global_position)
	if dist > distancia_minima:
		bot.mover_hacia(jugador.global_position, delta, dist > distancia_correr)
	else:
		bot.detener_movimiento(delta)

func _buscar_jefe_cerca() -> Node3D:
	for jefe in get_tree().get_nodes_in_group(grupo_jefe):
		if not is_instance_valid(jefe):
			continue
		if jefe.get("activo") != true or jefe.get("muriendo") == true:
			continue
		if bot.global_position.distance_to(jefe.global_position) <= rango_deteccion_combate * 1.3:
			return jefe
	return null

func _hay_objetivo_valido_cerca() -> bool:
	for enemigo in get_tree().get_nodes_in_group(grupo_enemigos):
		if not is_instance_valid(enemigo):
			continue
		if enemigo.get("activo") != true or enemigo.get("muriendo") == true:
			continue
		if enemigo.get("solo_danio_por_pantallas") == true:
			continue
		
		var tiene_escudo: bool = enemigo.get("escudo_activo") == true
		var valido_para_rol := true
		if bot.rol == "rompe_escudo":
			valido_para_rol = tiene_escudo
		elif bot.rol == "letal":
			valido_para_rol = not tiene_escudo
		
		if valido_para_rol and bot.global_position.distance_to(enemigo.global_position) <= rango_deteccion_combate:
			return true
	return false
