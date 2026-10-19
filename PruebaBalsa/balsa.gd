extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.5
@export var angulo_maximo_giro: float = 45.0  # grados a cada lado del rumbo inicial
@export var retraso_inicio: float = 1.0       # segundos hasta que arranca después de subirse

@onready var zona_cubierta: Area3D = get_node_or_null("ZonaCubierta")

@export var vida_balsa: int = 3
signal balsa_destruida

var is_controlled = false
var player_is_near = false
var player_node: Node3D = null      # jugador que está cerca (para abordar)
var piloto: Node3D = null           # jugador que la maneja
var pasajeros: Array[Node3D] = []   # jugadores parados sobre la cubierta
var _transform_previa: Transform3D
var _rotacion_inicial: float = 0.0
var _inicio_marcha_ms: int = 0


func _ready() -> void:
	add_to_group("Balsa")
	_transform_previa = global_transform
	_rotacion_inicial = rotation.y
	if zona_cubierta:
		zona_cubierta.body_entered.connect(_on_cubierta_body_entered)
		zona_cubierta.body_exited.connect(_on_cubierta_body_exited)
	else:
		push_warning("Falta el Area3D 'ZonaCubierta' en la balsa: los pasajeros no se moverán con ella.")


func _physics_process(delta: float) -> void:
	# 1. ABORDAR / BAJAR (solo el piloto; el otro jugador sube saltando)
	if Input.is_action_just_pressed("Abordar"):
		if is_controlled:
			if is_multiplayer_authority():
				rpc_abordar_balsa.rpc(1, false)
		elif player_is_near and player_node != null:
			if player_node.name == str(multiplayer.get_unique_id()):
				rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), true)

	# 2. MOVIMIENTO: avanza sola; el piloto solo puede girar un poco a cada lado
	var en_marcha := is_controlled and Time.get_ticks_msec() >= _inicio_marcha_ms
	if is_multiplayer_authority() and en_marcha:
		var turn_input := Input.get_axis("Derecha", "Izquierda")
		var limite := deg_to_rad(angulo_maximo_giro)
		var giro := wrapf(rotation.y - _rotacion_inicial, -PI, PI)
		giro = clampf(giro + turn_input * turn_speed * delta, -limite, limite)
		rotation.y = _rotacion_inicial + giro
		velocity = -transform.basis.z * speed
		
		# Movemos la balsa
		move_and_slide()
		
		# --- NUEVA LÓGICA DE COLISIÓN (Solo el Host la procesa) ---
		for i in get_slide_collision_count():
			var colision = get_slide_collision(i)
			var collider = colision.get_collider()
			
			# Comprobamos si con lo que chocamos es un barril
			if collider and collider.is_in_group("Barriles"):
				# Le decimos al barril que lo chocamos (y que se destruya)
				if collider.has_method("_colision_balsa"):
					collider._colision_balsa()
				# Le restamos 1 de vida a la balsa a través de la red
				rpc("_recibir_danio")
				
				# Frenamos el chequeo de colisiones en este frame para evitar choques múltiples con el mismo barril
				break

	# 3. ARRASTRAR PASAJEROS (corre en todas las PC)
	_arrastrar_pasajeros()

func _arrastrar_pasajeros() -> void:
	var cambio := global_transform * _transform_previa.affine_inverse()
	_transform_previa = global_transform
	
	for p in pasajeros:
		if not is_instance_valid(p) or p == piloto:
			continue
		if Global.modo_multijugador == "linea" and not p.is_multiplayer_authority():
			continue
		p.global_position = cambio * p.global_position


@rpc("any_peer", "call_local", "reliable")
func rpc_abordar_balsa(id_jugador: int, subiendo: bool) -> void:
	if subiendo and is_controlled:
		return  # ya tiene piloto
	
	var jugador_objetivo = get_tree().current_scene.find_child(str(id_jugador), true, false)
	
	if subiendo:
		set_multiplayer_authority(id_jugador)
		is_controlled = true
		_inicio_marcha_ms = Time.get_ticks_msec() + int(retraso_inicio * 1000.0)
		
		if jugador_objetivo:
			piloto = jugador_objetivo
			if "input_bloqueado" in piloto:
				piloto.input_bloqueado = true
			
			piloto.reparent(self, false)
			piloto.set_physics_process(false)
			piloto.position = Vector3(0, 1.0, 0)
			
			if piloto.has_method("prepare_for_raft"):
				piloto.prepare_for_raft()
	else:
		is_controlled = false
		
		if piloto:
			piloto.reparent(get_tree().current_scene, false)
			piloto.set_physics_process(true)
			
			if "input_bloqueado" in piloto:
				piloto.input_bloqueado = false
			
			piloto.global_position = global_position + (transform.basis.x * 2.5)
			piloto = null
		
		# Recién ahora, con el piloto ya fuera de la balsa, la autoridad vuelve al host
		set_multiplayer_authority(1)


func _on_zona_abordaje_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores") or body.is_in_group("Jugador"):
		player_is_near = true
		player_node = body

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	if body == player_node:
		player_is_near = false


func _on_cubierta_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador") and body not in pasajeros:
		pasajeros.append(body)

func _on_cubierta_body_exited(body: Node3D) -> void:
	pasajeros.erase(body)
	
func eliminar_balsa() -> void:
	if Global.modo_multijugador == "linea":
		if multiplayer.is_server():
			rpc_eliminar_balsa.rpc()
	else:
		rpc_eliminar_balsa()

@rpc("any_peer", "call_local", "reliable")
func _recibir_danio() -> void:
	vida_balsa -= 1
	print("¡La balsa chocó con un barril! Vidas restantes: ", vida_balsa)
	
	if vida_balsa <= 0:
		print("¡La balsa se ha destruido!")
		balsa_destruida.emit()
		GameManager.set_mode(GameManager.GameMode.VIDAS_BALSA) # Le avisa al GameManager que perdieron
		
		# Usamos la función que ya tenías para eliminarla
		if Global.modo_multijugador == "linea":
			if multiplayer.is_server():
				rpc_eliminar_balsa.rpc()
		else:
			rpc_eliminar_balsa()


@rpc("any_peer", "call_local", "reliable")
func rpc_eliminar_balsa() -> void:
	# Bajar al piloto
	if is_instance_valid(piloto):
		piloto.reparent(get_tree().current_scene, true)
		piloto.set_physics_process(true)

		if "input_bloqueado" in piloto:
			piloto.input_bloqueado = false

		piloto.global_position = global_position + transform.basis.x * 2.5
		piloto = null

	# Bajar a los pasajeros
	for pasajero in pasajeros:
		if not is_instance_valid(pasajero):
			continue

		# Los pasajeros no son hijos de la balsa,
		# así que no necesitan reparent().
		pasajero.global_position = global_position + transform.basis.x * 3.0

	pasajeros.clear()
	is_controlled = false

	# Eliminar la balsa
	queue_free()
