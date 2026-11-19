class_name BotStateMachine
extends Node

@export var estado_inicial: BotState
var estado_actual: BotState
var estados: Dictionary = {}

func inicializar(bot_ref) -> void:
	for hijo in get_children():
		if hijo is BotState:
			estados[hijo.name] = hijo
			hijo.bot = bot_ref
			hijo.state_machine = self
	
	if estado_inicial != null:
		estado_actual = estado_inicial
	elif estados.has("Seguir"):
		# Respaldo: si no se asignó en el Inspector, arranca siguiendo
		estado_actual = estados["Seguir"]
	
	if estado_actual:
		estado_actual.enter()

func _physics_process(delta: float) -> void:
	if estado_actual and estado_actual.bot:
		if estado_actual.bot.estoy_muerto() or estado_actual.bot.controles_bloqueados:
			return
		estado_actual.physics_update(delta)

func cambiar_estado(nombre_estado: String, datos: Dictionary = {}) -> void:
	if not estados.has(nombre_estado):
		push_warning("[BotFSM] No existe el estado: " + nombre_estado)
		return
	
	if estado_actual:
		estado_actual.exit()
	
	estado_actual = estados[nombre_estado]
	estado_actual.enter(datos)
