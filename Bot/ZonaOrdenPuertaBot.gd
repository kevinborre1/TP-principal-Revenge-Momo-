class_name ZonaOrdenPuertaBot
extends Area3D

@export var boton_para_nico: Node3D
@export var boton_liberacion: Node # Para MANTENER_HASTA_CRUCE: botón del otro lado que suelta a Nico
@export var zona_cruce: Area3D # Para CRUZAR_Y_MANTENER: Area3D ubicada justo después de cruzar la puerta
@export var puerta: Node
@export var tipo_cooperacion: EstadoCooperarBoton.TipoCooperacion = EstadoCooperarBoton.TipoCooperacion.MANTENER_HASTA_CRUCE

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Reacciona solo al jugador humano (ignora al bot y a enemigos)
	if not body.is_in_group("Jugador") or body.is_in_group("BotCompanero"):
		return
	
	# En modos donde la puerta aún debe abrirse, si ya está abierta no hacemos nada.
	# En CRUZAR_Y_MANTENER la puerta se abre al pisar tu botón, así que sí debe ejecutarse.
	if tipo_cooperacion != EstadoCooperarBoton.TipoCooperacion.CRUZAR_Y_MANTENER:
		if is_instance_valid(puerta) and puerta.get("esta_abierta") == true:
			return
	
	var bot := get_tree().get_first_node_in_group("BotCompanero")
	if not is_instance_valid(bot):
		return
	
	# Si Nico ya está ejecutando una tarea cooperativa, no interrumpimos ni pisamos su estado actual
	if bot.state_machine and bot.state_machine.estado_actual is EstadoCooperarBoton:
		return
	
	bot.cambiar_estado("CooperarBoton", {
		"tipo": tipo_cooperacion,
		"boton": boton_para_nico,
		"boton_liberacion": boton_liberacion,
		"zona_cruce": zona_cruce,
		"objetivo_estado": puerta
	})
