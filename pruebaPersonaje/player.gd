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
var herido = false
var StaminaMax = 100.0
var StaminaActual= 100.0
var StaminaRegeneracion = 0.75
var StaminaPerdida= 1.0
var input_bloqueado: bool = false

#Nodos de minijuego
var minijuego_scene = preload("res://pruebaPersonaje/minijuego/memotest.tscn")
var minijuego_instance: Control = null


@onready var inventario_manager = $Inventario

# Referencias a los nodos
@onready var barraSalud: ProgressBar = $BarraSalud
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

var punto_respawn :  Vector3 = Vector3(36, 2, 1250)

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
				camara.make_current() #camara.call_deferred("make_current")
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
			if has_node("ContenedorMinijuego"):
				$ContenedorMinijuego.hide()
				$ContenedorMinijuego.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raycast: RayCast3D = find_child("RayCastDisparo", true, false)
	if raycast:
		raycast.add_exception(self)
		
	actualizar_modo_combate()
	
	# APAGAR FÍSICAS Y COLISIONES INMEDIATAMENTE AL NACER
	set_physics_process(false) # Apaga la gravedad y el movimiento
	if collision_shape_3d:
		collision_shape_3d.disabled = true # Evita que colisione con el host si aparecen juntos
	
	# 1. Asignamos la posición inicial por defecto ANTES del timer (por si es partida nueva)
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

	# 2. Le damos medio segundo a la red y al mapa para cargar colisiones
	await get_tree().create_timer(0.5).timeout
	
	# 3. Si somos los dueños de este jugador, le pedimos al Host la posición guardada (si existe, pisará la inicial)
	if is_multiplayer_authority():
		SaveAndLoad.solicitar_posicion_guardada_al_servidor()
		# Esperamos un instante mínimo a que llegue el RPC del servidor antes de activar la gravedad
		await get_tree().create_timer(0.15).timeout

	# PRENDER TODO DE NUEVO
	if collision_shape_3d:
		collision_shape_3d.disabled = false
	set_physics_process(true) # Reactiva el _physics_process (gravedad y controles)
	
	# Arrancar el reloj si el modo es contrarreloj
	if label_contrarreloj:
		if Global.modo_de_juego == "contrarreloj":
			label_contrarreloj.show()
			# Solo el host da la orden de iniciar para que no arranque 2 veces
			if is_multiplayer_authority():
				GameManager.iniciar_timer()
		else:
			label_contrarreloj.hide()


func _input(event: InputEvent) -> void:
	if input_bloqueado or (Global.modo_multijugador == "linea" and not is_multiplayer_authority()):
		return
		
	# logica exclusiva de mirar alrededor
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Global.modo_multijugador == "local" and name != "1":
			return
		
		camera_rotation.x -= event.relative.y * mouse_sensitivy
		camera_rotation.y -= event.relative.x * mouse_sensitivy
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-60), deg_to_rad(30))
		spring_arm_3d.rotation.x = camera_rotation.x
		spring_arm_3d.rotation.y = camera_rotation.y
		

# FUNCIÓN _UNHANDLED_INPUT: Para acciones y gameplay
func _unhandled_input(event: InputEvent) -> void:
	if input_bloqueado or (Global.modo_multijugador == "linea" and not is_multiplayer_authority()):
		return
	
	# Solo volvemos a capturar el mouse si no hay ningún minijuego abierto
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and minijuego_instance == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# logica acciones y gameplay
	# Activar Ragdoll
	if event.is_action_pressed("hacer_ragdoll") and not is_on_floor():
		activar_ragdoll()

	# inventario
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
		
	# disparar y rotar el modelo hacia la camara
	if event.is_action_pressed("disparar") and punto_de_mira.is_visible_in_tree() :
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
		if modelo and spring_arm_3d:
			modelo.rotation.y = spring_arm_3d.rotation.y + PI

	# soltar ítem con G
	if event is InputEventKey and event.physical_keycode == KEY_G and event.pressed and not event.echo:
		soltar_item_actual()

	# recoger con E
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		intentar_recoger_item()

	# consumir con C 
	if event is InputEventKey and event.physical_keycode == KEY_C and event.pressed and not event.echo:
		consumir_item_actual.rpc()
		
func _physics_process(delta: float) -> void:
	if input_bloqueado:
		return
		
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
	
	player_animation()
		
	var velocidadActual = SPEED
	actualizar_barraStamina()
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Definimos qué acciones va a leer este script
	var act_izq = "Izquierda"
	var act_der = "Derecha"
	var act_ade = "Adelante"
	var act_atr = "Atras"
	var act_salto = "Salto"
	#var act_correr = "Correr"
	
	# Si estamos en local y somos el Jugador 2, cambiamos el nombre de las acciones a leer
	if Global.modo_multijugador == "local" and name == "2":
		act_izq = "Izquierda_p2"
		act_der = "Derecha_p2"
		act_ade = "Adelante_p2"
		act_atr = "Atras_p2"
		act_salto = "Salto_p2"
		#act_correr = "Correr_p2"

	# Ahora procesamos con las teclas que correspondan a cada uno
	if Input.is_action_just_pressed(act_salto) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	correr_fisico = Input.is_physical_key_pressed(KEY_SHIFT)
	if Global.modo_multijugador == "local" and name == "2":
		correr_fisico = Input.is_physical_key_pressed(KEY_P)
	if correr_fisico and StaminaActual > 0:
		velocidadActual = SPEED * multiplicadorDeCarrera
		StaminaActual -= StaminaPerdida
		actualizar_barraStamina()
	elif (StaminaActual < StaminaMax) and not correr_fisico :
		StaminaActual += StaminaRegeneracion
		actualizar_barraStamina()
		
	#CAMARA
	var input_dir := Input.get_vector(act_izq, act_der, act_ade, act_atr)
	
	# El movimiento vuelve a ser relativo a la cámara (para que WASD responda según tu vista)
	var move_vector = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, spring_arm_3d.rotation.y)
	var direction = move_vector.normalized()
	
	if direction:
		velocity.x = direction.x * velocidadActual
		velocity.z = direction.z * velocidadActual
		
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("perso") else null))
		if modelo:
			# Calculamos hacia dónde se mueve el personaje respecto a la cámara
			var target_angle = atan2(-direction.x, -direction.z)
			#Caminamos hacia donde ve la camara tambien
			modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle + PI, 15.0 * delta)
				
	else:
		velocity.x = move_toward(velocity.x, 0, velocidadActual * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0, velocidadActual * 4.0 * delta)
	move_and_slide()
	# Actualizar HUD del Contrarreloj
	if Global.modo_de_juego == "contrarreloj" and label_contrarreloj:
		if Global.menu_pausa_abierto:
			label_contrarreloj.hide() # Lo ocultamos en el menú
		else:
			label_contrarreloj.show() # Lo mostramos en el juego
			
			var minutos = int(GameManager.tiempo_restante) / 60
			var segundos = int(GameManager.tiempo_restante) % 60
			label_contrarreloj.text = "%02d:%02d" % [minutos, segundos]
			
			if GameManager.tiempo_restante <= 60.0:
				label_contrarreloj.modulate = Color.RED
			else:
				label_contrarreloj.modulate = Color.WHITE
func activar_ragdoll():
	if collision_shape_3d:
		collision_shape_3d.disabled = true
	if skeleton_3d:
		skeleton_3d.physical_bones_start_simulation()
		
func actualizar_barraStamina():
	cambioStamina.emit()
	
func actualizar_barraDeVida():
	if barraSalud:
		barraSalud.max_value = saludMax
		barraSalud.value = saludActual 
	cambioSalud.emit()
	
func heridoPorEnemigo():
	if Global.modo_multijugador == "linea":
		# Solo el Host (servidor) tiene derecho a confirmar si hubo un golpe
		if multiplayer.is_server():
			# Le manda una orden directa por internet al dueño de este personaje
			rpc_id(get_multiplayer_authority(), "_recibir_danio_red", 10)
	else:
		# Si están jugando en modo local (pantalla dividida), se aplica directo
		_recibir_danio_red(10)

# Esta es la orden que viaja por la red
@rpc("any_peer", "call_local", "reliable")
func _recibir_danio_red(danio: int):
	saludActual -= danio
	herido = true
	if saludActual <= 0:
		saludActual = 0
		actualizar_barraDeVida()
		respawnear()
		print("¡El jugador ha muerto!")
	actualizar_barraDeVida()

func respawnear():
	# 1. VISUAL PARA TODOS: Escondemos el cuerpo y apagamos físicas.
	# Como esto lo ven todos los jugadores, no necesita restricciones.
	hide()
	set_physics_process(false)
	
	# 2. LÓGICA LOCAL: Solo apagamos la cámara si ESTA computadora controla a este jugador
	if is_multiplayer_authority():
		camara.current = false
	
	# 3. Esperar 2 segundos
	await get_tree().create_timer(2.0).timeout
	
	# 4. Restaurar estadísticas y posición en todas las pantallas
	velocity = Vector3.ZERO
	saludActual = 100
	global_transform.origin = punto_respawn
	force_update_transform()
	
	# 5. RESTAURAR LÓGICA LOCAL: Solo el dueño actualiza su cámara (y posiblemente su UI)
	if is_multiplayer_authority():
		actualizar_barraDeVida()
		camara.current = true
		
	# 6. VISUAL PARA TODOS: Volvemos a encender todo
	show()
	set_physics_process(true)
	
func actualizar_respawn(direccion_respawn: Vector3):
	punto_respawn = direccion_respawn
	
func is_moving():
	return abs(velocity.z) > 0 || abs(velocity.x) > 0

func player_animation():
	# 1. Si está en el aire (Salto)
	if not is_on_floor():
		detener_musica_baile()
		if animation.has_animation("salta"):
			animation.play("salta", 0.1, 1.8)
		elif animation.has_animation("Jump/mixamo_com"):
			animation.play("Jump/mixamo_com", 0.1, 1.8)
		return
	else:
		animation.speed_scale = 1.0

	# Definir acciones según P1 o P2
	var act_bailar = "bailar"
	var act_correr = "Correr"
	if Global.modo_multijugador == "local" and name == "2":
		act_bailar = "bailar_p2"
		act_correr = "Correr_p2"

	# 2. Si presiona la tecla de Baile
	if Input.is_action_pressed(act_bailar):
		# Reproducir música si no está sonando ya
		if macarena and not macarena.playing:
			macarena.play()

		if animation.has_animation("Macarena Dance/mixamo_com"):
			animation.play("Macarena Dance/mixamo_com", 0.3)
			return
		elif animation.has_animation("baila"):
			animation.play("baila", 0.3)
			return

	# Si llegó acá, NO está bailando -> Detener la música
	detener_musica_baile()

	# 3. Movimiento (Caminar / Correr / Idle)
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
		# 1. Si es una pepita de café (tiene el método ser_recogido y no es un ItemBase)
		if cuerpo.has_method("ser_recogido") and not (cuerpo is ItemBase):
			cuerpo.ser_recogido()
			break
		
		# 2. Si es un ítem normal del inventario (como las botellas)
		elif cuerpo is ItemBase:
			var exito = inventario_manager.agregar_item(cuerpo.nombre_item, cuerpo.icono, cuerpo.ruta_escena, self)
			if exito:
				cuerpo.ser_recogido()
				break
				
# Función auxiliar para frenar la canción
func detener_musica_baile():
	if macarena and macarena.playing:
		macarena.stop()
		
func soltar_item_actual():
	var item = inventario_manager.obtener_item_actual()
	if item != null:
		var ruta = item["ruta_escena"]
		
		# Le decimos al inventario que borre el ítem del HUD y del arreglo
		inventario_manager.borrar_item_actual()

		# Instanciamos el objeto en el mundo
		if ruta != "":
			var escena_objeto = load(ruta)
			if escena_objeto:
				var nuevo_objeto = escena_objeto.instantiate()
				get_tree().current_scene.add_child(nuevo_objeto)
				nuevo_objeto.global_position = global_position + (global_transform.basis.z * -1.5) + Vector3(0, 1, 0)

@rpc("any_peer", "call_local", "reliable")
func consumir_item_actual():
	#var item = inventario_manager.obtener_item_actual()
	#if item != null:
		#var ruta = item["ruta_escena"]
		#var escena_objeto = load(ruta)
		
		if item_en_mano != null :
			#var item_temporal = escena_objeto.instantiate()
			if item_en_mano is ItemBase:
				var se_uso = item_en_mano.usar_item(self)
				
				# Si se pudo usar con éxito, lo borramos del inventario
				if se_uso == true:
					inventario_manager.borrar_item_actual()
					desequipar_para_todos()
					
			#item_temporal.queue_free()

func recibir_cura(puntos_cura: int) -> bool:
	
	if saludActual >= saludMax:
		print("Salud llena. No puedes usar la botella.")
		return false
	saludActual += puntos_cura
	
	if saludActual > saludMax:
		saludActual = saludMax
	print("Te curaste. Tu salud ahora es: ", saludActual)
	actualizar_barraDeVida()
	return true
	
#Funciones de minijuego
func abrir_minijuego() -> void:
	#solo abrimos el minijuego si este personaje es el nuestro en esta PC
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
	if minijuego_instance:
		return  # ya está abierto, evitar duplicados
	$ContenedorMinijuego.show()
	$ContenedorMinijuego.mouse_filter = Control.MOUSE_FILTER_PASS
	$CanvasLayer/PuntoDeMira.hide()
	if has_node("PanelContainer2"): $PanelContainer2.hide()
	if has_node("icon_counter"): $icon_counter.hide()
	minijuego_instance = minijuego_scene.instantiate()
	minijuego_instance.nombre_jugador = "Jugador 1" if name == "1" else "Jugador 2"
	$ContenedorMinijuego.add_child(minijuego_instance)  
	minijuego_instance.minijuego_terminado.connect(_on_minijuego_terminado)
	
	#Subir opacidad de contenedorMinijuego
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
	
	# Desvanece el contenedor 
	var tween = create_tween()
	tween.tween_property($ContenedorMinijuego, "modulate:a", 0.0, 0.5)
	# Espera a que la animación del Tween termine antes de borrar el minijuego
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
		# 1. Activamos o desactivamos la mira según lo que pida el objeto
		if item_en_mano.activa_mira_combate:punto_de_mira.show()
		else:punto_de_mira.hide()
		
		# 2. Ajustamos la cámara dependiendo de si el objeto la modifica o no
		if item_en_mano.modifica_camara:
			ajustar_camara(item_en_mano.distancia_camara, item_en_mano.offset_camara)
		else:
			# Ítem común, cámara normal
			ajustar_camara(distancia_camara_normal, Vector3(0.0, 1.5, 0.0))
	else:
		# Manos vacías: ocultamos mira y cámara normal
		punto_de_mira.hide()
		ajustar_camara(distancia_camara_normal, Vector3(0.0, 1.5, 0.0))
		
func ajustar_camara(distancia_camara: float, posicion_camara: Vector3):
		spring_arm.spring_length = distancia_camara
		spring_arm.position = posicion_camara
		
# 1. Tu inventario llamará a esta función cuando elijas el arma
func solicitar_equipar(ruta_escena: String) -> void:
	if not is_multiplayer_authority(): 
		return
# Le decimos a todos los clientes que te pongan el arma en la mano
	equipar_para_todos.rpc(ruta_escena)

# 2. Tu inventario llamará a esta cuando la deselecciones
func solicitar_desequipar() -> void:
	if not is_multiplayer_authority(): 
		return
	desequipar_para_todos.rpc()

# --- FUNCIONES MULTIJUGADOR ---
@rpc("any_peer", "call_local", "reliable")
func equipar_para_todos(ruta_escena: String) -> void:
# Si ya tenías algo en la mano, lo borramos primero
	if item_en_mano != null:
		item_en_mano.queue_free()
		item_en_mano = null

	if ruta_escena == "":
		return
# Cargamos el archivo del arma y lo creamos

	var escena_nueva = load(ruta_escena)
	if escena_nueva:
		item_en_mano = escena_nueva.instantiate()
		mano.add_child(item_en_mano)
		print("Tengo en la mano"+ruta_escena)
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

# Funcion para la balsa
func prepare_for_raft() -> void:
	# reiniciar la variable que guarda el movimiento del mouse
	camera_rotation = Vector2.ZERO
	# resetea la rotacion del brazo de la camara
	if spring_arm_3d:
		spring_arm_3d.rotation = Vector3.ZERO
	# reiniciamos la rotacion del nodo raiz del jugador
	rotation = Vector3.ZERO
	#reiniciamos la rotacion del modelo 3d para que no quede con mala orientacion respecto a la balsa
	var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
	if modelo:
		modelo.rotation = Vector3(0, PI, 0)

@rpc("any_peer", "call_local", "reliable")
func bloquear_controles(bloquear: bool) -> void:
	input_bloqueado = bloquear
	if bloquear:
		velocity = Vector3.ZERO # Frena al jugador inmediatamente si venía corriendo
