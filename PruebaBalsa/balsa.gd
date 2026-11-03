extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.5
@export var angulo_maximo_giro: float = 45.0  # grados a cada lado del rumbo inicial
@export var retraso_inicio: float = 1.0       # segundos hasta que arranca después de subirse

@onready var zona_cubierta: Area3D = get_node_or_null("ZonaCubierta")

var is_controlled = false
var player_is_near = false
var player_node: Node3D = null     # jugador que está cerca (para abordar)
var piloto: Node3D = null          # jugador que la maneja
var pasajeros: Array[Node3D] = []  # jugadores parados sobre la cubierta
var _transform_previa: Transform3D
var _rotacion_inicial: float = 0.0
var _inicio_marcha_ms: int = 0

var punto_spawn: Vector3
@export var tiempo_para_reiniciar: float = 3.0 # Segundos de espera antes de que vuelva sola
var _tiempo_vacia: float = 0.0

func _ready() -> void:
	add_to_group("Balsa")
	punto_spawn = global_transform.origin
	_rotacion_inicial = rotation.y
	_transform_previa = global_transform
	
	if zona_cubierta:
		zona_cubierta.body_entered.connect(_on_cubierta_body_entered)
		zona_cubierta.body_exited.connect(_on_cubierta_body_exited)
	else:
		push_warning("Falta el Area3D 'ZonaCubierta' en la balsa: los pasajeros no se moverán con ella.")


func _physics_process(delta: float) -> void:
	if Global.modo_multijugador == "linea" and not NetworkManager.red_conectada():
		return
	# ABORDAR / BAJAR (solo el piloto; el otro jugador sube saltando)
	if Input.is_action_just_pressed("Abordar"):
		if is_controlled:
			if is_multiplayer_authority():
				rpc_abordar_balsa.rpc(1, false)
		elif player_is_near and player_node != null:
			if player_node.name == str(multiplayer.get_unique_id()):
				rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), true)

	# 2. MOVIMIENTO: avanza sola; el piloto solo puede girar un poco a cada lado
	var en_marcha := is_controlled and Time.get_ticks_msec() >= _inicio_marcha_ms
	
	if is_multiplayer_authority():
		if en_marcha:
			var turn_input := Input.get_axis("Derecha", "Izquierda")
			var limite := deg_to_rad(angulo_maximo_giro)
			var giro := wrapf(rotation.y - _rotacion_inicial, -PI, PI)
			giro = clampf(giro + turn_input * turn_speed * delta, -limite, limite)
			rotation.y = _rotacion_inicial + giro
			velocity = -transform.basis.z * speed
		else:
			velocity = Vector3.ZERO
		
		move_and_slide()
		
		# LÓGICA DE COLISIÓN
		if en_marcha:
			for i in get_slide_collision_count():
				var colision = get_slide_collision(i)
				var collider = colision.get_collider()
				
				if collider and collider.is_in_group("Barriles"):
					if collider.has_method("_colision_balsa"):
						collider._colision_balsa()
					
					# Un solo choque devuelve la balsa y a ambos jugadores a la esquina del río
					if Global.modo_multijugador == "linea":
						rpc_chocar_balsa.rpc()
					else:
						rpc_chocar_balsa()
					return # Cortamos el frame acá para que _arrastrar_pasajeros no los mueva

	_arrastrar_pasajeros()
	
	# 4. VERIFICAR SI ESTÁ ABANDONADA PARA REINICIARLA
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if piloto == null and pasajeros.is_empty():
			if global_transform.origin.distance_to(punto_spawn) > 1.0:
				_tiempo_vacia += delta
				if _tiempo_vacia >= tiempo_para_reiniciar:
					_tiempo_vacia = 0.0
					rpc_eliminar_balsa.rpc()
		else:
			_tiempo_vacia = 0.0


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
		bajar_piloto()
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


# Devuelve la balsa y a AMBOS jugadores al inicio al chocar
@rpc("any_peer", "call_local", "reliable")
func rpc_chocar_balsa() -> void:
	bajar_piloto(false)
	pasajeros.clear()
	is_controlled = false
	set_multiplayer_authority(1)
	
	# Devolvemos la balsa a su punto de origen
	velocity = Vector3.ZERO
	global_transform.origin = punto_spawn
	rotation.y = _rotacion_inicial
	force_update_transform()
	_transform_previa = global_transform
	
	# Teletransportar a jugadores a punto_respawn
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	for i in range(jugadores.size()):
		var j = jugadores[i]
		if is_instance_valid(j):
			j.velocity = Vector3.ZERO
			# Tomamos el punto_respawn (esquina del río) del jugador y los separamos 1.2m para que no se traben entre sí
			var esquina_rio: Vector3 = j.punto_respawn if "punto_respawn" in j else (punto_spawn + transform.basis.x * 8.0)
			j.global_position = esquina_rio + Vector3(float(i) * 1.2, 0.2, 0.0)
			j.force_update_transform()



@rpc("any_peer", "call_local", "reliable")
func rpc_eliminar_balsa() -> void:
	bajar_piloto(false)
	for pasajero in pasajeros:
		if not is_instance_valid(pasajero):
			continue
		if "punto_respawn" in pasajero:
			pasajero.global_position = pasajero.punto_respawn
			pasajero.force_update_transform()

	pasajeros.clear()
	is_controlled = false
	set_multiplayer_authority(1)

	velocity = Vector3.ZERO
	global_transform.origin = punto_spawn
	rotation.y = _rotacion_inicial
	force_update_transform()
	_transform_previa = global_transform


func bajar_piloto(mover_al_costado: bool = true) -> void:
	rotation.y = _rotacion_inicial	
	is_controlled = false
	
	if piloto:
		piloto.reparent(get_tree().current_scene, false)
		piloto.set_physics_process(true)
		
		if piloto.has_method("salir_de_balsa"):
			piloto.salir_de_balsa()
		
		if "input_bloqueado" in piloto:
			piloto.input_bloqueado = false
		
		
		if mover_al_costado:
			piloto.global_position = global_position + transform.basis.x * 2.5
			piloto.force_update_transform()
			
		piloto = null
