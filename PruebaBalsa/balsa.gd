extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.5

var is_controlled = false
var player_is_near = false
var player_node: Node3D = null

func _physics_process(delta: float) -> void:
	# 1. LÓGICA DE ABORDAR (Inputs locales)
	if Input.is_action_just_pressed("Abordar"):
		if is_controlled:
			# BAJAR: Si está controlada y YO soy el piloto, me bajo
			if is_multiplayer_authority():
				rpc_abordar_balsa.rpc(1, false) # Devuelve la autoridad al servidor (ID 1)
				
		elif player_is_near and player_node != null:
			# SUBIR: Si no está controlada y YO soy el jugador que está cerca
			# Comprobamos que el jugador cerca sea el nuestro (comparando el nombre con nuestro ID)
			if player_node.name == str(multiplayer.get_unique_id()):
				rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), true)
	
	# 2. MOVIMIENTO FÍSICO
	# Si no está siendo controlada, o si NO somos el piloto, no calculamos el movimiento
	if not is_controlled or not is_multiplayer_authority():
		return
	
	# Movimiento de la balsa (Solo lo ejecuta el piloto)
	var turn_input = Input.get_axis("Derecha", "Izquierda")
	rotation.y += turn_input * turn_speed * delta

	var move_input = Input.get_axis("Atras", "Adelante")
	var forward_direction = -transform.basis.z
	
	velocity = forward_direction * move_input * speed
	move_and_slide()


# Lógica de sincronización para subirse y bajarse
@rpc("any_peer", "call_local", "reliable")
func rpc_abordar_balsa(id_jugador: int, subiendo: bool) -> void:
	# Buscamos al jugador exacto en el árbol de escenas por su ID
	var jugador_objetivo = get_tree().current_scene.find_child(str(id_jugador), true, false)
	
	if subiendo:
		# Le damos la autoridad de la balsa al jugador que se sube
		set_multiplayer_authority(id_jugador)
		is_controlled = true
		
		if jugador_objetivo:
			player_node = jugador_objetivo
			if "input_bloqueado" in player_node:
				player_node.input_bloqueado = true
				
			player_node.reparent(self, false)
			player_node.set_physics_process(false)
			player_node.position = Vector3(0, 1.0, 0)
			
			if player_node.has_method("prepare_for_raft"):
				player_node.prepare_for_raft()
				
	else:
		# Devolvemos la autoridad de la balsa al host/servidor
		set_multiplayer_authority(1)
		is_controlled = false
		
		if player_node:
			player_node.reparent(get_tree().current_scene, false)
			player_node.set_physics_process(true)
			
			if "input_bloqueado" in player_node:
				player_node.input_bloqueado = false
			
			player_node.global_position = global_position + (transform.basis.x * 2.5)


# Conexión del área de abordaje
func _on_zona_abordaje_body_entered(body: Node3D) -> void:  
	if body.is_in_group("jugadores") or body.is_in_group("Jugador"):
		player_is_near = true
		player_node = body

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	if body == player_node:
		player_is_near = false
