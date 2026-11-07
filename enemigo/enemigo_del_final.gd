extends CharacterBody3D

@export var velocidad: float = 20.0
@export var perseguir_siempre: bool = true
## false = arranca apagado y lo activa la zona (Area3D). true = arranca activo (para probar)
@export var activo_al_inicio: bool = false
## Daño que le hace al jugador en cada golpe
@export var danio: float = 100.0
## Distancia a la que el enemigo frena junto al jugador
@export var distancia_parada: float = 1.2
## Distancia a la que el enemigo "toca" al jugador (tiene que ser mayor que distancia_parada)
@export var radio_contacto: float = 1.8
@export var cooldown_ataque: float = 1.0 # El enemigo hace daño cada 1 segundo
## Qué tan rápido gira hacia el jugador
@export var velocidad_giro: float = 8.0
## Si el glb no mira hacia adelante, corregilo acá en grados (probá 180, 90 o -90)
@export var offset_rotacion_modelo: float = 0.0
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
var activo: bool = false
var caminando: bool = false
var tiempo_ultimo_ataque: float = 0.0
var _transform_inicial: Transform3D
var _tiempo_debug: float = 0.0


func _ready() -> void:
	# La zona Area3D busca a los enemigos de este grupo
	add_to_group("EnemigoDelFinal")
	# Posición y rotación donde está colocado en el mapa: a donde vuelve al reiniciar
	_transform_inicial = global_transform
	if region_navegacion:
		nav_agent.navigation_layers = region_navegacion.navigation_layers
	_aplicar_estado(activo_al_inicio)


# ---------------------------------------------------------------
# Activación / desactivación (las llama la zona en cada peer)
# ---------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func activar_enemigo() -> void:
	_aplicar_estado(true)


## Lo deja invisible, sin colisión y de vuelta en su lugar inicial
@rpc("authority", "call_local", "reliable")
func desactivar_enemigo() -> void:
	_aplicar_estado(false)
	global_transform = _transform_inicial
	velocity = Vector3.ZERO
	caminando = false
	tiempo_ultimo_ataque = 0.0
	if animation_player:
		animation_player.stop()
	nav_agent.target_position = global_position


func _aplicar_estado(valor: bool) -> void:
	activo = valor
	visible = activo
	_cambiar_estado_colisiones(not activo)
	# La lógica corre solo en el servidor; los clientes reciben position/rotation
	set_physics_process(activo and multiplayer.is_server())


func _cambiar_estado_colisiones(desactivado: bool) -> void:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.set_deferred("disabled", desactivado)


# ---------------------------------------------------------------
# Movimiento (solo servidor; position y rotation las replica el MultiplayerSynchronizer)
# ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Aplicar gravedad para que no flote
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not GameManager.papas_atacan and not perseguir_siempre:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		velocity.z = move_toward(velocity.z, 0, velocidad)
		move_and_slide()
		_actualizar_caminando()
		return

	# Buscar al jugador más cercano
	var jugador_objetivo := obtener_jugador_mas_cercano()
	if jugador_objetivo:
		var a_jugador: Vector3 = jugador_objetivo.global_position - global_position
		a_jugador.y = 0.0

		# El modelo SIEMPRE mira al jugador (mientras lo persigue y cuando ya llegó)
		_mirar_a(a_jugador, delta)

		if a_jugador.length() > distancia_parada:
			# 1. Destino final: el jugador
			nav_agent.target_position = jugador_objetivo.global_position

			# 2. Siguiente paso de la ruta trazada por el NavMesh
			var siguiente_posicion: Vector3 = nav_agent.get_next_path_position()

			# 3. Se mueve hacia ese paso (la rotación ya la maneja _mirar_a)
			var direccion: Vector3 = siguiente_posicion - global_position
			direccion.y = 0.0
			if direccion.length() > 0.05:
				direccion = direccion.normalized()
				velocity.x = direccion.x * velocidad
				velocity.z = direccion.z * velocidad
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			# Ya llegó: frena
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
	_comprobar_colisiones_jugador()
	_actualizar_caminando()

	if depurar:
		_tiempo_debug -= delta
		if _tiempo_debug <= 0.0:
			_tiempo_debug = 0.5
			print("velocity=", snappedf(velocity.length(), 0.01),
				" real=", snappedf(get_real_velocity().length(), 0.01))


## Gira el cuerpo (y con él el glb) para mirar hacia 'direccion' (en el plano horizontal)
func _mirar_a(direccion: Vector3, delta: float) -> void:
	if direccion.length() < 0.01:
		return
	var yaw := atan2(-direccion.x, -direccion.z) + deg_to_rad(offset_rotacion_modelo)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(velocidad_giro * delta, 0.0, 1.0))


# ---------------------------------------------------------------
# Daño por contacto (el servidor detecta, el dueño del jugador lo recibe)
# ---------------------------------------------------------------

func _comprobar_colisiones_jugador() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - tiempo_ultimo_ataque < cooldown_ataque:
		return
	for j in get_tree().get_nodes_in_group("Jugador"):
		if not is_instance_valid(j):
			continue
		var d: Vector3 = j.global_position - global_position
		if Vector2(d.x, d.z).length() <= radio_contacto and absf(d.y) <= 1.5:
			tiempo_ultimo_ataque = ahora
			_rpc_ataque.rpc()
			_rpc_golpear_jugador.rpc_id(j.get_multiplayer_authority(), j.get_path(), danio)
			# Después de herir: la zona manda a AMBOS jugadores al marker y apaga a TODOS los
			# enemigos en todos los peers. Es diferido para no cambiar la física en pleno frame.
			get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "ZonaFinal", "reiniciar_recorrido")
			break


## Se ejecuta SOLO en el peer dueño del jugador golpeado
@rpc("authority", "call_local", "reliable")
func _rpc_golpear_jugador(ruta_jugador: NodePath, danio_recibido: float) -> void:
	var jugador := get_node_or_null(ruta_jugador)
	if jugador and jugador.has_method("heridoPorEnemigo"):
		jugador.heridoPorEnemigo(danio_recibido)


# Jugador más cercano (multijugador)
func obtener_jugador_mas_cercano() -> Node3D:
	var jugador_cercano: Node3D = null
	var distancia_minima := INF

	for j in get_tree().get_nodes_in_group("Jugador"):
		if is_instance_valid(j):
			var distancia: float = global_position.distance_to(j.global_position)
			if distancia < distancia_minima:
				distancia_minima = distancia
				jugador_cercano = j

	return jugador_cercano


# ---------------------------------------------------------------
# Animaciones (se replican a todos los peers)
# ---------------------------------------------------------------

func _actualizar_caminando() -> void:
	var se_mueve := Vector2(velocity.x, velocity.z).length() > 0.1
	if se_mueve != caminando:
		_rpc_caminando.rpc(se_mueve)


@rpc("authority", "call_local", "reliable")
func _rpc_caminando(valor: bool) -> void:
	caminando = valor
	manejar_animaciones()


@rpc("authority", "call_local", "reliable")
func _rpc_ataque() -> void:
	if animation_player and ANIM_ATAQUE != &"" and animation_player.has_animation(ANIM_ATAQUE):
		animation_player.play(ANIM_ATAQUE, 0.1)


func manejar_animaciones() -> void:
	if not animation_player or not is_instance_valid(animation_player) or ANIM_CAMINAR == &"":
		return
	# No cortar el golpe a la mitad
	if ANIM_ATAQUE != &"" and animation_player.current_animation == ANIM_ATAQUE \
			and animation_player.is_playing():
		return

	if caminando and animation_player.has_animation(ANIM_CAMINAR):
		animation_player.play(ANIM_CAMINAR, 0.2)
	else:
		animation_player.stop()
