class_name BotNico
extends CharacterBody3D

@export var velocidad_caminar: float = 5.0
@export var velocidad_correr: float = 10.0
@export var cadencia_disparo: float = 0.55
@export var salud_max: int = 100
@export var tiempo_respawn: float = 3.0
@export var altura_sentado: float = -0.4
@export var altura_limite_caida: float = -20.0
@export var friccion_empuje: float = 24.0
@export var escena_arma: PackedScene # Arrastrá acá la escena .tscn de tu pistola

@export_enum("ambos", "rompe_escudo", "letal") var rol: String = "ambos"

const ESCENA_BALA_RESPALDO: PackedScene = preload("res://Objetos-Interactivos/Sistema-Combate/Bala.tscn")
const SFX_DISPARO_RESPALDO: AudioStream = preload("res://sonidos/disparo_nerf.wav")

# Usamos get_node_or_null para evitar crasheos si cambia el nombre en la escena
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var state_machine: BotStateMachine = get_node_or_null("StateMachine")
@onready var punto_disparo: Marker3D = get_node_or_null("PuntoDisparo")
@onready var raycast_disparo: RayCast3D = get_node_or_null("RayCastDisparo")
@onready var modelo: Node3D = get_node_or_null("Walk (1)")
@onready var animation: AnimationPlayer = find_child("AnimationPlayer", true, false)

var jugador_principal: Node3D = null
var salud_actual: int = 100
var muerto: bool = false
var punto_respawn: Vector3 = Vector3.ZERO
var controles_bloqueados: bool = false
var arma_desenfundada: bool = false

var _cooldown_disparo: float = 0.0
var _velocidad_empuje: Vector3 = Vector3.ZERO
var _arma_instancia: Node3D = null

func _ready() -> void:
	salud_actual = salud_max
	# Se suma al grupo "Jugador" para que botones, puertas, enemigos, balas y balsa lo reconozcan
	add_to_group("Jugador")
	add_to_group("BotCompanero")
	
	if punto_respawn == Vector3.ZERO:
		punto_respawn = global_position
	
	_inicializar_arma()
	
	# Esperamos un frame para asegurar que el Jugador 1 ya esté en el árbol
	await get_tree().process_frame
	obtener_jugador_principal()
	
	if state_machine:
		state_machine.inicializar(self)
	else:
		push_error("[BotNico] Falta el nodo hijo llamado exactamente 'StateMachine'.")

func _physics_process(delta: float) -> void:
	if muerto:
		return
	
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

# --- GESTIÓN DEL ARMA DEL COMPAÑERO ---

func _inicializar_arma() -> void:
	if not escena_arma:
		return
	
	var mano: Node3D = _obtener_o_crear_mano_derecha()
	if not is_instance_valid(mano):
		return
	
	_arma_instancia = escena_arma.instantiate() as Node3D
	if _arma_instancia:
		_arma_instancia.name = "ArmaNico"
		mano.add_child(_arma_instancia)
		if _arma_instancia.has_method("desactivar_para_mano"):
			_arma_instancia.desactivar_para_mano()
		_arma_instancia.visible = false

func _obtener_o_crear_mano_derecha() -> Node3D:
	var existente := find_child("ManoDerechaAttachment", true, false) as Node3D
	if existente:
		return existente
	
	# Si Bot.tscn aún no tiene el BoneAttachment3D, lo creamos sobre el hueso de la mano derecha
	var esqueleto := find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto:
		for nombre_hueso in ["mixamorig_RightHand", "RightHand", "mixamorig:RightHand"]:
			if esqueleto.find_bone(nombre_hueso) != -1:
				var attachment := BoneAttachment3D.new()
				attachment.name = "ManoDerechaAttachment"
				attachment.bone_name = nombre_hueso
				esqueleto.add_child(attachment)
				return attachment
	
	return modelo if is_instance_valid(modelo) else self

func equipar_arma(activa: bool) -> void:
	arma_desenfundada = activa
	if is_instance_valid(_arma_instancia):
		_arma_instancia.visible = activa

# --- SALUD, DAÑO, MUERTE Y RESPAWN (Contrato compatible con Player) ---

func heridoPorEnemigo(danio: int = 10) -> void:
	if muerto or controles_bloqueados:
		return
	
	salud_actual = max(0, salud_actual - danio)
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	if muerto:
		return
	
	muerto = true
	equipar_arma(false)
	velocity = Vector3.ZERO
	_velocidad_empuje = Vector3.ZERO
	
	# Lo sacamos temporalmente de "Jugador" para que las papitas no acampen sobre su cuerpo muerto
	if is_in_group("Jugador"):
		remove_from_group("Jugador")
	
	hide()
	_cambiar_colisiones(true)
	
	await get_tree().create_timer(tiempo_respawn).timeout
	
	if not is_inside_tree():
		return
	
	salud_actual = salud_max
	muerto = false
	add_to_group("Jugador")
	_cambiar_colisiones(false)
	show()
	
	# Si el jugador avanzó lejos (por ejemplo cruzó una puerta), reaparece cerca suyo para no quedar encerrado
	var destino_respawn := punto_respawn
	var jugador := obtener_jugador_principal()
	if is_instance_valid(jugador) and punto_respawn.distance_to(jugador.global_position) > 25.0:
		destino_respawn = jugador.global_position + Vector3(1.2, 0.2, 1.2)
	
	global_position = destino_respawn
	if nav_agent:
		nav_agent.target_position = global_position
	
	if state_machine:
		state_machine.cambiar_estado("Seguir")

func _cambiar_colisiones(desactivado: bool) -> void:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.disabled = desactivado

func _verificar_caida_vacio() -> void:
	if global_position.y < altura_limite_caida:
		respawnear()

func respawnear() -> void:
	velocity = Vector3.ZERO
	_velocidad_empuje = Vector3.ZERO
	global_position = punto_respawn
	
	if nav_agent:
		nav_agent.target_position = global_position
	
	if state_machine:
		state_machine.cambiar_estado("Seguir")

# --- EMPUJE EXTERNO ---

func recibir_empuje(impulso: Vector3) -> void:
	if controles_bloqueados or muerto:
		return
	
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_aplicar_empuje_red.rpc_id(get_multiplayer_authority(), impulso)
		return
	
	_guardar_empuje(impulso)

@rpc("any_peer", "call_local", "unreliable")
func _aplicar_empuje_red(impulso: Vector3) -> void:
	_guardar_empuje(impulso)

func _guardar_empuje(impulso: Vector3) -> void:
	impulso.y = 0.0
	_velocidad_empuje = impulso

func _aplicar_empuje_externo(delta: float) -> void:
	if _velocidad_empuje.length_squared() > 0.001:
		velocity.x += _velocidad_empuje.x
		velocity.z += _velocidad_empuje.z
		_velocidad_empuje = _velocidad_empuje.move_toward(Vector3.ZERO, friccion_empuje * delta)

# Cumple el mismo contrato que Player para cinemáticas y eventos de Door.gd
func bloquear_controles(bloquear: bool) -> void:
	controles_bloqueados = bloquear
	if bloquear:
		velocity = Vector3.ZERO
		_velocidad_empuje = Vector3.ZERO

# --- API DE MOVIMIENTO Y ACCIONES (usada por todos los estados - DRY) ---

func mover_hacia(destino: Vector3, delta: float, correr: bool = false) -> void:
	if muerto:
		return
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
	
	_aplicar_empuje_externo(delta)
	move_and_slide()
	_actualizar_animacion(correr)

# Permite desplazarse lateralmente o retroceder mientras mantiene la mirada/puntería sobre el objetivo
func mover_tactico(objetivo_pos: Vector3, direccion_movimiento: Vector3, delta: float) -> void:
	if muerto:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	direccion_movimiento.y = 0.0
	if direccion_movimiento.length_squared() > 0.001:
		var dir := direccion_movimiento.normalized()
		var vel_tactica := velocidad_caminar * 0.85
		velocity.x = dir.x * vel_tactica
		velocity.z = dir.z * vel_tactica
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidad_caminar * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, velocidad_caminar * 4.0 * delta)
	
	rotar_hacia(objetivo_pos, delta)
	_aplicar_empuje_externo(delta)
	move_and_slide()
	_actualizar_animacion(false)

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
	
	if nav_agent.is_navigation_finished():
		if not nav_agent.is_target_reachable():
			return destino
		return global_position
	
	return siguiente

func detener_movimiento(delta: float) -> void:
	if muerto:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, velocidad_caminar * 4.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, velocidad_caminar * 4.0 * delta)
	_aplicar_empuje_externo(delta)
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
	if muerto or not is_instance_valid(objetivo):
		return
	rotar_hacia(objetivo.global_position, delta)
	
	if _cooldown_disparo > 0.0:
		return
	_cooldown_disparo = cadencia_disparo
	
	# Apuntamos al centro del torso de la papita para que la bala viaje horizontal y no pegue en el piso
	var blanco := objetivo.global_position + Vector3(0.0, 0.75, 0.0)
	
	if is_instance_valid(_arma_instancia) and _arma_instancia.has_method("disparar_desde_ia"):
		_arma_instancia.disparar_desde_ia(blanco, rol)
	else:
		# Respaldo directo con Bala.tscn si todavía no arrastraste la escena del arma en el Inspector
		var origen := punto_disparo.global_position if is_instance_valid(punto_disparo) else (global_position + Vector3(0.0, 1.1, 0.0))
		var dir := (blanco - origen).normalized()
		var bala := ESCENA_BALA_RESPALDO.instantiate() as Area3D
		get_tree().current_scene.add_child(bala)
		bala.global_position = origen
		bala._direccion_salida(dir)
		bala.set_tipo(rol)
		_reproducir_sonido_respaldo()

func _reproducir_sonido_respaldo() -> void:
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = SFX_DISPARO_RESPALDO
	player_3d.max_distance = 35.0
	player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)

func _actualizar_animacion(corriendo: bool) -> void:
	if not animation:
		return
	var vel_real := get_real_velocity()
	var moviendose := Vector2(vel_real.x, vel_real.z).length() > 0.2
	if moviendose:
		var anim := "camina"
		if arma_desenfundada and animation.has_animation("Pistol Walk/mixamo_com"):
			anim = "Pistol Walk/mixamo_com"
		elif corriendo and animation.has_animation("Fast Run/mixamo_com"):
			anim = "Fast Run/mixamo_com"
		if animation.has_animation(anim) and animation.current_animation != anim:
			animation.play(anim, 0.2)
	else:
		var anim_quieto := "Standing Idle/mixamo_com"
		if arma_desenfundada and animation.has_animation("Pistol Idle/mixamo_com"):
			anim_quieto = "Pistol Idle/mixamo_com"
		if animation.has_animation(anim_quieto) and animation.current_animation != anim_quieto:
			animation.play(anim_quieto, 0.25)

# --- COMPATIBILIDAD CON TUS SCRIPTS ACTUALES (player.gd / balsa.gd / roles) ---

func cambiar_estado(nombre: String, datos: Dictionary = {}) -> void:
	if state_machine:
		state_machine.cambiar_estado(nombre, datos)

func asignar_rol(nuevo_rol: String) -> void:
	rol = nuevo_rol

func estoy_muerto() -> bool:
	return muerto

func prepare_for_raft() -> void:
	equipar_arma(false)
	if modelo:
		modelo.rotation = Vector3(0, PI, 0)
		modelo.position.y = altura_sentado
	if animation and animation.has_animation("Sitting Pose/mixamo_com"):
		animation.play("Sitting Pose/mixamo_com", 0.2)

func salir_de_balsa() -> void:
	if modelo:
		modelo.position.y = 0.0
