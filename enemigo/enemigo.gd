extends CharacterBody3D

const SPEED = 3.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad para que no flote
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Buscar al jugador más cercano
	var jugador_objetivo = obtener_jugador_mas_cercano()

	# 3. Perseguir al jugador si existe
	if jugador_objetivo:
		# Hacer que el enemigo mire hacia el jugador
		var posicion_mirar = Vector3(jugador_objetivo.global_position.x, global_position.y, jugador_objetivo.global_position.z)
		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)

		# Avanzar hacia ADELANTE en su eje local (-basis.z)
		var direccion_adelante = -global_transform.basis.z
		velocity.x = direccion_adelante.x * SPEED
		velocity.z = direccion_adelante.z * SPEED
		

	move_and_slide()

# Función para encontrar al jugador más cercano en juegos multijugador
func obtener_jugador_mas_cercano() -> Node3D:
	# Obtenemos todos los nodos que asignamos al grupo "jugadores"
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	
	if jugadores.is_empty():
		return null
		
	var jugador_cercano = null
	var distancia_minima = INF
	
	# Comparamos la distancia con cada jugador en el mapa
	for j in jugadores:
		if is_instance_valid(j):
			var distancia = global_position.distance_to(j.global_position)
			if distancia < distancia_minima:
				distancia_minima = distancia
				jugador_cercano = j
				
	return jugador_cercano
