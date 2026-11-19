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
