extends CharacterBody3D

signal llego_al_final

@export var speed: float = 5.0
@export var turn_speed: float = 2.5
@export var angulo_maximo_giro: float = 45.0    # grados a cada lado del rumbo inicial
@export var retraso_inicio: float = 1.0         # segundos hasta que arranca después de subirse
@export var distancia_maxima: float = 0.0       # metros desde la salida donde frena (0 = sin límite)
@export var distancia_max_piloto: float = 10.0  # si el piloto queda más lejos, se lo suelta
@export var tiempo_para_reiniciar: float = 3.0  # segundos vacía antes de volver sola al inicio

@onready var zona_cubierta: Area3D = get_node_or_null("ZonaCubierta")

var is_controlled := false
var jugadores_cerca: Array[Node3D] = []   # jugadores dentro de la zona de abordaje
var piloto: Node3D = null
var pasajeros: Array[Node3D] = []
var punto_spawn: Vector3

var _padre_original_piloto: Node = null
var _transform_previa: Transform3D
var _rotacion_inicial: float = 0.0
var _inicio_marcha_ms: int = 0
var _llego_al_final := false
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

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _physics_process(delta: float) -> void:
	if Global.modo_multijugador == "linea" and not NetworkManager.red_conectada():
		return

	_procesar_abordaje()

	var en_marcha := is_controlled and not _llego_al_final \
			and Time.get_ticks_msec() >= _inicio_marcha_ms

	if is_multiplayer_authority():
		_mover(delta, en_marcha)
		if en_marcha and _chequear_choque():
			return
		if en_marcha and distancia_maxima > 0.0 \
				and global_position.distance_to(punto_spawn) >= distancia_maxima:
			rpc_llegar_al_final.rpc()
		_validar_piloto()
	else:
		# En las PCs que no son autoridad igual arrastramos a los pasajeros
		_limpiar_excepciones()
		_arrastrar_pasajeros()

	_revisar_abandono(delta)


# ---------------------------------------------------------------- ABORDAJE

func _procesar_abordaje() -> void:
	if not Input.is_action_just_pressed("Abordar"):
		return
	if is_controlled:
		# Solo el piloto (autoridad) puede bajarse
		if is_multiplayer_authority():
			rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), false)
	elif _jugador_local_cerca() != null:
		rpc_abordar_balsa.rpc(multiplayer.get_unique_id(), true)


func _jugador_local_cerca() -> Node3D:
	var mi_id := str(multiplayer.get_unique_id())
	for j in jugadores_cerca:
		if is_instance_valid(j) and j.name == mi_id:
			return j
	return null


@rpc("any_peer", "call_local", "reliable")
func rpc_abordar_balsa(id_jugador: int, subiendo: bool) -> void:
	if subiendo:
		if is_controlled:
			return  # ya tiene piloto
		var jugador := get_tree().current_scene.find_child(str(id_jugador), true, false) as Node3D
		if jugador == null:
			return  # no tocamos el estado si no encontramos al jugador

		set_multiplayer_authority(id_jugador)
		is_controlled = true
		_llego_al_final = false
		_inicio_marcha_ms = Time.get_ticks_msec() + int(retraso_inicio * 1000.0)

		piloto = jugador
		_padre_original_piloto = jugador.get_parent()
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


func bajar_piloto(mover_al_costado: bool = true) -> void:
	is_controlled = false

	if piloto == null:
		rotation.y = _rotacion_inicial
		return
	if not is_instance_valid(piloto):
		piloto = null
		_padre_original_piloto = null
		rotation.y = _rotacion_inicial
		return

	_limpiar_excepciones()

	# Volvemos al padre original (puede ser un SubViewport en modo local)
	# y CONSERVAMOS la posición mundial: antes el piloto caía en (0, 1, 0) del mundo
	var destino: Node = _padre_original_piloto
	if not is_instance_valid(destino):
		destino = get_tree().current_scene
	if piloto.get_parent() != destino:
		piloto.reparent(destino, true)

	rotation.y = _rotacion_inicial   # recién ahora, con el piloto ya fuera

	piloto.set_physics_process(true)
	if piloto.has_method("salir_de_balsa"):
		piloto.salir_de_balsa()
	if "input_bloqueado" in piloto:
		piloto.input_bloqueado = false

	if mover_al_costado:
		piloto.global_position = global_position + transform.basis.x * 2.5
		piloto.force_update_transform()

	piloto = null
	_padre_original_piloto = null


func _on_zona_abordaje_body_entered(body: Node3D) -> void:
	if (body.is_in_group("jugadores") or body.is_in_group("Jugador")) \
			and body not in jugadores_cerca:
		jugadores_cerca.append(body)

func _on_zona_abordaje_body_exited(body: Node3D) -> void:
	jugadores_cerca.erase(body)

func _on_cubierta_body_entered(body: Node3D) -> void:
	if body == piloto:
		return
	if body.is_in_group("Jugador") and body not in pasajeros:
		pasajeros.append(body)

func _on_cubierta_body_exited(body: Node3D) -> void:
	pasajeros.erase(body)


# -------------------------------------------------------------- MOVIMIENTO

func _mover(delta: float, en_marcha: bool) -> void:
	# La balsa avanza sola; el piloto solo puede girar un poco a cada lado
	if en_marcha:
		var turn_input := Input.get_axis("Derecha", "Izquierda")
		var limite := deg_to_rad(angulo_maximo_giro)
		var giro := wrapf(rotation.y - _rotacion_inicial, -PI, PI)
		giro = clampf(giro + turn_input * turn_speed * delta, -limite, limite)
		rotation.y = _rotacion_inicial + giro
		velocity = -transform.basis.z * speed
	else:
		velocity = Vector3.ZERO

	# Ignoramos a los jugadores mientras nos movemos para que un pasajero parado
	# arriba no bloquee a la balsa al subir una rampa
	var jugadores := get_tree().get_nodes_in_group("Jugador")
	for j in jugadores:
		if is_instance_valid(j) and j is PhysicsBody3D:
			add_collision_exception_with(j)

	move_and_slide()
	_arrastrar_pasajeros()

	# Restauramos la colisión para que los pasajeros tengan piso firme
	for j in jugadores:
		if is_instance_valid(j) and j is PhysicsBody3D and j != piloto:
			remove_collision_exception_with(j)


func _arrastrar_pasajeros() -> void:
	var cambio := global_transform * _transform_previa.affine_inverse()
	_transform_previa = global_transform

	for p in pasajeros:
		if not is_instance_valid(p) or p == piloto:
			continue
		p.global_position = cambio * p.global_position


# Devuelve true si chocó con un barril (y reinició todo)
func _chequear_choque() -> bool:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("Barriles"):
			if collider.has_method("_colision_balsa"):
				collider._colision_balsa()
			if Global.modo_multijugador == "linea":
				rpc_chocar_balsa.rpc()
			else:
				rpc_chocar_balsa()
			return true
	return false


# Si el piloto desapareció o fue teletransportado lejos de la balsa
# (por ejemplo, una muerte), lo soltamos para no seguir manejando "en el vacío"
func _validar_piloto() -> void:
	if not is_controlled:
		return
	var huerfano := not is_instance_valid(piloto) \
			or piloto.get_parent() != self \
			or piloto.global_position.distance_to(global_position) > distancia_max_piloto
	if huerfano:
		rpc_soltar_piloto.rpc()


# Si la balsa queda vacía y lejos del inicio, el servidor la devuelve
func _revisar_abandono(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	if piloto == null and pasajeros.is_empty() \
			and global_position.distance_to(punto_spawn) > 1.0:
		_tiempo_vacia += delta
		if _tiempo_vacia >= tiempo_para_reiniciar:
			_tiempo_vacia = 0.0
			rpc_eliminar_balsa.rpc()
	else:
		_tiempo_vacia = 0.0


# --------------------------------------------------------- FIN DE RECORRIDO

# Se puede llamar desde un Area3D del nivel ("FinDeRio") que detecte a la balsa
func llegar_al_final() -> void:
	if is_multiplayer_authority():
		rpc_llegar_al_final.rpc()


@rpc("any_peer", "call_local", "reliable")
func rpc_llegar_al_final() -> void:
	if _llego_al_final:
		return
	_llego_al_final = true
	velocity = Vector3.ZERO
	llego_al_final.emit()


# ------------------------------------------------------------- REINICIOS

func eliminar_balsa() -> void:
	if Global.modo_multijugador == "linea":
		if multiplayer.is_server():
			rpc_eliminar_balsa.rpc()
	else:
		rpc_eliminar_balsa()


# Choque: devuelve la balsa y a AMBOS jugadores al inicio
@rpc("any_peer", "call_local", "reliable")
func rpc_chocar_balsa() -> void:
	_reiniciar_balsa(true)


# Abandono o muerte: devuelve la balsa y a quienes estaban a bordo (piloto incluido)
@rpc("any_peer", "call_local", "reliable")
func rpc_eliminar_balsa() -> void:
	_reiniciar_balsa(false)


@rpc("any_peer", "call_local", "reliable")
func rpc_soltar_piloto() -> void:
	bajar_piloto(false)   # conserva donde esté el piloto (p. ej. su punto de respawn)
	set_multiplayer_authority(1)


func _reiniciar_balsa(devolver_a_todos: bool) -> void:
	# Juntamos a los afectados ANTES de soltar al piloto (antes se perdía la referencia)
	var afectados: Array = []
	if is_instance_valid(piloto):
		afectados.append(piloto)
	for p in pasajeros:
		if is_instance_valid(p) and p not in afectados:
			afectados.append(p)
	if devolver_a_todos:
		for j in get_tree().get_nodes_in_group("Jugador"):
			if is_instance_valid(j) and j not in afectados:
				afectados.append(j)

	bajar_piloto(false)
	_limpiar_excepciones()
	pasajeros.clear()
	is_controlled = false
	_llego_al_final = false
	_tiempo_vacia = 0.0
	set_multiplayer_authority(1)

	# Devolvemos la balsa a su punto de origen
	velocity = Vector3.ZERO
	global_transform.origin = punto_spawn
	rotation.y = _rotacion_inicial
	force_update_transform()
	_transform_previa = global_transform

	# Mandamos a cada jugador a su punto de respawn, separados 1.2 m entre sí
	for i in afectados.size():
		var j = afectados[i]
		if j is CharacterBody3D:
			j.velocity = Vector3.ZERO
		var base: Vector3 = j.punto_respawn if "punto_respawn" in j \
				else (punto_spawn + transform.basis.x * 8.0)
		j.global_position = base + Vector3(float(i) * 1.2, 0.2, 0.0)
		j.force_update_transform()


func _on_peer_disconnected(id: int) -> void:
	if is_controlled and get_multiplayer_authority() == id:
		bajar_piloto(false)
		set_multiplayer_authority(1)
		
# Quita TODAS las excepciones de colisión de la balsa
func _limpiar_excepciones() -> void:
	for cuerpo in get_collision_exceptions():
		remove_collision_exception_with(cuerpo)
