class_name ZonaOrdenPuertaBot
extends Area3D

@export var boton_para_nico: Node3D
@export var boton_liberacion: Node # Botón del otro lado que suelta a Nico (en MANTENER_HASTA_CRUCE)
@export var puerta: Node
@export var tipo_cooperacion: EstadoCooperarBoton.TipoCooperacion = EstadoCooperarBoton.TipoCooperacion.MANTENER_HASTA_CRUCE

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Reacciona solo al jugador humano (ignora al bot y a enemigos)
	if not body.is_in_group("Jugador") or body.is_in_group("BotCompanero"):
		return
	
	# Si la puerta está abierta ahora mismo, no mandamos una orden innecesaria
	if is_instance_valid(puerta) and puerta.get("esta_abierta") == true:
		return
	
	var bot := get_tree().get_first_node_in_group("BotCompanero")
	if not is_instance_valid(bot):
		return
	
	# Evita reiniciar el estado si Nico ya está yendo a este mismo botón
	if bot.state_machine.estado_actual is EstadoCooperarBoton:
		if bot.state_machine.estado_actual.boton_objetivo == boton_para_nico:
			return
	
	bot.cambiar_estado("CooperarBoton", {
		"tipo": tipo_cooperacion,
		"boton": boton_para_nico,
		"boton_liberacion": boton_liberacion,
		"objetivo_estado": puerta
	})
