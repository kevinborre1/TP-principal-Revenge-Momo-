extends CharacterBody3D

var velocidad: float = 1
@export var perseguir_siempre: bool = true
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var activo: bool = true 
var ANIM_CAMINAR = ""
var ANIM_ATAQUE = ""
@onready var nav_region: NavigationRegion3D = $"../NavigationRegion3D"
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer
var tiempo_ultimo_ataque: float = 0.0
var cooldown_ataque: float = 1.0 # El enemigo hace daño cada 1 segundo


func _ready() -> void:
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true) 
	animation_player = $momo_chicken/AnimationPlayer

func _physics_process(delta: float) -> void:
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

	# Buscar al jugador más cercano
	var jugador_objetivo = obtener_jugador_mas_cercano()
	if jugador_objetivo:
		# 1. Le decimos al agente cuál es el destino final (el jugador)
		nav_agent.target_position = jugador_objetivo.global_position
		
		# 2. Obtenemos el siguiente paso en la ruta trazada por el NavMesh
		var siguiente_posicion = nav_agent.get_next_path_position()
		
		# 3. Orientamos al enemigo hacia ese siguiente paso (ignorando el eje Y)
		var posicion_mirar = Vector3(siguiente_posicion.x, global_position.y, siguiente_posicion.z)
		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)

		# 4. Calculamos la dirección y aplicamos la velocidad
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
		
		# Comprobamos si con lo que chocamos es el Player (por clase o grupo)
		if colisionador is Player or colisionador.is_in_group("Jugador"):
			var tiempo_actual = Time.get_ticks_msec() / 1000.0
			
			# Comprobamos si ya pasó el tiempo de cooldown
			if tiempo_actual - tiempo_ultimo_ataque >= cooldown_ataque:
				if colisionador.has_method("heridoPorEnemigo"):
					# Llamamos a la función de daño del Player
					colisionador.heridoPorEnemigo() 
					tiempo_ultimo_ataque = tiempo_actual
					_reproducir_ataque()

# Función para encontrar al jugador más cercano en juegos multijugador
func obtener_jugador_mas_cercano() -> Node3D:
	# Obtenemos todos los nodos que asignamos al grupo "jugadores"
	var jugadores = get_tree().get_nodes_in_group("Jugador") # ¡OJO AQUÍ! Lo cambié a "Jugador" con mayúscula porque así lo tienes en el _ready de tu script Player
	
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

func _reproducir_ataque() -> void:
	if animation_player and animation_player.has_animation(ANIM_ATAQUE):
		animation_player.play(ANIM_ATAQUE, 0.1)

func manejar_animaciones() -> void:
	if not animation_player or not is_instance_valid(animation_player):
		return
	# No cortar el golpe a la mitad
	if animation_player.current_animation == ANIM_ATAQUE and animation_player.is_playing():
		return
	
	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()
	
	if velocidad_horizontal > 0.1:
		animation_player.play(ANIM_CAMINAR, 0.2)
	else:
		animation_player.stop()

#puede ser authority
@rpc("any_peer", "call_local", "reliable")
func activar_enemigo() -> void:
	activo = true
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true)
	
