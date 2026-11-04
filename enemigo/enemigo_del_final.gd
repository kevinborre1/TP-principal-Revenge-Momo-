extends CharacterBody3D

var velocidad: float = 3.5
@export var perseguir_siempre: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var activo: bool = false 
var ANIM_CAMINAR = "mixamo_com"
var ANIM_ATAQUE = ""
var ANIM_MUERTE = ""
var muriendo: bool = false

@onready var nav_agent: NavigationAgent3D
@onready var animation_player: AnimationPlayer

func _ready() -> void:
	visible = true
	_cambiar_estado_colisiones(true)
	set_physics_process(true) # apagamos las fisicas de los enemigos al empezar hasta que se activen
	animation_player = $Walking/AnimationPlayer
func _physics_process(delta: float) -> void:
	print(global_position)
	if not multiplayer.is_server() or not activo:
		return
# Aplicar gravedad para que no flote
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not GameManager.papas_atacan and not perseguir_siempre:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		move_and_slide()
		manejar_animaciones() # llamamos a la animacion de quieto
		return
	var jugador_objetivo = obtener_jugador_mas_cercano()
	if jugador_objetivo:
		nav_agent.target_position = jugador_objetivo.global_position
		var siguiente_posicion = nav_agent.get_next_path_position()
		var posicion_mirar = Vector3(siguiente_posicion.x, global_position.y, siguiente_posicion.z)
		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)
		var direccion = global_position.direction_to(siguiente_posicion)
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
	move_and_slide()
	_comprobar_colisiones_jugador()
	manejar_animaciones()

func _cambiar_estado_colisiones(desactivado: bool) -> void:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.disabled = desactivado

func _comprobar_colisiones_jugador() -> void:
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var colisionador = colision.get_collider()
		
		if colisionador is Player or colisionador.is_in_group("Jugador"):
			if colisionador.has_method("heridoPorEnemigo"):
				colisionador.heridoPorEnemigo() 
				_reproducir_ataque()

func obtener_jugador_mas_cercano() -> Node3D:
	var jugadores = get_tree().get_nodes_in_group("Jugador") 
	if jugadores.is_empty():
		return null
		
	var jugador_cercano = null
	var distancia_minima = INF
	
	for j in jugadores:
		if is_instance_valid(j):
			var distancia = global_position.distance_to(j.global_position)
			if distancia < distancia_minima:
				distancia_minima = distancia
				jugador_cercano = j
				
	return jugador_cercano

func _reproducir_ataque() -> void:
	if animation_player and animation_player.has_animation(ANIM_ATAQUE):
		animation_player.play(ANIM_ATAQUE, 0.1)

func manejar_animaciones() -> void:
	if not animation_player or not is_instance_valid(animation_player) or muriendo:
		return
	# No cortar el golpe a la mitad
	if animation_player.current_animation == ANIM_ATAQUE and animation_player.is_playing():
		return
	
	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()
	
	if velocidad_horizontal > 0.1:
		animation_player.play(ANIM_CAMINAR, 0.2)
	else:
		animation_player.stop()

@rpc("any_peer", "call_local", "reliable")
func activar_enemigo() -> void:
	activo = true
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true)
