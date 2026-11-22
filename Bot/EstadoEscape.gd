extends BotState

var punto_salida: Node3D = null

func enter(datos: Dictionary = {}) -> void:
	punto_salida = datos.get("punto_salida", null)

func physics_update(delta: float) -> void:
	# Si tiene una meta fija y el jugador está cerca, corre hacia la salida;
	# si se alejó del jugador, prioriza mantenerse pegado a él para no perderse.
	var destino: Vector3
	if is_instance_valid(punto_salida):
		destino = punto_salida.global_position
	elif is_instance_valid(bot.jugador_principal):
		destino = bot.jugador_principal.global_position
	else:
		return
	
	bot.mover_hacia(destino, delta, true) # correr = true siempre
