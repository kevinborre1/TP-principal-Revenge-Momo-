class_name BotState
extends Node

var bot: BotNico
var state_machine: BotStateMachine

# Se ejecuta una vez al entrar al estado. 'datos' permite pasar parámetros (ej. qué botón pisar).
func enter(_datos: Dictionary = {}) -> void:
	pass

# Se ejecuta una vez al salir del estado (ideal para limpiar timers o referencias).
func exit() -> void:
	pass

# Se ejecuta en cada frame de física.
func physics_update(_delta: float) -> void:
	pass

func jefe_esta_activo(jefe: Node3D) -> bool:
	if not is_instance_valid(jefe) or not jefe.visible:
		return false
	if jefe.has_method("esta_en_combate"):
		return jefe.esta_en_combate()
	if "activo" in jefe:
		return jefe.get("activo") == true and jefe.get("muriendo") != true
	if "fase" in jefe:
		return int(jefe.get("fase")) != 3
	return false

func obtener_posicion_jefe(jefe: Node3D) -> Vector3:
	if not is_instance_valid(jefe):
		return Vector3.ZERO
	if jefe.has_method("obtener_centro_real"):
		return jefe.obtener_centro_real()
	return jefe.global_position

func hay_persecucion_final_activa() -> bool:
	for enemigo in get_tree().get_nodes_in_group("EnemigoDelFinal"):
		if is_instance_valid(enemigo) and enemigo.get("activo") == true:
			return true
	return false
