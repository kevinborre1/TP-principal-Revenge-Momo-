extends ItemBase 
class_name Arma

@export var escena_bala: PackedScene = preload("res://Objetos-Interactivos/Sistema-Combate/Bala.tscn")
@onready var punto_de_disparo: Marker3D = $PuntoDeDisparo

@export var cadencia: float = 0.2
var puede_disparar: bool = true

# Sonidos
const SFX_DISPARO = preload("res://sonidos/disparo_nerf.wav")

func _jugador_dueño() -> Player:
	var nodo: Node = self
	while nodo and not (nodo is Player):
		nodo = nodo.get_parent()
	return nodo as Player

func _physics_process(_delta: float) -> void:
	var jugador := _jugador_dueño()
	if jugador == null or jugador.input_bloqueado or jugador.muerto:
		return
	if Global.get("menu_pausa_abierto") == true:
		return
	if not jugador.is_multiplayer_authority():
		return

	if Input.is_action_just_pressed("disparar") and puede_disparar:
		disparar()

func disparar() -> void:
	if not escena_bala:
		return
	puede_disparar = false 
		
	var player = _jugador_dueño()
	if not player:
		puede_disparar = true
		return
		
	reproducir_sfx_3d(SFX_DISPARO)
	var raycast: RayCast3D = player.find_child("RayCastDisparo", true, false)
	
	if raycast:
		raycast.clear_exceptions()
		
		if player is CollisionObject3D:
			raycast.add_exception(player)
			
		for otro in get_tree().get_nodes_in_group("jugadores"):
			if otro is CollisionObject3D:
				raycast.add_exception(otro)
		for otro in get_tree().get_nodes_in_group("Jugador"):
			if otro is CollisionObject3D:
				raycast.add_exception(otro)
				
		raycast.force_raycast_update()
		
	var direccion_disparada = Vector3.FORWARD
	var apuntando_a_enemigo = false
	
	if raycast and raycast.is_colliding():
		var objeto_colisionado = raycast.get_collider()
		if objeto_colisionado and objeto_colisionado.is_in_group("Enemigo"):
			var punto_impacto = raycast.get_collision_point()
			direccion_disparada = (punto_impacto - punto_de_disparo.global_position).normalized()
			apuntando_a_enemigo = true
			
	if not apuntando_a_enemigo:
		var camara: Camera3D = player.find_child("Camera3D", true, false)
		if camara:
			var distancia_convergencia = 50.0
			var punto_lejano = camara.global_position - (camara.global_transform.basis.z.normalized() * distancia_convergencia)
			direccion_disparada = (punto_lejano - punto_de_disparo.global_position).normalized()
		else:
			direccion_disparada = -global_transform.basis.z.normalized()
			
	if multiplayer.has_multiplayer_peer():
		generar_bala.rpc(punto_de_disparo.global_position, direccion_disparada, player.rol)
	else:
		generar_bala(punto_de_disparo.global_position, direccion_disparada, player.rol)
	
	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true

# Método reutilizable para que BotNico dispare usando el mismo cañón, sonido y sincronización de red
func disparar_desde_ia(objetivo_pos: Vector3, rol_tirador: String = "ambos") -> void:
	if not escena_bala or not puede_disparar:
		return
	puede_disparar = false
	
	reproducir_sfx_3d(SFX_DISPARO)
	var origen := punto_de_disparo.global_position if is_instance_valid(punto_de_disparo) else global_position
	var direccion_disparada := (objetivo_pos - origen).normalized()
	if direccion_disparada == Vector3.ZERO:
		direccion_disparada = -global_transform.basis.z.normalized()
	
	if multiplayer.has_multiplayer_peer():
		generar_bala.rpc(origen, direccion_disparada, rol_tirador)
	else:
		generar_bala(origen, direccion_disparada, rol_tirador)
	
	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true

@rpc("call_local", "any_peer", "reliable")
func generar_bala(posicion_inicial: Vector3, direccion: Vector3, tipo: String = "ambos") -> void:
	var bala = escena_bala.instantiate() as Area3D
	
	get_tree().current_scene.add_child(bala)
	
	bala.global_position = posicion_inicial
	bala._direccion_salida(direccion)
	bala.set_tipo(tipo)
	
func desactivar_para_mano() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	var colision = get_node_or_null("CollisionShape3D")
	if colision:
		colision.set_deferred("disabled", true)	

func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.bus = &"SFX"
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
