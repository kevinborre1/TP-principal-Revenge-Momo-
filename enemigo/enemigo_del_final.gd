extends CharacterBody3D

@export var velocidad: float = 4.0
@export var perseguir_siempre: bool = true
## Distancia a la que el enemigo frena junto al jugador
@export var distancia_parada: float = 1.2
## Distancia a la que el enemigo "toca" al jugador (tiene que ser mayor que distancia_parada)
@export var radio_contacto: float = 1.8
@export var cooldown_ataque: float = 1.0 # El enemigo hace daño cada 1 segundo
## NOMBRES de animaciones (los ves en el AnimationPlayer). Vacío = no anima
@export var ANIM_CAMINAR: StringName = &""
@export var ANIM_ATAQUE: StringName = &""
## Opcional: región de navegación que usa este enemigo (copia su capa al agente)
@export var region_navegacion: NavigationRegion3D
## Imprime la velocidad cada 0.5 s para depurar
@export var depurar: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var activo: bool = true
var tiempo_ultimo_ataque: float = 0.0
var _tiempo_debug: float = 0.0


func _ready() -> void:
	visible = true
	_cambiar_estado_colisiones(false)
	set_physics_process(true)
	if region_navegacion:
		nav_agent.navigation_layers = region_navegacion.navigation_layers
	for n in find_children("*", "CollisionObject3D", true, false):
		print("COLISIONADOR HIJO: ", n.get_path(), " layer=", n.collision_layer)


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
		manejar_animaciones() # animación de quieto
		return

	# Buscar al jugador más cercano
	var jugador_objetivo = obtener_jugador_mas_cercano()
	if jugador_objetivo:
		var a_jugador: Vector3 = jugador_objetivo.global_position - global_position
		a_jugador.y = 0.0

		if a_jugador.length() > distancia_parada:
			# 1. Destino final: el jugador
			nav_agent.target_position = jugador_objetivo.global_position

			# 2. Siguiente paso de la ruta trazada por el NavMesh
			var siguiente_posicion: Vector3 = nav_agent.get_next_path_position()

			# 3. Dirección horizontal hacia ese paso
			var direccion: Vector3 = siguiente_posicion - global_position
			direccion.y = 0.0
			if direccion.length() > 0.05:
				direccion = direccion.normalized()
				velocity.x = direccion.x * velocidad
				velocity.z = direccion.z * velocidad
				# Si tu modelo mira hacia +Z, usá atan2(direccion.x, direccion.z)
				rotation.y = lerp_angle(rotation.y, atan2(-direccion.x, -direccion.z), delta * 8.0)
		else:
			# Ya llegó: frena y mira al jugador
			velocity.x = 0.0
			velocity.z = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(-a_jugador.x, -a_jugador.z), delta * 8.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
	_comprobar_colisiones_jugador()
	manejar_animaciones()

	if depurar:
		_tiempo_debug -= delta
		if _tiempo_debug <= 0.0:
			_tiempo_debug = 0.5
			print("velocity=", snappedf(velocity.length(), 0.01),
				" real=", snappedf(get_real_velocity().length(), 0.01))
		print("platform_vel=", get_platform_velocity())
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			print("  choca con: ", c.get_collider().get_path())


func _cambiar_estado_colisiones(desactivado: bool) -> void:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.disabled = desactivado


# Daño por distancia (ya no depende del choque entre cuerpos)
func _comprobar_colisiones_jugador() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - tiempo_ultimo_ataque < cooldown_ataque:
		return
	for j in get_tree().get_nodes_in_group("Jugador"):
		if not is_instance_valid(j) or not j.has_method("heridoPorEnemigo"):
			continue
		var d: Vector3 = j.global_position - global_position
		if Vector2(d.x, d.z).length() <= radio_contacto and absf(d.y) <= 1.5:
			j.heridoPorEnemigo()
			tiempo_ultimo_ataque = ahora
			_reproducir_ataque()
			break


# Jugador más cercano (multijugador)
func obtener_jugador_mas_cercano() -> Node3D:
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	if jugadores.is_empty():
		return null

	var jugador_cercano: Node3D = null
	var distancia_minima = INF

	for j in jugadores:
		if is_instance_valid(j):
			var distancia = global_position.distance_to(j.global_position)
			if distancia < distancia_minima:
				distancia_minima = distancia
				jugador_cercano = j

	return jugador_cercano


func _reproducir_ataque() -> void:
	if animation_player and ANIM_ATAQUE != &"" and animation_player.has_animation(ANIM_ATAQUE):
		animation_player.play(ANIM_ATAQUE, 0.1)


func manejar_animaciones() -> void:
	if not animation_player or not is_instance_valid(animation_player) or ANIM_CAMINAR == &"":
		return
	# No cortar el golpe a la mitad
	if ANIM_ATAQUE != &"" and animation_player.current_animation == ANIM_ATAQUE \
			and animation_player.is_playing():
		return

	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()

	if velocidad_horizontal > 0.1 and animation_player.has_animation(ANIM_CAMINAR):
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
