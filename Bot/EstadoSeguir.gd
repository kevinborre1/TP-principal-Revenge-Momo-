extends BotState

@export var distancia_minima: float = 2.8
@export var distancia_correr: float = 7.0

func physics_update(delta: float) -> void:
	var jugador: Node3D = bot.obtener_jugador_principal()
	if not is_instance_valid(jugador):
		# Aunque el jugador todavía no haya aparecido, aplicamos gravedad para que no flote
		bot.detener_movimiento(delta)
		return
	
	var dist := bot.global_position.distance_to(jugador.global_position)
	if dist > distancia_minima:
		bot.mover_hacia(jugador.global_position, delta, dist > distancia_correr)
	else:
		bot.detener_movimiento(delta)
