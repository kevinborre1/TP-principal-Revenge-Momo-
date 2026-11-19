extends BotState

@export var grupo_carteles: String = "CartelesColores"
var gestor_minijuego: Node = null # Referencia a tu nodo MiniJuegoColore
var cartel_objetivo: Node3D = null

func enter(datos: Dictionary = {}) -> void:
	gestor_minijuego = datos.get("gestor_minijuego", null)
	cartel_objetivo = null

func physics_update(delta: float) -> void:
	if not is_instance_valid(gestor_minijuego):
		state_machine.cambiar_estado("Seguir")
		return
	
	# TODO: Reemplazá "color_letra_actual" por el nombre real de la variable/método
	# en tu script de MiniJuegoColore que guarda el color de la letra de la pantalla principal
	var color_buscado = gestor_minijuego.get("color_letra_actual")
	if color_buscado == null:
		return
	
	cartel_objetivo = _buscar_cartel_por_color(color_buscado)
	if is_instance_valid(cartel_objetivo):
		# Se posiciona a una distancia cómoda de disparo y apunta al cartel
		var dist := bot.global_position.distance_to(cartel_objetivo.global_position)
		if dist > 12.0:
			bot.mover_hacia(cartel_objetivo.global_position, delta, true)
		else:
			bot.detener_movimiento(delta)
			bot.disparar_a(cartel_objetivo, delta)

func _buscar_cartel_por_color(color_buscado) -> Node3D:
	for cartel in get_tree().get_nodes_in_group(grupo_carteles):
		if is_instance_valid(cartel) and cartel.get("color_cartel") == color_buscado:
			return cartel
	return null
