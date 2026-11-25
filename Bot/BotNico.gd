class_name BotNico
extends CharacterBody3D

signal cambioSalud

@export var velocidad_caminar: float = 5.0
@export var velocidad_correr: float = 10.0
@export var cadencia_disparo: float = 0.55
@export var salud_max: int = 100
@export var tiempo_respawn: float = 3.0
@export var altura_sentado: float = -0.4
@export var altura_limite_caida: float = -20.0
@export var friccion_empuje: float = 24.0
@export var intervalo_navegacion: float = 0.25
@export var escena_arma: PackedScene # Arrastrá acá la escena .tscn de tu pistola

@export_enum("ambos", "rompe_escudo", "letal") var rol: String = "ambos"

const ESCENA_BALA_RESPALDO: PackedScene = preload("res://Objetos-Interactivos/Sistema-Combate/Bala.tscn")
const SFX_DISPARO_RESPALDO: AudioStream = preload("res://sonidos/disparo_nerf.wav")

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var state_machine: BotStateMachine = get_node_or_null("StateMachine")
@onready var punto_disparo: Marker3D = get_node_or_null("PuntoDisparo")
@onready var raycast_disparo: RayCast3D = get_node_or_null("RayCastDisparo")
@onready var modelo: Node3D = get_node_or_null("Walk (1)")
@onready var animation: AnimationPlayer = find_child("AnimationPlayer", true, false)

# Agregá estas variables en BotNico.gd
@export var velocidad_salto_onda: float = 6
@export var margen_deteccion_onda: float = 2.0
@export var factor_esquive_ladrillo: float = 1.25
var _cooldown_salto_onda: float = 0.0

var jugador_principal: Node3D = null
var salud_actual: int = 100
var muerto: bool = false
var punto_respawn: Vector3 = Vector3.ZERO
var controles_bloqueados: bool = false
var arma_desenfundada: bool = false

var _cooldown_disparo: float = 0.0
var _timer_nav: float = 0.0
var _ultimo_destino_nav: Vector3 = Vector3(INF, INF, INF)
var _velocidad_empuje: Vector3 = Vector3.ZERO
var _arma_instancia: Node3D = null

var _tiempo_atascado: float = 0.0
var _pos_control_atasco: Vector3 = Vector3.ZERO

func _ready() -> void:
	salud_actual = salud_max
	add_to_group("Jugador")
	add_to_group("BotCompanero")
	
	if punto_respawn == Vector3.ZERO:
		punto_respawn = global_position
	
	_inicializar_arma()
	
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
	if _timer_nav > 0.0:
		_timer_nav -= delta
	
	_verificar_caida_vacio()

func obtener_jugador_principal() -> Node3D:
	if is_instance_valid(jugador_principal):
		return jugador_principal
	
	for j in get_tree().get_nodes_in_group("Jugador"):
		if j != self and not j.is_in_group("BotCompanero"):
			jugador_principal = j
			return jugador_principal
	return null
func obtener_boton_escudo_libre(grupo: String = "BotonEscudoJefe", boton_a_evitar: Node3D = null) -> Node3D:
	var candidatos: Array[Node3D] = []
	for nodo in get_tree().get_nodes_in_group(grupo):
		if nodo is Node3D and is_instance_valid(nodo) and nodo != boton_a_evitar:
			candidatos.append(nodo as Node3D)
	
	if candidatos.is_empty():
		return boton_a_evitar
	
	var jugador: Node3D = obtener_jugador_principal()
	var libres: Array[Node3D] = []
	for btn in candidatos:
		if not boton_ocupado_por_jugador(btn, jugador):
			libres.append(btn)
	
	return libres.pick_random() if not libres.is_empty() else candidatos.pick_random()

func boton_ocupado_por_jugador(boton: Node3D, jugador: Node3D) -> bool:
	if not is_instance_valid(jugador):
		return false
	if boton is Area3D and (boton as Area3D).overlaps_body(jugador):
		return true
	var dist_xz := Vector2(
		boton.global_position.x - jugador.global_position.x,
		boton.global_position.z - jugador.global_position.z
	).length()
	return dist_xz < 1.3
	
	
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

# --- SALUD, DAÑO, MUERTE Y RESPAWN (Contrato compatible con Player y Ahogamiento) ---

func heridoPorEnemigo(danio: float = 10.0) -> void:
	_recibir_danio_red(int(roundi(danio)))

@rpc("any_peer", "call_local", "reliable")
func _recibir_danio_red(danio: int) -> void:
	if muerto or controles_bloqueados:
		return
	print("[BotNico] Daño: -", danio, " | Salud: ", salud_actual, " | Desde: ", get_stack()[1].get("source", "").get_file(), ":", get_stack()[1].get("line", 0))
	salud_actual = max(0, salud_actual - danio)
	cambioSalud.emit()
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	if muerto:
		return
	print("Murio BotNico")
	muerto = true
	equipar_arma(false)
	velocity = Vector3.ZERO
	_velocidad_empuje = Vector3.ZERO
	
	if is_in_group("Jugador"):
		remove_from_group("Jugador")
	
	hide()
	_cambiar_colisiones(true)
	
	await get_tree().create_timer(tiempo_respawn).timeout
	
	if not is_inside_tree():
		return
	
	salud_actual = salud_max
	muerto = false
	cambioSalud.emit()
	add_to_group("Jugador")
	_cambiar_colisiones(false)
	show()
	
	var destino_respawn := punto_respawn
	var jugador := obtener_jugador_principal()
	if is_instance_valid(jugador) and punto_respawn.distance_to(jugador.global_position) > 25.0:
		destino_respawn = jugador.global_position + Vector3(1.2, 0.2, 1.2)
	
	global_position = destino_respawn
	_reiniciar_navegacion()
	
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
	global_position = punto_respawn+Vector3(0,2,0)
	_reiniciar_navegacion()
	
	if state_machine:
		state_machine.cambiar_estado("Seguir")
		
@rpc("any_peer", "call_local", "reliable")
func mover_a(destino: Vector3) -> void:
	velocity = Vector3.ZERO
	_velocidad_empuje = Vector3.ZERO
	global_position = destino
	_reiniciar_navegacion()
	
func _reiniciar_navegacion() -> void:
	_timer_nav = 0.0
	_tiempo_atascado = 0.0
	_pos_control_atasco = global_position
	_ultimo_destino_nav = Vector3(INF, INF, INF)
	if nav_agent:
		nav_agent.target_position = global_position

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
	
	# Detector anti-atasco: si lleva >0.7s intentando avanzar sin moverse, camina directo hacia el destino
	var dist_objetivo := Vector2(global_position.x - destino.x, global_position.z - destino.z).length()
	if dist_objetivo > 1.5:
		if Vector2(global_position.x - _pos_control_atasco.x, global_position.z - _pos_control_atasco.z).length() < 0.25:
			_tiempo_atascado += delta
			if _tiempo_atascado > 0.7:
				siguiente_punto = destino
		else:
			_tiempo_atascado = 0.0
			_pos_control_atasco = global_position
	else:
		_tiempo_atascado = 0.0
	
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
	_ejecutar_desplazamiento(delta, true)
	#_intentar_subir_escalon()
	_actualizar_animacion(correr)

#func _intentar_subir_escalon() -> void:
	#if not is_on_floor() or not is_on_wall():
		#return
	## Solo impulsa si realmente está intentando avanzar horizontalmente
	#if Vector2(velocity.x, velocity.z).length() < 0.2:
		#return
	#var normal_pared := get_wall_normal()
	## Solo actúa frente a bordes verticales (escalones), no en rampas ya caminables
	#if absf(normal_pared.y) < 0.2:
		#velocity.y = 3.8
	
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
	_ejecutar_desplazamiento(delta, true)
	_actualizar_animacion(false)

func _calcular_siguiente_punto(destino: Vector3) -> Vector3:
	if not nav_agent:
		return destino
	
	var mapa := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return destino
	
	var dist_horiz := Vector2(global_position.x - destino.x, global_position.z - destino.z).length()
	if dist_horiz < 1.2:
		return destino
	
	if _timer_nav <= 0.0 and _ultimo_destino_nav.distance_squared_to(destino) > 0.09:
		nav_agent.target_position = destino
		_ultimo_destino_nav = destino
		_timer_nav = intervalo_navegacion
	
	var siguiente := nav_agent.get_next_path_position()
	
	# Evita que el NavMesh lo mande hacia un techo (ej. Módulo 7) cuando el destino real está al nivel del suelo
	if absf(siguiente.y - destino.y) > 2.5 and absf(global_position.y - destino.y) < 2.5:
		return destino
	
	if nav_agent.is_navigation_finished():
		# Si el NavMesh quedó cortado antes de llegar (ej. borde de muelle), avanza directo
		if dist_horiz > 1.5:
			return destino
		return global_position
	
	return siguiente

func detener_movimiento(delta: float, mantener_posicion: bool = false) -> void:
	if muerto:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0.0, velocidad_caminar * 4.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, velocidad_caminar * 4.0 * delta)
	_ejecutar_desplazamiento(delta, not mantener_posicion)
	_actualizar_animacion(false)

func _ejecutar_desplazamiento(delta: float, permitir_empuje_lateral: bool = true) -> void:
	var esquive: Vector3 = esquivar_peligros_jefe(delta)
	if permitir_empuje_lateral and esquive.length_squared() > 0.001:
		velocity.x += esquive.x
		velocity.z += esquive.z
	_aplicar_empuje_externo(delta)
	move_and_slide()

func rotar_hacia(objetivo_pos: Vector3, delta: float) -> void:
	var dir := objetivo_pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	var angulo_objetivo := atan2(-dir.x, -dir.z)
	if modelo:
		modelo.rotation.y = lerp_angle(modelo.rotation.y, angulo_objetivo + PI, 12.0 * delta)

func disparar_a(objetivo: Node3D, delta: float, offset_altura: float = 0.75) -> bool:
	if muerto or not is_instance_valid(objetivo):
		return false
	var blanco: Vector3 = _calcular_punto_impacto(objetivo, offset_altura)
	rotar_hacia(blanco, delta)
	
	if _cooldown_disparo > 0.0:
		return false
	_cooldown_disparo = cadencia_disparo
	
	var dist := snappedf(global_position.distance_to(blanco), 0.1)
	print("[BotNico] Disparando a: ", objetivo.name, " | Blanco: ", blanco, " | Dist: ", dist, "m")
	
	if is_instance_valid(_arma_instancia) and _arma_instancia.has_method("disparar_desde_ia"):
		_arma_instancia.disparar_desde_ia(blanco, rol)
	else:
		var origen := punto_disparo.global_position if is_instance_valid(punto_disparo) else (global_position + Vector3(0.0, 1.1, 0.0))
		var dir := (blanco - origen).normalized()
		var bala := ESCENA_BALA_RESPALDO.instantiate() as Area3D
		get_tree().current_scene.add_child(bala)
		bala.global_position = origen
		bala._direccion_salida(dir)
		bala.set_tipo(rol)
		_reproducir_sonido_respaldo()
	return true


func _calcular_punto_impacto(objetivo: Node3D, offset_defecto: float) -> Vector3:
	if objetivo.has_method("obtener_centro_real"):
		return objetivo.obtener_centro_real() + Vector3(0.0, 1.8, 0.0)
	return objetivo.global_position + Vector3(0.0, offset_defecto, 0.0)


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

# --- COMPATIBILIDAD CON TUS SCRIPTS ACTUALES ---

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
		
		
	
func esquivar_peligros_jefe(delta: float) -> Vector3:
	_cooldown_salto_onda = maxf(0.0, _cooldown_salto_onda - delta)
	var empuje_lateral := Vector3.ZERO
	var escena_actual := get_tree().current_scene
	if escena_actual == null:
		return empuje_lateral

	for nodo in escena_actual.get_children():
		if not is_instance_valid(nodo) or not (nodo is Node3D):
			continue
		var n3d := nodo as Node3D

		# 1. Onda expansiva: en OndaExpansiva crece "_radio" y el anillo está en [ _radio - ancho, _radio ]
		if "_radio" in n3d and "ancho" in n3d:
			var radio_actual: float = float(n3d.get("_radio"))
			var ancho_anillo: float = float(n3d.get("ancho"))
			var altura_p: float = float(n3d.get("altura_peligro")) if "altura_peligro" in n3d else 0.1
			var dist_xz := Vector2(global_position.x - n3d.global_position.x, global_position.z - n3d.global_position.z).length()
			var borde_cercano := radio_actual - ancho_anillo
			# Salta cuando el anillo está por alcanzarlo o cruzándolo y está a ras de piso
			if _cooldown_salto_onda <= 0.0 and is_on_floor():
				if dist_xz >= borde_cercano - margen_deteccion_onda and dist_xz <= radio_actual + 0.6:
					if global_position.y - n3d.global_position.y < altura_p + 0.35:
						velocity.y = velocidad_salto_onda
						_cooldown_salto_onda = 0.45

		# 2. Zona de ladrillazo: tiene "radio" y "retraso" (o "dano") y está en el piso
		if "radio" in n3d and ("retraso" in n3d or "dano" in n3d):
			var radio_zona: float = float(n3d.get("radio"))
			var desde_centro := global_position - n3d.global_position
			desde_centro.y = 0.0
			var dist_zona := desde_centro.length()
			if dist_zona < radio_zona + 0.6:
				var dir_huida := desde_centro.normalized() if dist_zona > 0.01 else Vector3.RIGHT
				empuje_lateral += dir_huida * factor_esquive_ladrillo

	return empuje_lateral
