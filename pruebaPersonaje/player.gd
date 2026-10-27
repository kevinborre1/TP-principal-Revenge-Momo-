extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var multiplicadorDeCarrera = 2
var mouse_sensitivy := 0.003
@export var saludMax: int = 100
@export var saludActual: int = saludMax
signal cambioSalud
signal cambioStamina


# --- NUEVA SEÑAL PARA EL GAMEMANAGER ---
signal jugador_murio(jugador_nodo)

var herido = false
var StaminaMax = 100.0
var StaminaActual= 100.0
var StaminaRegeneracion = 0.75
var StaminaPerdida= 1.0
var input_bloqueado: bool = false
# Variable para controlar si el consumo de estamina está desactivado y el escudo
var estamina_infinita: bool = false
var escudo_activo: bool = false

#Nodos de minijuego
var minijuego_scene = preload("res://pruebaPersonaje/minijuego/memotest.tscn")
var minijuego_instance: Control = null


@onready var inventario_manager = $Inventario
@onready var fps = $FPS

# Referencias a los nodos
@onready var barraSalud = $BarraSalud
@onready var detector_items = $DetectorItems
@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var skeleton_3d: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
@onready var barraStamina = $BarraDeStamina
@onready var animation = $"Walk (1)/AnimationPlayer"
@onready var macarena: AudioStreamPlayer = $musicaBaile2
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var punto_de_mira: Control = $CanvasLayer/PuntoDeMira # Ajusta la ruta de tu UI
# Camara
@onready var camara: Camera3D = find_child("Camera3D", true, false) as Camera3D
@export var distancia_camara_normal: float = 2.0
var camera_rotation := Vector2.ZERO
var correr_fisico = Input.is_physical_key_pressed(KEY_SHIFT)
# Ruta hacia tu BoneAttachment3D de la mano:
@onready var mano: BoneAttachment3D = $"Walk (1)/Skeleton3D/ManoDerechaAttachment"
var item_en_mano: Node3D = null
@onready var label_contrarreloj: Label = $CanvasLayer2/LabelContrarreloj
@onready var contenedor_corazones = get_node_or_null("CanvasLayer2/ContenedorCorazones")

var punto_respawn : Vector3 = Vector3(36, 2, 1250)

func _ready() -> void:
	var id_player = name.to_int()
	set_multiplayer_authority(id_player)
	add_to_group("Jugador")
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id_player)
		
	var es_mi_personaje = (id_player == multiplayer.get_unique_id())
	
	await get_tree().process_frame
	
	if Global.modo_multijugador == "local":
		if camara:
			camara.make_current()
		if barraStamina: barraStamina.show()
		if barraSalud: barraSalud.show()
		if inventario_manager: inventario_manager.show()
		if has_node("CanvasLayer"): $CanvasLayer.show()
		actualizar_barraStamina()	
	
	elif Global.modo_multijugador == "linea":
		if es_mi_personaje:
			if camara:
				camara.make_current() 
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
			if barraStamina: barraStamina.show()
			if barraSalud: barraSalud.show()
			if inventario_manager: inventario_manager.show()
			if has_node("CanvasLayer"): $CanvasLayer.show()
			if has_node("PanelContainer2"): $PanelContainer2.show()
			if has_node("icon_counter"): $icon_counter.show()
			if has_node("ContenedorMinijuego"):
				$ContenedorMinijuego.show()
				$ContenedorMinijuego.mouse_filter = Control.MOUSE_FILTER_PASS
			
			actualizar_barraStamina()
			
			var terreno = get_tree().current_scene.find_child("Terrain3D", true, false)
			if terreno != null and camara != null:
				terreno.set_camera(camara)
				terreno.set_physics_process(true)
		else:
			if camara:
				camara.current = false
				
			if barraStamina: barraStamina.hide()
			if barraSalud: barraSalud.hide()
			if inventario_manager: inventario_manager.hide()
			if has_node("CanvasLayer"): $CanvasLayer.hide()
			if has_node("PanelContainer2"): $PanelContainer2.hide()
			if has_node("icon_counter"): $icon_counter.hide()
			if has_node("CanvasLayer2"): $CanvasLayer2.hide()
			if contenedor_corazones:
				contenedor_corazones.hide()
			if has_node("ContenedorMinijuego"):
				$ContenedorMinijuego.hide()
				$ContenedorMinijuego.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
	var raycast: RayCast3D = find_child("RayCastDisparo", true, false)
	if raycast:
		raycast.add_exception(self)
		
	actualizar_modo_combate()
	
	# APAGAR FÍSICAS Y COLISIONES INMEDIATAMENTE AL NACER
	set_physics_process(false) 
	if collision_shape_3d:
		collision_shape_3d.disabled = true 
	
	# 1. Asignamos la posición inicial
	if Global.modo_multijugador == "linea":
		if get_tree().current_scene.name == "Tutorial":
			if id_player == 1:
				global_position = Vector3(-3, 5, -36)
			else:
				global_position = Vector3(-3, 5, -33)
		else:
			if id_player == 1:
				global_position = Vector3(36, 2, 1250)
			else:
				global_position = Vector3(40, 2, 1250)

	await get_tree().create_timer(0.5).timeout
	
	if is_multiplayer_authority():
		SaveAndLoad.solicitar_posicion_guardada_al_servidor()
		await get_tree().create_timer(0.5).timeout
		SaveAndLoad.solicitar_sincronizacion_mapa_al_servidor()
		await get_tree().create_timer(0.15).timeout

	if collision_shape_3d:
		collision_shape_3d.disabled = false
	set_physics_process(true) 
	
	# Arrancar modos de juego especiales
	if is_multiplayer_authority():
		if Global.modo_multijugador == "linea":
			if multiplayer.is_server():
				if Global.modo_de_juego == "contrarreloj":
					GameManager.contrarreloj.iniciar_timer()
				elif Global.modo_de_juego == "vida_compartida":
					GameManager.vida_compartida.iniciar_modo()
			else:
				GameManager.contrarreloj._pedir_estado_al_host.rpc_id(1)
				GameManager.vida_compartida._pedir_estado_al_host.rpc_id(1)
				
		elif Global.modo_multijugador == "local" and name == "1":
			if Global.modo_de_juego == "contrarreloj":
				GameManager.contrarreloj.iniciar_timer()
			elif Global.modo_de_juego == "vida_compartida":
				GameManager.vida_compartida.iniciar_modo()

	# --- NUEVO: REGISTRO MODULAR ---
	# El jugador se presenta al GameManager apenas termina de cargar
	GameManager.registrar_jugador(self)
	inventario_manager.seleccionar_slot(0, self)
	
func _input(event: InputEvent) -> void:
	if input_bloqueado or (Global.modo_multijugador == "linea" and not is_multiplayer_authority()):
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Global.modo_multijugador == "local" and name != "1":
			return
		
		camera_rotation.x -= event.relative.y * mouse_sensitivy
		camera_rotation.y -= event.relative.x * mouse_sensitivy
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-60), deg_to_rad(30))
		spring_arm_3d.rotation.x = camera_rotation.x
		spring_arm_3d.rotation.y = camera_rotation.y
		
func _unhandled_input(event: InputEvent) -> void:
	if input_bloqueado or (Global.modo_multijugador == "linea" and not is_multiplayer_authority()):
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and minijuego_instance == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("hacer_ragdoll") and not is_on_floor():
		activar_ragdoll()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			inventario_manager.seleccionar_slot(0, self)
			actualizar_modo_combate()
		elif  event.physical_keycode == KEY_2: 
			inventario_manager.seleccionar_slot(1, self)
			actualizar_modo_combate()
		elif event.physical_keycode == KEY_3: 
			inventario_manager.seleccionar_slot(2, self)
			actualizar_modo_combate()
		elif event.physical_keycode == KEY_4: 
			inventario_manager.seleccionar_slot(3, self)
			actualizar_modo_combate()
		elif event.physical_keycode == KEY_5: 
			inventario_manager.seleccionar_slot(4, self)
			actualizar_modo_combate()
		
	if event.is_action_pressed("disparar") and punto_de_mira.is_visible_in_tree() :
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
		if modelo and spring_arm_3d:
			modelo.rotation.y = spring_arm_3d.rotation.y + PI

	if event is InputEventKey and event.physical_keycode == KEY_G and event.pressed and not event.echo:
		soltar_item_actual()

	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		intentar_recoger_item()

	if event is InputEventKey and event.physical_keycode == KEY_C and event.pressed and not event.echo:
		consumir_item_actual.rpc()
		
func _physics_process(delta: float) -> void:
	if input_bloqueado:
		return
		
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		if label_contrarreloj:
			label_contrarreloj.hide()
		return
		
	fps.text = "FPS: " + str(Engine.get_frames_per_second())
	player_animation()
		
	var velocidadActual = SPEED
	actualizar_barraStamina()
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	var act_izq = "Izquierda"
	var act_der = "Derecha"
	var act_ade = "Adelante"
	var act_atr = "Atras"
	var act_salto = "Salto"
	
	if Global.modo_multijugador == "local" and name == "2":
		act_izq = "Izquierda_p2"
		act_der = "Derecha_p2"
		act_ade = "Adelante_p2"
		act_atr = "Atras_p2"
		act_salto = "Salto_p2"

	if Input.is_action_just_pressed(act_salto) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	correr_fisico = Input.is_physical_key_pressed(KEY_SHIFT)
	if Global.modo_multijugador == "local" and name == "2":
		correr_fisico = Input.is_physical_key_pressed(KEY_P)
	if correr_fisico and StaminaActual > 0:
		velocidadActual = SPEED * multiplicadorDeCarrera
		if not estamina_infinita:
			StaminaActual -= StaminaPerdida
		actualizar_barraStamina()
	elif (StaminaActual < StaminaMax) and not correr_fisico :
		StaminaActual += StaminaRegeneracion
		actualizar_barraStamina()
	#CAMARA
	var input_dir := Input.get_vector(act_izq, act_der, act_ade, act_atr)
	var move_vector = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, spring_arm_3d.rotation.y)
	var direction = move_vector.normalized()
	
	if direction:
		velocity.x = direction.x * velocidadActual
		velocity.z = direction.z * velocidadActual
		
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("perso") else null))
		if modelo:
			var target_angle = atan2(-direction.x, -direction.z)
			modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle + PI, 15.0 * delta)
				
	else:
		velocity.x = move_toward(velocity.x, 0, velocidadActual * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0, velocidadActual * 4.0 * delta)
	move_and_slide()
	
	# Actualización visual de HUDs
	if label_contrarreloj:
		if Global.modo_de_juego == "contrarreloj" and not Global.menu_pausa_abierto:
			label_contrarreloj.show()
			var minutos = int(GameManager.contrarreloj.tiempo_restante) / 60
			var segundos = int(GameManager.contrarreloj.tiempo_restante) % 60
			label_contrarreloj.text = "%02d:%02d" % [minutos, segundos]
			
			if GameManager.contrarreloj.tiempo_restante <= 60.0:
				label_contrarreloj.modulate = Color.RED
			else:
				label_contrarreloj.modulate = Color.WHITE
		else:
			label_contrarreloj.hide()
			
	if contenedor_corazones:
		if Global.modo_de_juego == "vida_compartida" and not Global.menu_pausa_abierto:
			if not contenedor_corazones.visible:
				contenedor_corazones.show()
			
			var cantidad_restante = GameManager.vida_compartida.corazones_actuales
			var imagenes_corazones = contenedor_corazones.get_children()
			
			for i in range(imagenes_corazones.size()):
				if i < cantidad_restante:
					imagenes_corazones[i].show()
				else:
					imagenes_corazones[i].hide()
		else:
			if contenedor_corazones.visible:
				contenedor_corazones.hide()

func activar_ragdoll():
	if collision_shape_3d:
		collision_shape_3d.disabled = true
	if skeleton_3d:
		skeleton_3d.physical_bones_start_simulation()
		
func actualizar_barraStamina():
	cambioStamina.emit()
	
func actualizar_barraDeVida():
	cambioSalud.emit()
	
func heridoPorEnemigo():
	if escudo_activo:
		return
	if Global.modo_multijugador == "linea":
		if multiplayer.is_server():
			if Global.modo_de_juego == "vida_compartida":
				GameManager.vida_compartida.cambiar_salud_compartida(-10)
			else:
				rpc_id(get_multiplayer_authority(), "_recibir_danio_red", 10)
	else:
		_recibir_danio_red(10)

# --- NUEVO: DELEGACIÓN DE MUERTE LIMPIA ---
@rpc("any_peer", "call_local", "reliable")
func _recibir_danio_red(danio: int):
	if escudo_activo:
		return
	saludActual -= danio
	herido = true
	if saludActual <= 0:
		saludActual = 0
		actualizar_barraDeVida()
		# El jugador ya no toma decisiones aquí. 
		# Solo grita al GameManager que murió, y el Manager se encarga del resto.
		jugador_murio.emit(self)
		
	actualizar_barraDeVida()

func respawnear():
	hide()
	set_physics_process(false)
	
	if is_multiplayer_authority() and Global.modo_multijugador == "local":
		camara.current = false
	
	await get_tree().create_timer(2.0).timeout
	
	velocity = Vector3.ZERO
	saludActual = 100
	global_transform.origin = punto_respawn
	force_update_transform()
	
	if is_multiplayer_authority():
		actualizar_barraDeVida()
		camara.current = true
		
	show()
	set_physics_process(true)
	
func actualizar_respawn(direccion_respawn: Vector3):
	punto_respawn = direccion_respawn
	
func is_moving():
	return abs(velocity.z) > 0 || abs(velocity.x) > 0

func player_animation():
	if not is_on_floor():
		detener_musica_baile()
		if animation.has_animation("salta"):
			animation.play("salta", 0.1, 1.8)
		elif animation.has_animation("Jump/mixamo_com"):
			animation.play("Jump/mixamo_com", 0.1, 1.8)
		return
	else:
		animation.speed_scale = 1.0

	var act_bailar = "bailar"
	var act_correr = "Correr"
	if Global.modo_multijugador == "local" and name == "2":
		act_bailar = "bailar_p2"
		act_correr = "Correr_p2"

	if Input.is_action_pressed(act_bailar):
		if macarena and not macarena.playing:
			macarena.play()

		if animation.has_animation("Macarena Dance/mixamo_com"):
			animation.play("Macarena Dance/mixamo_com", 0.3)
			return
		elif animation.has_animation("baila"):
			animation.play("baila", 0.3)
			return

	detener_musica_baile()

	if is_moving():
		if Input.is_action_pressed(act_correr) and StaminaActual > 0:
			if animation.has_animation("Fast Run/mixamo_com"):
				animation.play("Fast Run/mixamo_com", 0.2)
			elif animation.has_animation("correr"):
				animation.play("Fast Run/mixamo_com", 0.2)
			else:
				animation.play("camina", 0.2, 1.8)
		else:
			animation.play("camina", 0.3)
	else:
		animation.play("Standing Idle/mixamo_com", 0.3)


func intentar_recoger_item():
	if not is_multiplayer_authority(): return
	
	if not detector_items: return
	
	var cuerpos_cercanos = detector_items.get_overlapping_areas()
	
	for cuerpo in cuerpos_cercanos:
		if cuerpo.has_method("ser_recogido") and not (cuerpo is ItemBase):
			cuerpo.ser_recogido()
			break
		
		elif cuerpo is ItemBase:
			var exito = inventario_manager.agregar_item(cuerpo.nombre_item, cuerpo.icono, cuerpo.ruta_escena, self)
			if exito:
				cuerpo.ser_recogido()
				break
				
func detener_musica_baile():
	if macarena and macarena.playing:
		macarena.stop()
		
# Ejecutado por el cliente dueño del inventario
func soltar_item_actual():
	if not is_multiplayer_authority(): return
	
	if _obtener_contenedor_items() == null:
		push_warning("No se puede soltar: falta 'ContenedorItemsSoltados' en la escena '%s'" % get_tree().current_scene.name)
		return
	var item = inventario_manager.obtener_item_actual()
	if item and item["ruta_escena"] != "":
		var ruta = item["ruta_escena"]
		inventario_manager.borrar_item_actual()
		solicitar_desequipar()
		
		# Enviar la solicitud de física al Host
		var modelo = $"Walk (1)" if has_node("Walk (1)") else self
		var direccion_frente = modelo.global_transform.basis.z.normalized()
		_servidor_procesar_soltar.rpc_id(1, ruta, global_position, direccion_frente)

# Ejecutado ÚNICAMENTE en el Host
@rpc("any_peer", "call_local", "reliable")
func _servidor_procesar_soltar(ruta: String, pos_origen: Vector3, direccion: Vector3):
	if not multiplayer.is_server(): return
	
	var contenedor := _obtener_contenedor_items()
	if contenedor == null:
		push_error("Falta 'ContenedorItemsSoltados' en la escena del host: no se pudo soltar " + ruta)
		return
	
	# Cálculo del RayCast en el servidor
	var origen = pos_origen + Vector3(0, 1.0, 0)
	var destino = origen + (direccion * 1.5)
	var query = PhysicsRayQueryParameters3D.create(origen, destino)
	var resultado = get_world_3d().direct_space_state.intersect_ray(query)
	var pos_final = resultado.position - (direccion * 0.2) if resultado else destino
	
	# Instanciar y agregar al contenedor (El Spawner lo replicará a todos los clientes)
	var nuevo_objeto = load(ruta).instantiate()
	
	contenedor.add_child(nuevo_objeto)

# DESPUÉS modificas su posición global (ahora que Godot ya sabe dónde está)
	nuevo_objeto.global_position = pos_final

@rpc("any_peer", "call_local", "reliable")
func consumir_item_actual():
		if item_en_mano != null :
			if item_en_mano is ItemBase:
				var se_uso = item_en_mano.usar_item(self)
				
				if se_uso == true:
					inventario_manager.borrar_item_actual()
					solicitar_desequipar()
					
func recibir_cura(puntos_cura: int) -> bool:
	if saludActual >= saludMax:
		print("Salud llena. No puedes usar la botella.")
		return false
		
	if Global.modo_multijugador == "linea" and Global.modo_de_juego == "vida_compartida":
		if is_multiplayer_authority():
			GameManager.vida_compartida.cambiar_salud_compartida(puntos_cura)
		return true
		
	saludActual += puntos_cura
	
	if saludActual > saludMax:
		saludActual = saludMax
	print("Te curaste. Tu salud ahora es: ", saludActual)
	actualizar_barraDeVida()
	return true
	
func abrir_minijuego() -> void:
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
	if minijuego_instance:
		return  
	$ContenedorMinijuego.show()
	$ContenedorMinijuego.mouse_filter = Control.MOUSE_FILTER_PASS
	$CanvasLayer/PuntoDeMira.hide()
	if has_node("PanelContainer2"): $PanelContainer2.hide()
	if has_node("icon_counter"): $icon_counter.hide()
	minijuego_instance = minijuego_scene.instantiate()
	minijuego_instance.nombre_jugador = "Jugador 1" if name == "1" else "Jugador 2"
	$ContenedorMinijuego.add_child(minijuego_instance)  
	minijuego_instance.minijuego_terminado.connect(_on_minijuego_terminado)
	
	var tween = create_tween()
	tween.tween_property($ContenedorMinijuego, "modulate:a", 1.0, 0.5)
	
	input_bloqueado = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_minijuego_terminado(gano: bool, puntaje: int) -> void:
	if gano and has_node("/root/SaveAndLoad"):
		if SaveAndLoad.logros == null:
			SaveAndLoad.cargar_logros()
		if SaveAndLoad.logros and not SaveAndLoad.logros.JugasteElMinijuego:
			SaveAndLoad.logros.JugasteElMinijuego = true
			if SaveAndLoad.has_method("guardar_logros"):
				SaveAndLoad.guardar_logros()
	
	var tween = create_tween()
	tween.tween_property($ContenedorMinijuego, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	minijuego_instance.queue_free()
	minijuego_instance = null
	input_bloqueado = false
	$CanvasLayer/PuntoDeMira.show()
	if has_node("PanelContainer2"): $PanelContainer2.show()
	if has_node("icon_counter"): $icon_counter.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func actualizar_modo_combate() -> void:
	if item_en_mano is ItemBase:
		if item_en_mano.activa_mira_combate:punto_de_mira.show()
		else:punto_de_mira.hide()
		
		if item_en_mano.modifica_camara:
			ajustar_camara(item_en_mano.distancia_camara, item_en_mano.offset_camara)
		else:
			ajustar_camara(distancia_camara_normal, Vector3(0.0, 1.5, 0.0))
	else:
		punto_de_mira.hide()
		ajustar_camara(distancia_camara_normal, Vector3(0.0, 1.5, 0.0))
		
func ajustar_camara(distancia_camara: float, posicion_camara: Vector3):
		spring_arm.spring_length = distancia_camara
		spring_arm.position = posicion_camara
		
func solicitar_equipar(ruta_escena: String) -> void:
	if not is_multiplayer_authority(): 
		return
	equipar_para_todos.rpc(ruta_escena)

func solicitar_desequipar() -> void:
	if not is_multiplayer_authority(): 
		return
	desequipar_para_todos.rpc()

@rpc("any_peer", "call_local", "reliable")
func equipar_para_todos(ruta_escena: String) -> void:
	if item_en_mano != null:
		# 1. Lo quitamos del árbol inmediatamente para liberar el nombre en ese mismo frame
		mano.remove_child(item_en_mano)
		item_en_mano.queue_free()
		item_en_mano = null

	if ruta_escena == "":
		return

	var escena_nueva = load(ruta_escena)
	if escena_nueva:
		item_en_mano = escena_nueva.instantiate()
		
		# 2. CLAVE: Forzamos el mismo nombre estático en el Host y en los Clientes
		item_en_mano.name = "ItemEquipado"
		
		mano.add_child(item_en_mano)
		print("Tengo en la mano " + ruta_escena)
		
		if item_en_mano is ItemBase:
			item_en_mano.desactivar_para_mano()
			
		actualizar_modo_combate()

@rpc("any_peer", "call_local", "reliable")
func desequipar_para_todos() -> void:
	if item_en_mano != null:
		item_en_mano.queue_free()
		item_en_mano = null 
		
	actualizar_modo_combate()

@rpc("any_peer", "call_local", "reliable")
func mover_a(nueva_pos: Vector3) -> void:
	velocity = Vector3.ZERO
	global_position = nueva_pos

func prepare_for_raft() -> void:
	camera_rotation = Vector2.ZERO
	if spring_arm_3d:
		spring_arm_3d.rotation = Vector3.ZERO
	rotation = Vector3.ZERO
	var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
	if modelo:
		modelo.rotation = Vector3(0, PI, 0)

@rpc("any_peer", "call_local", "reliable")
func bloquear_controles(bloquear: bool) -> void:
	input_bloqueado = bloquear
	if bloquear:
		velocity = Vector3.ZERO

func recibir_estamina(duracion: float) -> bool:
	if not estamina_infinita:
		# 1. Aplicamos el efecto en segundo plano mediante un Timer o método aparte
		activar_estamina_infinita(duracion)
		# 2. Retornamos true inmediatamente para que el ítem se consuma sin demoras
		return true
	return false

func activar_estamina_infinita(duracion: float) -> void:
	estamina_infinita = true
	await get_tree().create_timer(duracion).timeout
	estamina_infinita = false
	
func recibir_escudo(duracion: float) -> bool:
	if not escudo_activo:
		activar_escudo(duracion)
		return true
	return false

func activar_escudo(duracion: float) -> void:
	escudo_activo = true
	await get_tree().create_timer(duracion).timeout
	escudo_activo = false
	
func recibir_danio_porcentaje(porcentaje: float) -> bool:
	if escudo_activo:
		print("El escudo absorbió el daño de la manzana.")
		return false
		
	# Calcula la cantidad de vida a quitar en base a la salud máxima
	var danio_calculado : int = int(saludMax * (porcentaje / 100.0))
	
	# Si juegas en multijugador online, aplicamos el daño por red
	if Global.modo_multijugador == "linea":
		if Global.modo_de_juego == "vida_compartida":
			if is_multiplayer_authority():
				GameManager.vida_compartida.cambiar_salud_compartida(-danio_calculado)
		elif multiplayer.is_server():
			rpc_id(get_multiplayer_authority(), "_recibir_danio_red", danio_calculado)
		else:
			_recibir_danio_red.rpc_id(1, danio_calculado)
	else:
		_recibir_danio_red(danio_calculado)
		
	return true
	
func _obtener_contenedor_items() -> Node:
	var escena := get_tree().current_scene
	if escena == null:
		return null
	return escena.find_child("ContenedorItemsSoltados", true, false)
