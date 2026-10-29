extends CharacterBody3D

var velocidad: float = 3.5
@export var perseguir_siempre: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var vida_maxima: int = 20
var vida_actual: int = vida_maxima
@export var es_lider: bool = false
var activo: bool = false 
const ANIM_CAMINAR = "mixamo_com"
const ANIM_ATAQUE = "papa_ataque/mixamo_com"
const ANIM_MUERTE = "papa_muerte/mixamo_com"
var muriendo: bool = false
signal murio

@onready var animation_player: AnimationPlayer

# Variables para controlar el daño
var tiempo_ultimo_ataque: float = 0.0
var cooldown_ataque: float = 1.0 # El enemigo hace daño cada 1 segundo


func _ready() -> void:
	visible = false
	_cambiar_estado_colisiones(true)
	set_physics_process(false) # apagamos las fisicas de los enemigos al empezar hasta que se activen
	if not es_lider:
		animation_player = $papitas/AnimationPlayer
		
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
	
	# Perseguir al jugador si existe
	if jugador_objetivo:
		var posicion_mirar = Vector3(jugador_objetivo.global_position.x, global_position.y, jugador_objetivo.global_position.z)
		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)

		var direccion_adelante = -global_transform.basis.z
		velocity.x = direccion_adelante.x * velocidad
		velocity.z = direccion_adelante.z * velocidad
		
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


@rpc("any_peer", "call_local", "reliable")
func _daniar(danio: int) -> void:
	if muriendo:
		return
	# En línea solo el host resuelve el daño: las balas existen en todos los peers
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	if is_queued_for_deletion():
		return
	vida_actual -= danio
	print("¡El enemigo recibió un disparo! Daño:", danio, " | Vida restante:", vida_actual)
	
	if vida_actual <= 0:
		morir()

func morir() -> void:
	if multiplayer.is_server():
		murio.emit()
	
	if Global.modo_multijugador == "linea":
		_eliminar_en_todos.rpc()
	else:
		_eliminar_en_todos()

# El host la llama para borrar la papita en todos los peers
@rpc("authority", "call_local", "reliable")
func _eliminar_en_todos() -> void:
	if muriendo or is_queued_for_deletion():
		return
	muriendo = true
	SaveAndLoad.sumar_estadistica("enemigosAsesinados")
	set_physics_process(false)
	_cambiar_estado_colisiones(true)  # las balas y el jugador ya no chocan con ella
	if animation_player and animation_player.has_animation(ANIM_MUERTE):
		animation_player.play(ANIM_MUERTE, 0.1)
		await get_tree().create_timer(animation_player.current_animation_length).timeout
	queue_free()

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

#puede ser authority
@rpc("any_peer", "call_local", "reliable")
func activar_enemigo() -> void:
	activo = true
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true)
