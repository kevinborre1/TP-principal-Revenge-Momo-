class_name BotNico
extends CharacterBody3D

@export var velocidad_caminar: float = 5.0
@export var velocidad_correr: float = 10.0
@export var cadencia_disparo: float = 0.45
@export var altura_sentado: float = -0.4
@export var altura_limite_caida: float = -20.0

@export_enum("ambos", "rompe_escudo", "letal") var rol: String = "ambos"

# Usamos get_node_or_null para evitar crasheos si cambia el nombre en la escena
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var state_machine: BotStateMachine = get_node_or_null("StateMachine")
@onready var punto_disparo: Marker3D = get_node_or_null("PuntoDisparo")
@onready var raycast_disparo: RayCast3D = get_node_or_null("RayCastDisparo")
@onready var modelo: Node3D = get_node_or_null("Walk (1)")
@onready var animation: AnimationPlayer = find_child("AnimationPlayer", true, false)

var jugador_principal: Node3D = null
var muerto: bool = false
var punto_respawn: Vector3 = Vector3(46 ,1 , 1243)
var controles_bloqueados: bool = false

var _cooldown_disparo: float = 0.0

func _ready() -> void:
	# Se suma al grupo "Jugador" para que botones, puertas y la balsa lo detecten igual que a un humano
	add_to_group("Jugador")
	add_to_group("BotCompanero")
	
	if punto_respawn == Vector3.ZERO:
		punto_respawn = global_position
	
	# Esperamos un frame para asegurar que el Jugador 1 ya esté en el árbol
	await get_tree().process_frame
	obtener_jugador_principal()
	
	if state_machine:
		state_machine.inicializar(self)
	else:
		push_error("[BotNico] Falta el nodo hijo llamado exactamente 'StateMachine'.")

func _physics_process(delta: float) -> void:
	if _cooldown_disparo > 0.0:
		_cooldown_disparo -= delta
	
	_verificar_caida_vacio()

# Búsqueda perezosa (lazy): si el jugador spawnea más tarde o se llama distinto a "1", igual lo encuentra
func obtener_jugador_principal() -> Node3D:
	if is_instance_valid(jugador_principal):
		return jugador_principal
	
	for j in get_tree().get_nodes_in_group("Jugador"):
		if j != self and not j.is_in_group("BotCompanero"):
			jugador_principal = j
			return jugador_principal
	return null

# --- INTEGRIDAD FÍSICA Y RESPAWN ---

func _verificar_caida_vacio() -> void:
	if global_position.y < altura_limite_caida:
		print("cAI nICO")
		respawnear()

func respawnear() -> void:
	velocity = Vector3.ZERO
	global_position = punto_respawn
	
	if nav_agent:
		nav_agent.target_position = global_position
	
	if state_machine:
		state_machine.cambiar_estado("Seguir")

# Cumple el mismo contrato que Player para cinemáticas y eventos de Door.gd
func bloquear_controles(bloquear: bool) -> void:
	controles_bloqueados = bloquear
	if bloquear:
		velocity = Vector3.ZERO

# --- API DE MOVIMIENTO Y ACCIONES (usada por todos los estados - DRY) ---

func mover_hacia(destino: Vector3, delta: float, correr: bool = false) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var siguiente_punto := _calcular_siguiente_punto(destino)
	var direccion := siguiente_punto - global_position
	direccion.y = 0.0
	
	if direccion.length() > 0.15:
		direccion = direccion.normalized()
		var vel := velocidad_correr if correr else velocidad_caminar
		velocity.x = direccion.x * vel
		velocity.z = direccion.z * vel
		rotar_hacia(global_position + direccion, delta)
	else:
		detener_movimiento(delta)
		return
	
	move_and_slide()
	_actualizar_animacion(correr)

func _calcular_siguiente_punto(destino: Vector3) -> Vector3:
	if not nav_agent:
		return destino
	
	var mapa := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return destino
	
	# Último tramo: si ya está al lado del destino, camina directo para no trabarse con el borde del NavMesh
	var dist_horiz := Vector2(global_position.x - destino.x, global_position.z - destino.z).length()
	if dist_horiz < 1.2:
		return destino
	
	if nav_agent.target_position.distance_squared_to(destino) > 0.04:
		nav_agent.target_position = destino
	
	var siguiente := nav_agent.get_next_path_position()
	
	# Si el NavMesh terminó antes de llegar o el destino quedó inalcanzable, intenta caminar directo
	if nav_agent.is_navigation_finished():
		if not nav_agent.is_target_reachable():
			return destino
		return global_position
	
	return siguiente

func detener_movimiento(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, velocidad_caminar * 4.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, velocidad_caminar * 4.0 * delta)
	move_and_slide()
	_actualizar_animacion(false)

func rotar_hacia(objetivo_pos: Vector3, delta: float) -> void:
	var dir := objetivo_pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	var angulo_objetivo := atan2(-dir.x, -dir.z)
	if modelo:
		modelo.rotation.y = lerp_angle(modelo.rotation.y, angulo_objetivo + PI, 12.0 * delta)

func disparar_a(objetivo: Node3D, delta: float) -> void:
	if not is_instance_valid(objetivo):
		return
	rotar_hacia(objetivo.global_position, delta)
	
	if _cooldown_disparo > 0.0:
		return
	_cooldown_disparo = cadencia_disparo
	
	# TODO: Conectá acá con tu sistema real de balas o raycast.
	if objetivo.has_method("_daniar"):
		objetivo._daniar(1)
	elif objetivo.has_method("recibir_disparo"):
		objetivo.recibir_disparo(rol)

func _actualizar_animacion(corriendo: bool) -> void:
	if not animation:
		return
	var vel_real := get_real_velocity()
	var moviendose := Vector2(vel_real.x, vel_real.z).length() > 0.2
	if moviendose:
		var anim := "Fast Run/mixamo_com" if corriendo and animation.has_animation("Fast Run/mixamo_com") else "camina"
		if animation.has_animation(anim) and animation.current_animation != anim:
			animation.play(anim, 0.2)
	elif animation.has_animation("Standing Idle/mixamo_com") and animation.current_animation != "Standing Idle/mixamo_com":
		animation.play("Standing Idle/mixamo_com", 0.25)

# --- COMPATIBILIDAD CON TUS SCRIPTS ACTUALES (player.gd / balsa.gd / roles) ---

func cambiar_estado(nombre: String, datos: Dictionary = {}) -> void:
	if state_machine:
		state_machine.cambiar_estado(nombre, datos)

func asignar_rol(nuevo_rol: String) -> void:
	rol = nuevo_rol

func estoy_muerto() -> bool:
	return muerto

func prepare_for_raft() -> void:
	if modelo:
		modelo.rotation = Vector3(0, PI, 0)
		modelo.position.y = altura_sentado
	if animation and animation.has_animation("Sitting Pose/mixamo_com"):
		animation.play("Sitting Pose/mixamo_com", 0.2)

func salir_de_balsa() -> void:
	if modelo:
		modelo.position.y = 0.0
