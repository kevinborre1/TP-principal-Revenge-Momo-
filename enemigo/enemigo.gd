extends CharacterBody3D

var velocidad: float = 3.5
@export var perseguir_siempre: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var vida_maxima: int = 20
var vida_actual: int = vida_maxima
@export var es_lider: bool = false
var activo: bool = false 
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
	vida_actual -= danio
	print("¡El enemigo recibió un disparo! Daño:", danio, " | Vida restante:", vida_actual)
	
	# Aquí puedes agregar efectos visuales, partículas de impacto o sangre en "transformacion_bala.origin"
	
	if vida_actual <= 0:
		SaveAndLoad.sumar_estadistica("enemigosAsesinados")
		morir()

func morir() -> void:
	if multiplayer.is_server():
		murio.emit()
	
	set_physics_process(false)
	queue_free()

func manejar_animaciones() -> void:
	# Comprobamos si el enemigo se está moviendo en el plano horizontal (X, Z)
	if not animation_player or not is_instance_valid(animation_player):
		return
		
	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()
	
	if velocidad_horizontal > 0.1:
		animation_player.play("2165105689072_TempMotion") 
	else:
		animation_player.stop()

#puede ser authority
@rpc("any_peer", "call_local", "reliable")
func activar_enemigo() -> void:
	activo = true
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true)
