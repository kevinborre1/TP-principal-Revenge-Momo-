class_name EstadoSeguir
extends BotState

@export var distancia_minima: float = 2.8
@export var distancia_correr: float = 7.0
@export var detectar_combate: bool = true
@export var rango_deteccion_combate: float = 22.0
@export var multiplicador_rango_jefe: float = 3.5
@export var grupo_enemigos: String = "Enemigos"
@export var grupo_jefe: String = "JefeFinal"

var _timer_escaneo: float = 0.0

func enter(_datos: Dictionary = {}) -> void:
	_timer_escaneo = 0.0

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if hay_persecucion_final_activa():
		state_machine.cambiar_estado("Escape")
		return
	
	if detectar_combate:
		_timer_escaneo -= delta
		if _timer_escaneo <= 0.0:
			_timer_escaneo = 0.25
			var jefe: Node3D = _buscar_jefe_cerca()
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
	
	var dist: float = bot.global_position.distance_to(jugador.global_position)
	if dist > distancia_minima:
		bot.mover_hacia(jugador.global_position, delta, dist > distancia_correr)
	else:
		bot.detener_movimiento(delta)

func _buscar_jefe_cerca() -> Node3D:
	var rango_jefe: float = rango_deteccion_combate * multiplicador_rango_jefe
	for jefe in get_tree().get_nodes_in_group(grupo_jefe):
		if not (jefe is Node3D):
			continue
		var nodo_jefe := jefe as Node3D
		if not jefe_esta_activo(nodo_jefe):
			continue
		if bot.global_position.distance_to(obtener_posicion_jefe(nodo_jefe)) <= rango_jefe:
			return nodo_jefe
	return null

func _hay_objetivo_valido_cerca() -> bool:
	for enemigo in get_tree().get_nodes_in_group(grupo_enemigos):
		if not (enemigo is Node3D) or not is_instance_valid(enemigo):
			continue
		if enemigo.get("activo") != true or enemigo.get("muriendo") == true:
			continue
		if enemigo.get("solo_danio_por_pantallas") == true:
			continue
		
		var tiene_escudo: bool = bool(enemigo.get("escudo_activo"))
		var valido_para_rol: bool = true
		if bot.rol == "rompe_escudo":
			valido_para_rol = tiene_escudo
		elif bot.rol == "letal":
			valido_para_rol = not tiene_escudo
		
		if valido_para_rol and bot.global_position.distance_to((enemigo as Node3D).global_position) <= rango_deteccion_combate:
			return true
	return false
