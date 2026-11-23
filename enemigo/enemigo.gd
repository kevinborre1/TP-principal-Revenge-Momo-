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

@export var sonido_spawn: AudioStream
@export var sonido_muerte: AudioStream

# Para evitar 200 sonidos a la vez
static var _ultimo_spawn_sfx: Dictionary = {}
const COOLDOWN_SPAWN_MS: int = 800 # mínimo de cooldown para que vuelva a escucharse el sonido de spawn

func _ready() -> void:
	_velocidad_normal = velocidad
	_danio_normal = danio_golpe
	_cooldown_normal = cooldown_ataque
	visible = false
	_cambiar_estado_colisiones(true)
	set_physics_process(false)
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
	
	# Asignar la capa de navegación correcta según el tamaño
	if es_lider:
		nav_agent.navigation_layers = 2 # Lee el mapa donde NO cabe debajo de la mesa
		add_to_group("JefeFinal")
	else:
		nav_agent.navigation_layers = 1 # Lee el mapa normal
		add_to_group("Enemigos")
	_reproducir_sonido_spawn()
	
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not activo:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if not GameManager.papas_atacan and not perseguir_siempre:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		move_and_slide()
		manejar_animaciones()
		return

	if animation_player and animation_player.current_animation == ANIM_ATAQUE and animation_player.is_playing():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var jugador_objetivo = obtener_jugador_mas_cercano()
	tiempo_actualizacion_nav -= delta

	if jugador_objetivo:
		if tiempo_actualizacion_nav <= 0.0:
			nav_agent.target_position = jugador_objetivo.global_position
			tiempo_actualizacion_nav = INTERVALO_NAV

		var siguiente_posicion = nav_agent.get_next_path_position()
		if not nav_agent.is_navigation_finished() and global_position.distance_to(siguiente_posicion) < 0.1:
			siguiente_posicion = jugador_objetivo.global_position
		elif nav_agent.is_navigation_finished():
			siguiente_posicion = jugador_objetivo.global_position

		var posicion_mirar = Vector3(
			siguiente_posicion.x,
			global_position.y,
			siguiente_posicion.z
		)

		if global_position.distance_to(posicion_mirar) > 0.1:
			look_at(posicion_mirar, Vector3.UP)

		var direccion = global_position.direction_to(siguiente_posicion)
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
	_comprobar_colisiones_jugador()
	_ataque_a_distancia(jugador_objetivo)
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
			var tiempo_actual = Time.get_ticks_msec() / 1000.0
			
			if tiempo_actual - tiempo_ultimo_ataque >= cooldown_ataque:
				if colisionador.has_method("heridoPorEnemigo"):
					colisionador.heridoPorEnemigo(danio_golpe)
					tiempo_ultimo_ataque = tiempo_actual
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
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	if is_queued_for_deletion():
		return
	if escudo_activo:
		_romper_escudo()
		return
	vida_actual -= danio
	
	if vida_actual <= 0:
		morir()

func morir() -> void:
	if multiplayer.is_server():
		murio.emit()
	
	if Global.modo_multijugador == "linea":
		_eliminar_en_todos.rpc()
	else:
		_eliminar_en_todos()

@rpc("authority", "call_local", "reliable")
func _eliminar_en_todos() -> void:
	if muriendo or is_queued_for_deletion():
		return
	muriendo = true
	if es_lider:
		MusicManager.stop_music()
	reproducir_sfx_3d(sonido_muerte)
	SaveAndLoad.sumar_estadistica("enemigosAsesinados")
	set_physics_process(false)
	_cambiar_estado_colisiones(true)
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
	activado.emit()
	
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

@rpc("authority", "call_local", "reliable")
func set_furia(activa: bool, multiplicador_velocidad: float = 2.5, cooldown_furia: float = 0.3) -> void:
	en_furia = activa
	velocidad = _velocidad_normal * multiplicador_velocidad if activa else _velocidad_normal
	danio_golpe = _danio_normal * 3 if activa else _danio_normal
	cooldown_ataque = cooldown_furia if activa else _cooldown_normal
	if animation_player:
		animation_player.speed_scale = 3.0 if activa else 1.0

func _ataque_a_distancia(objetivo: Node3D) -> void:
	if not en_furia or objetivo == null or not is_instance_valid(objetivo):
		return
	if objetivo.get("muerto") == true:
		return
	var diferencia := objetivo.global_position - global_position
	if absf(diferencia.y) > 3.0:
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

func _reproducir_sonido_spawn() -> void:
	if sonido_spawn == null:
		return
	var ahora: int = Time.get_ticks_msec()
	var ultimo: int = _ultimo_spawn_sfx.get(sonido_spawn, -COOLDOWN_SPAWN_MS)
	if ahora - ultimo < COOLDOWN_SPAWN_MS:
		return
	_ultimo_spawn_sfx[sonido_spawn] = ahora
	reproducir_sfx_3d(sonido_spawn)
	
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.bus = &"SFX"
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 40.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
		
	var contenedor := get_tree().current_scene if get_tree().current_scene else get_tree().root
	contenedor.add_child(player_3d)
	player_3d.global_position = global_position
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
