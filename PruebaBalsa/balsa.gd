extends CharacterBody3D


# exporto estas variables para poder cambiarlas desde el inspector sin necesidad de abrir el script.
@export var speed: float = 5.0
@export var turn_speed: float = 2.5

# comprobamos si esta siendo controlado y tiene un personaje cerca
var is_controlled = false
var player_is_near = false
var player_node: Node3D = null

func _physics_process(delta: float) -> void:
	# para subir y bajar de la balsa (la tecla que se va a usar)
	if Input.is_action_just_pressed("Abordar"):
		
		if is_controlled:
			# bajar: Si ya estamos manejando, nos bajamos directamente
			is_controlled = false
			player_node.reparent(get_parent())
			player_node.set_physics_process(true)
			
			# empujamos al jugador un poco a la derecha (eje X) al bajarse.
			# Si lo dejas en el centro (0,0), se fusionará con la madera y saldrá volando.
			player_node.global_position = global_position + (transform.basis.x * 2.5)
			
		elif player_is_near:
			# subir: Si no manejamos pero estamos cerca, nos subimos
			is_controlled = true
			player_node.reparent(self)
			player_node.set_physics_process(false)
			player_node.position = Vector3(0, 1.0, 0)
	
	# para bloquear el movimiento si no hay nadie arriba
	if not is_controlled:
		return
	
	# movimiento de la balsa
	# rotacion (izquierda / derecha)
	var turn_input = Input.get_axis("Derecha", "Izquierda")
	rotation.y += turn_input * turn_speed * delta

	# avance (adelante / atras)
	var move_input = Input.get_axis("Atras", "Adelante")
	
	# En Godot, la parte delantera de un objeto es el eje Z negativo
	var forward_direction = -transform.basis.z
	
	# aplicar velocidad y mover
	velocity = forward_direction * move_input * speed
	move_and_slide()
	
# para conectar el area 3d
func _on_zona_abordaje_body_entered(body: Node3D) -> void: 
	if body.name == "Player":
		player_is_near = true
		player_node = body

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_is_near = false
