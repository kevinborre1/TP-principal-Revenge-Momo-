extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.5

var is_controlled = false
var player_is_near = false
var player_node: Node3D = null

func _physics_process(delta: float) -> void:
	# Para subir y bajar de la balsa
	if Input.is_action_just_pressed("Abordar"):
		
		if is_controlled:
			# BAJAR: Nos bajamos de la balsa
			is_controlled = false
			
			# Devolvemos al jugador a la escena principal de forma segura
			player_node.reparent(get_tree().current_scene)
			
			# Reactivamos sus físicas y sus controles (desbloqueamos input)
			player_node.set_physics_process(true)
			if "input_bloqueado" in player_node:
				player_node.input_bloqueado = false
			
			# Empujamos al jugador a la derecha para que no se fusione con la madera
			player_node.global_position = global_position + (transform.basis.x * 2.5)
			
		elif player_is_near and player_node != null:
			# SUBIR: Nos subimos a la balsa
			is_controlled = true
			
			# Bloqueamos el input del jugador para que no mueva la cámara mientras navega
			if "input_bloqueado" in player_node:
				player_node.input_bloqueado = true
				
			player_node.reparent(self)
			player_node.set_physics_process(false)
			
			# Lo centramos ordenadamente en la balsa
			player_node.position = Vector3(0, 1.0, 0)
			# Opcional: Reiniciamos la rotación local respecto a la balsa para que mire hacia adelante
			player_node.rotation = Vector3.ZERO
	
	# Si no está siendo controlada, la balsa no hace nada
	if not is_controlled:
		return
	
	# Movimiento de la balsa
	var turn_input = Input.get_axis("Derecha", "Izquierda")
	rotation.y += turn_input * turn_speed * delta

	var move_input = Input.get_axis("Atras", "Adelante")
	var forward_direction = -transform.basis.z
	
	velocity = forward_direction * move_input * speed
	move_and_slide()

# Conexión del área de abordaje
func _on_zona_abordaje_body_entered(body: Node3D) -> void:  
	if body.is_in_group("jugadores") or body.is_in_group("Jugador"):
		player_is_near = true
		player_node = body

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	if body == player_node:
		player_is_near = false
		# No borramos player_node aquí por si acaso sale mientras está controlando (aunque no debería)
