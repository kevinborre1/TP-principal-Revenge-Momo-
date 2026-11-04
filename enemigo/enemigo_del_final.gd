class_name Enemigo
extends CharacterBody3D

@export var velocidad: float = 3.5
@export var perseguir_siempre: bool = true
## true = arranca activo (útil para probar). false = espera a activar_enemigo.rpc()
@export var activo_al_inicio: bool = true
@export var cooldown_danio: float = 1.0
## Distancia a la que el enemigo "toca" al jugador
@export var radio_contacto: float = 1.2
@export var anim_caminar: StringName = &"mixamo_com"
@export var anim_ataque: StringName = &""
## Marker3D en el centro de cada curva del camino
@export var esquinas: Array[Marker3D] = []
## Capa de colisión donde están las paredes (no el suelo)
@export_flags_3d_physics var mascara_paredes: int = 2

@onready var animation_player: AnimationPlayer = $Walking/AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var activo: bool = false
var caminando: bool = false
var _puede_danar: bool = true
var _destino: Vector3
var _tiempo_ruta: float = 0.0


func _ready() -> void:
	floor_snap_length = 0.5
	_destino = global_position
	_aplicar_estado(activo_al_inicio)
	print(name, " | activo=", activo, " | visible=", visible)


# ---------------------------------------------------------------
# RPC (solo el servidor los llama; se ejecutan en todos los peers)
# ---------------------------------------------------------------

## Llamar desde el servidor: enemigo.activar_enemigo.rpc()
@rpc("authority", "call_local", "reliable")
func activar_enemigo() -> void:
	_aplicar_estado(true)


@rpc("authority", "call_local", "reliable")
func _rpc_caminando(valor: bool) -> void:
	caminando = valor
	_actualizar_animacion()


@rpc("authority", "call_local", "reliable")
func _rpc_ataque() -> void:
	if anim_ataque != &"" and animation_player.has_animation(anim_ataque):
		animation_player.play(anim_ataque, 0.1)


## Se ejecuta SOLO en el peer dueño del jugador golpeado
@rpc("authority", "call_local", "reliable")
func _rpc_golpear_jugador(ruta_jugador: NodePath) -> void:
	var jugador := get_node_or_null(ruta_jugador)
	if jugador and jugador.has_method("heridoPorEnemigo"):
		jugador.heridoPorEnemigo()


# ---------------------------------------------------------------
# Estado
# ---------------------------------------------------------------

func _aplicar_estado(valor: bool) -> void:
	activo = valor
	visible = activo
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.set_deferred("disabled", not activo)
	# La lógica corre solo en el servidor; los clientes reciben position/rotation
	set_physics_process(activo and multiplayer.is_server())


# ---------------------------------------------------------------
# Movimiento (solo servidor; position y rotation las replica el MultiplayerSynchronizer)
# ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tiempo_ruta -= delta
	if _tiempo_ruta <= 0.0:
		_tiempo_ruta = 0.2
		_actualizar_objetivo()

	if not is_on_floor():
		velocity.y -= gravity * delta

	var persigue := GameManager.papas_atacan or perseguir_siempre
	var direccion := _destino - global_position
	direccion.y = 0.0

	if persigue and direccion.length() > 0.3:
		direccion = direccion.normalized()
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
		# Si tu modelo mira hacia +Z, usá atan2(direccion.x, direccion.z)
		rotation.y = lerp_angle(rotation.y, atan2(-direccion.x, -direccion.z), delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidad)
		velocity.z = move_toward(velocity.z, 0.0, velocidad)

	move_and_slide()

	var se_mueve := Vector2(velocity.x, velocity.z).length() > 0.1
	if se_mueve != caminando:
		_rpc_caminando.rpc(se_mueve)

	_comprobar_danio()


func _actualizar_objetivo() -> void:
	var objetivo := _jugador_mas_cercano()
	if objetivo == null:
		return

	# 1) Si lo ve, va directo hacia él
	if _hay_vista(objetivo.global_position):
		_destino = objetivo.global_position
		return

	# 2) Si no lo ve, va a la esquina visible más cercana al jugador
	var mejor: Marker3D = null
	var mejor_dist := INF
	for esquina in esquinas:
		# Ignora la esquina en la que ya está parado
		if esquina.global_position.distance_to(global_position) < 1.0:
			continue
		if not _hay_vista(esquina.global_position):
			continue
		var d := esquina.global_position.distance_squared_to(objetivo.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = esquina
	if mejor:
		_destino = mejor.global_position


func _hay_vista(punto: Vector3) -> bool:
	var altura := Vector3.UP * 0.8
	var consulta := PhysicsRayQueryParameters3D.create(
		global_position + altura, punto + altura, mascara_paredes, [get_rid()]
	)
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _jugador_mas_cercano() -> Node3D:
	var cercano: Node3D = null
	var dist_min := INF
	for j in get_tree().get_nodes_in_group("Jugador"):
		if not is_instance_valid(j):
			continue
		var d := global_position.distance_squared_to(j.global_position)
		if d < dist_min:
			dist_min = d
			cercano = j
	return cercano


# ---------------------------------------------------------------
# Daño por contacto (el servidor detecta, el dueño del jugador lo recibe)
# ---------------------------------------------------------------

func _comprobar_danio() -> void:
	if not _puede_danar:
		return
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		if not is_instance_valid(jugador):
			continue
		var diff: Vector3 = jugador.global_position - global_position
		# Distancia horizontal, y que no esté a otra altura
		if Vector2(diff.x, diff.z).length() > radio_contacto or absf(diff.y) > 1.5:
			continue
		_puede_danar = false
		_rpc_ataque.rpc()
		_rpc_golpear_jugador.rpc_id(jugador.get_multiplayer_authority(), jugador.get_path())
		get_tree().create_timer(cooldown_danio).timeout.connect(
			func(): _puede_danar = true
		)
		break


# ---------------------------------------------------------------
# Animación (corre en todos los peers)
# ---------------------------------------------------------------

func _actualizar_animacion() -> void:
	if not is_instance_valid(animation_player):
		return
	# No cortar el golpe a la mitad
	if anim_ataque != &"" and animation_player.current_animation == anim_ataque \
			and animation_player.is_playing():
		return
	if caminando:
		animation_player.play(anim_caminar, 0.2)
	else:
		animation_player.stop()
