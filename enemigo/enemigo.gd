extends CharacterBody3D

var velocidad: float = 3.5
@export var perseguir_siempre: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var vida_maxima: int = 20
var vida_actual: int = vida_maxima
@export var es_lider: bool = false
@export var danio_golpe: int = 10
@export var alcance_furia: float = 6.0 # en furia pega a esta distancia aunque no toque al jugador
var activo: bool = false 
var ANIM_CAMINAR = "mixamo_com"
var ANIM_ATAQUE = "papa_ataque/mixamo_com"
var ANIM_MUERTE = "papa_muerte/mixamo_com"
var muriendo: bool = false
@export var tiene_escudo: bool = true
@export var tiempo_regeneracion_escudo: float = 3.0
var escudo_activo: bool = false
var _timer_escudo: Timer
@onready var malla_escudo: Node3D = get_node_or_null("Escudo")

var tiempo_actualizacion_nav: float = 0.0
const INTERVALO_NAV: float = 0.5

signal activado
@export var solo_danio_por_pantallas: bool = false # el líder del bar solo muere con el minijuego de colores
signal murio

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer

# Variables para controlar el daño
var tiempo_ultimo_ataque: float = 0.0
var cooldown_ataque: float = 1.0 # El enemigo hace daño cada 1 segundo
var en_furia: bool = false
var _velocidad_normal: float
var _danio_normal: int
var _cooldown_normal: float


func _ready() -> void:
	_velocidad_normal = velocidad
	_danio_normal = danio_golpe
	_cooldown_normal = cooldown_ataque
	visible = false
	_cambiar_estado_colisiones(true)
	set_physics_process(false) # apagamos las fisicas de los enemigos al empezar hasta que se activen
	if es_lider:
		animation_player = $patato/AnimationPlayer
		ANIM_ATAQUE = "lider_ataque/mixamo_com"
		ANIM_MUERTE = "lider_muerte/mixamo_com"
	else:
		animation_player = $papitas/AnimationPlayer
		ANIM_CAMINAR = "Caminar"
		ANIM_ATAQUE = "Golpe"
		ANIM_MUERTE = "Muerte"
	
	# El escudo es solo para las papitas chicas
	_timer_escudo = Timer.new()
	_timer_escudo.one_shot = true
	_timer_escudo.wait_time = tiempo_regeneracion_escudo
	_timer_escudo.timeout.connect(_regenerar_escudo)
	add_child(_timer_escudo)
	_set_escudo(tiene_escudo and not es_lider)
	
	# NUEVO: Asignar la capa de navegación correcta según el tamaño
	if es_lider:
		nav_agent.navigation_layers = 1 # Lee el mapa donde NO cabe debajo de la mesa
	else:
		nav_agent.navigation_layers = 2 # Lee el mapa normal
		
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not activo:
		return

	# Aplicar gravedad para que no flote
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Si los enemigos no están atacando, quedarse quietos
	if not GameManager.papas_atacan and not perseguir_siempre:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		move_and_slide()
		manejar_animaciones()
		return

	# Mientras pega, se queda quieto hasta terminar la animación
	if animation_player and animation_player.current_animation == ANIM_ATAQUE and animation_player.is_playing():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Buscar al jugador más cercano
	var jugador_objetivo = obtener_jugador_mas_cercano()
	
	# Controlar el intervalo de actualización de navegación
	tiempo_actualizacion_nav -= delta

	if jugador_objetivo:
		# Actualizar el destino cada 0.2 segundos
		if tiempo_actualizacion_nav <= 0.0:
			nav_agent.target_position = jugador_objetivo.global_position
			tiempo_actualizacion_nav = INTERVALO_NAV

		# Obtener el siguiente punto de navegación
		var siguiente_posicion = nav_agent.get_next_path_position()
		#Para cuando no hay NavMesh
		# SI NO HAY NAVMESH EN LA ESCENA
		if not nav_agent.is_navigation_finished() and global_position.distance_to(siguiente_posicion) < 0.1:
			siguiente_posicion = jugador_objetivo.global_position
		elif nav_agent.is_navigation_finished():
			siguiente_posicion = jugador_objetivo.global_position

		# Orientar al enemigo hacia el siguiente punto
		var posicion_mirar = Vector3(
			siguiente_posicion.x,
			global_position.y,
			siguiente_posicion.z
		)

		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)

		# Calcular la dirección y aplicar velocidad
		var direccion = global_position.direction_to(siguiente_posicion)
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad

	else:
		# Si no hay jugadores, detener el movimiento horizontal
		velocity.x = 0.0
		velocity.z = 0.0

	# Aplicar movimiento
	move_and_slide()
	# Comprobar colisiones con jugadores
	_comprobar_colisiones_jugador()
	# Ataque especial del líder
	_ataque_a_distancia(jugador_objetivo)
	# Actualizar animaciones
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
					colisionador.heridoPorEnemigo(danio_golpe)
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

# Las balas de jugador entran por acá: el tipo decide si rompe el escudo o hace daño
func recibir_bala(danio: int, tipo: String) -> void:
	if solo_danio_por_pantallas:
		return
	if muriendo or is_queued_for_deletion():
		return
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	if escudo_activo:
		if tipo != "letal":
			_romper_escudo()
		return
	if tipo != "rompe_escudo":
		_daniar(danio)

@rpc("any_peer", "call_local", "reliable")
func _daniar(danio: int) -> void:
	if muriendo:
		return
	# En línea solo el host resuelve el daño: las balas existen en todos los peers
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	if is_queued_for_deletion():
		return
	if escudo_activo:
		_romper_escudo()
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
	activado.emit()
	
# Solo el host llega acá (en línea _daniar corta antes en los clientes)
func _romper_escudo() -> void:
	_set_escudo.rpc(false)
	_timer_escudo.start()

func _regenerar_escudo() -> void:
	if muriendo:
		return
	_set_escudo.rpc(true)

@rpc("authority", "call_local", "reliable")
func _set_escudo(valor: bool) -> void:
	escudo_activo = valor
	if malla_escudo:
		malla_escudo.visible = valor

# El minijuego de colores pone al líder en furia: más rápido y pega más seguido
@rpc("authority", "call_local", "reliable")
func set_furia(activa: bool, multiplicador_velocidad: float = 2.5, cooldown_furia: float = 0.3) -> void:
	en_furia = activa
	velocidad = _velocidad_normal * multiplicador_velocidad if activa else _velocidad_normal
	danio_golpe = _danio_normal * 3 if activa else _danio_normal
	cooldown_ataque = cooldown_furia if activa else _cooldown_normal
	if animation_player:
		animation_player.speed_scale = 3.0 if activa else 1.0

# En furia golpea a los jugadores cercanos aunque no los toque (por ejemplo, escondidos bajo una mesa)
func _ataque_a_distancia(objetivo: Node3D) -> void:
	if not en_furia or objetivo == null or not is_instance_valid(objetivo):
		return
	if objetivo.get("muerto") == true:
		return
	var diferencia := objetivo.global_position - global_position
	if absf(diferencia.y) > 3.0: # no pegar a través de pisos
		return
	var distancia := Vector2(diferencia.x, diferencia.z).length()
	if distancia > alcance_furia or distancia < 0.1:
		return
	var tiempo_actual := Time.get_ticks_msec() / 1000.0
	if tiempo_actual - tiempo_ultimo_ataque < cooldown_ataque:
		return
	if objetivo.has_method("heridoPorEnemigo"):
		look_at(Vector3(objetivo.global_position.x, global_position.y, objetivo.global_position.z), Vector3.UP)
		objetivo.heridoPorEnemigo(danio_golpe)
		tiempo_ultimo_ataque = tiempo_actual
		_reproducir_ataque()
