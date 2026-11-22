class_name EstadoEscape
extends BotState

@export var distancia_reagrupe_jugador: float = 2.2
@export var radio_evasion_enemigo: float = 6.5
@export var fuerza_desvio_enemigo: float = 3.5

var meta_escape: Node3D = null

func enter(datos: Dictionary = {}) -> void:
	meta_escape = datos.get("meta", null)
	# Guarda el arma para priorizar velocidad máxima y animación de sprint
	bot.equipar_arma(false)

func exit() -> void:
	meta_escape = null

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	# Cuando los enemigos se desactivan (llegaron al final o ZonaFinal reinició), vuelve a Seguir
	if not hay_persecucion_final_activa():
		state_machine.cambiar_estado("Seguir")
		return
	
	var destino_base: Vector3 = _obtener_destino_escape()
	if destino_base == Vector3.INF:
		bot.detener_movimiento(delta)
		return
	
	var destino_evasivo: Vector3 = _aplicar_desvio_perseguidores(destino_base)
	
	# Si ya está muy cerca del destino y no tiene enemigos encima, acompaña el ritmo
	var dist_destino: float = Vector2(
		bot.global_position.x - destino_evasivo.x,
		bot.global_position.z - destino_evasivo.z
	).length()
	
	if dist_destino > distancia_reagrupe_jugador or _enemigo_cerca():
		bot.mover_hacia(destino_evasivo, delta, true) # true = correr a velocidad_correr
	else:
		bot.detener_movimiento(delta)

func _obtener_destino_escape() -> Vector3:
	if is_instance_valid(meta_escape):
		return meta_escape.global_position
	
	var jugador: Node3D = bot.obtener_jugador_principal()
	if is_instance_valid(jugador):
		return jugador.global_position
	
	return Vector3.INF

func _aplicar_desvio_perseguidores(destino: Vector3) -> Vector3:
	var repulsion := Vector3.ZERO
	for enemigo in get_tree().get_nodes_in_group("EnemigoDelFinal"):
		if not (enemigo is Node3D) or not is_instance_valid(enemigo):
			continue
		if enemigo.get("activo") != true:
			continue
		
		var desde_enemigo: Vector3 = bot.global_position - (enemigo as Node3D).global_position
		desde_enemigo.y = 0.0
		var dist: float = desde_enemigo.length()
		if dist > 0.01 and dist < radio_evasion_enemigo:
			var peso: float = (radio_evasion_enemigo - dist) / radio_evasion_enemigo
			repulsion += desde_enemigo.normalized() * peso * fuerza_desvio_enemigo
	
	return destino + repulsion

func _enemigo_cerca() -> bool:
	for enemigo in get_tree().get_nodes_in_group("EnemigoDelFinal"):
		if not (enemigo is Node3D) or not is_instance_valid(enemigo):
			continue
		if enemigo.get("activo") != true:
			continue
		if bot.global_position.distance_to((enemigo as Node3D).global_position) <= radio_evasion_enemigo:
			return true
	return false
