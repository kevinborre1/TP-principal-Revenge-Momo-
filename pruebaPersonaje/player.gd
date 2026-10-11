extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var multiplicadorDeCarrera = 2
var mouse_sensitivy := 0.003
@export var saludMax: int = 100.0
@export var saludActual: int = saludMax
var herido = false
signal cambioSalud
var StaminaMax = 100.0
var StaminaActual= 100.0
var StaminaRegeneracion = 0.75
var StaminaPerdida=1.0
var inventario = [null, null, null, null] 
var input_bloqueado: bool = false

#Nodos de minijuego
var minijuego_scene = preload("res://pruebaPersonaje/minijuego/memotest.tscn")
var minijuego_instance: Control = null

# Estado del arma
@export var arma_equipada: bool = false

# Referencias a los nodos
@onready var detector_items = $DetectorItems
@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var skeleton_3d: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
@onready var barraStamina = $BarraDeStamina
@onready var animation = $"Walk (1)/AnimationPlayer"
@onready var macarena: AudioStreamPlayer = $musicaBaile2
@onready var slots_ui = $Inventario.get_children() # Obtiene los 4 Paneles
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var crosshair: Control = $CanvasLayer/PuntoDeMira # Ajusta la ruta de tu UI
# Camara
@onready var camara: Camera3D = find_child("Camera3D", true, false) as Camera3D
@export var distancia_camara_normal: float = 2.0
@export var distancia_camara_combate: float = 3.5 # Más lejos cuando saca el arma
var camera_rotation := Vector2.ZERO
var correr_fisico = Input.is_physical_key_pressed(KEY_SHIFT)
# Ruta hacia tu BoneAttachment3D de la mano:
@onready var mano_attachment: BoneAttachment3D = $"Walk (1)/Skeleton3D/ManoDerechaAttachment"

func _ready() -> void:
	# APAGAR FÍSICAS Y COLISIONES INMEDIATAMENTE AL NACER
	set_physics_process(false) # Apaga la gravedad y el movimiento
	if collision_shape_3d:
		collision_shape_3d.disabled = true # Evita que colisione con el host si aparecen juntos
		
	var id_player = name.to_int()
	set_multiplayer_authority(id_player)
	add_to_group("Jugador")
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id_player)
	
	# Le damos medio segundo a la red para que sincronice todo y al mapa para cargar.
	await get_tree().create_timer(0.5).timeout
	
	# POSICIONAR AL JUGADOR
	if Global.modo_multijugador == "linea":
		# Verificamos si estamos en la escena del tutorial
		if get_tree().current_scene.name == "Tutorial":
			# Ajusta estas coordenadas "X, Y, Z" a donde quieres que aparezcan dentro de tu laberinto
			if id_player == 1:
				global_position = Vector3(-3, 0, -36) # Posición Host en Tutorial
			else:
				global_position = Vector3(-3, 0, -33) # Posición Cliente en Tutorial
		elif SaveAndLoad.rutaUtilizada == "" or not ResourceLoader.exists(SaveAndLoad.rutaUtilizada):
			if id_player == 1:
				global_position = Vector3(36, 10, 1250) 
			else:
				global_position = Vector3(40, 10, 1250)

	# PRENDER TODO DE NUEVO
	if collision_shape_3d:
		collision_shape_3d.disabled = false
	set_physics_process(true) # Reactiva el _physics_process (gravedad y controles)
	
	# PRENDER LA CÁMARA (Si es mi personaje)
	var es_mi_personaje = (id_player == multiplayer.get_unique_id())
	
	if Global.modo_multijugador == "local":
		if camara:
			camara.make_current()
		if barraStamina:
			barraStamina.visible = true
		configurar_barraStamina()
		
	elif Global.modo_multijugador == "linea":
		if es_mi_personaje:
			if camara:
				camara.make_current()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			configurar_barraStamina()
			if barraStamina:
				barraStamina.visible = true
		else:
			if camara:
				camara.current = false
			if barraStamina:
				barraStamina.visible = false
	
	# Hacemos que el RayCast de la cámara ignore al propio jugador para que no colisione con su cuerpo				
	var raycast: RayCast3D = find_child("RayCastDisparo", true, false)
	if raycast:
		raycast.add_exception(self)
		
	actualizar_modo_combate()

# 1. FUNCIÓN _INPUT: Solo para cámara y ratón
func _input(event: InputEvent) -> void:
	if input_bloqueado:
		return
	# Bloqueamos inputs si estamos en línea y no somos el dueño del personaje
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
	
	# Si haces clic izquierdo, vuelve a capturar el ratón
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# LÓGICA DE LA CÁMARA (Se queda aquí para máxima fluidez)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Si estamos en modo local y NO somos el jugador 1, ignoramos el ratón
		if Global.modo_multijugador == "local" and name != "1":
			return 
			
		camera_rotation.x -= event.relative.y * mouse_sensitivy
		camera_rotation.y -= event.relative.x * mouse_sensitivy
		
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-60), deg_to_rad(30))
		
		spring_arm_3d.rotation.x = camera_rotation.x
		spring_arm_3d.rotation.y = camera_rotation.y

# 2. FUNCIÓN _UNHANDLED_INPUT: Para acciones y gameplay
func _unhandled_input(event: InputEvent) -> void:
	if input_bloqueado:
		return
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return

	# Soltar ítem con G
	if event is InputEventKey and event.physical_keycode == KEY_G and event.pressed and not event.echo:
		soltar_item(0)

	# Activar Ragdoll
	if event.is_action_pressed("hacer_ragdoll") and not is_on_floor():
		activar_ragdoll()
		
	# Disparar y rotar el modelo hacia la cámara
	if event.is_action_pressed("disparar") and arma_equipada:
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
		if modelo and spring_arm_3d:
			modelo.rotation.y = spring_arm_3d.rotation.y + PI

	# Recoger con Q
	if event is InputEventKey and event.physical_keycode == KEY_Q and event.pressed and not event.echo:
		intentar_recoger_item()

	# Consumir con E
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		consumir_item(0)
		
func _physics_process(delta: float) -> void:
	if input_bloqueado:
		return
	player_animation()
	# Bloqueamos el movimiento en línea si no es nuestra autoridad
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
		
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
	var act_correr = "Correr"
	
	# Si estamos en local y somos el Jugador 2, cambiamos el nombre de las acciones a leer
	if Global.modo_multijugador == "local" and name == "2":
		act_izq = "Izquierda_p2"
		act_der = "Derecha_p2"
		act_ade = "Adelante_p2"
		act_atr = "Atras_p2"
		act_salto = "Salto_p2"
		act_correr = "Correr_p2"

	# Ahora procesamos con las teclas que correspondan a cada uno
	if Input.is_action_just_pressed(act_salto) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var correr_fisico = Input.is_physical_key_pressed(KEY_SHIFT)
	if Global.modo_multijugador == "local" and name == "2":
		correr_fisico = Input.is_physical_key_pressed(KEY_P)
	if correr_fisico and StaminaActual > 0:
		velocidadActual = SPEED * multiplicadorDeCarrera
		StaminaActual -= StaminaPerdida
	elif (StaminaActual < StaminaMax) and not correr_fisico :
		StaminaActual += StaminaRegeneracion
		
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
			
			if arma_equipada:
				# Con el arma equipada, el personaje rota hacia el movimiento (ajustado con + PI si caminaba al revés)
				modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle + PI, 15.0 * delta)
			else:
				# Modo normal de exploración
				modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle + PI, 15.0 * delta)
				
	else:
		velocity.x = move_toward(velocity.x, 0, velocidadActual * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0, velocidadActual * 4.0 * delta)
	move_and_slide()
	
func activar_ragdoll():
	if collision_shape_3d:
		collision_shape_3d.disabled = true
	if skeleton_3d:
		skeleton_3d.physical_bones_start_simulation()

func configurar_barraStamina():
	barraStamina.min_value = 0.0
	barraStamina.max_value= StaminaMax

func actualizar_barraStamina():
	barraStamina.value = StaminaActual
	
	#a modificar / expandir

func heridoPorEnemigo(area):
	saludActual -=10
	if saludActual < 0:
		saludActual = saludMax
	herido = true
	cambioSalud.emit()
	
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

func recolectar_item(nombre_item: String, textura_icono: Texture2D, ruta: String) -> bool:
	for i in range(inventario.size()):
		if inventario[i] == null:
			# Guardamos nombre y ruta
			inventario[i] = {
				"nombre": nombre_item,
				"ruta_escena": ruta
			}
			
			var icono_visual = slots_ui[i].get_node("icono") # ¡Ojo con mayúsculas/minúsculas de tu nodo "icono"!
			icono_visual.texture = textura_icono
			return true 
			
	print("El inventario está lleno")
	return false

# Función auxiliar para frenar la canción
func detener_musica_baile():
	if macarena and macarena.playing:
		macarena.stop()
		
func soltar_item(indice_slot: int):
	if inventario[indice_slot] != null:
		var ruta = inventario[indice_slot]["ruta_escena"]

		# Vaciamos inventario visual
		inventario[indice_slot] = null
		var icono_visual = slots_ui[indice_slot].get_node("icono")
		icono_visual.texture = null

		# Creamos el objeto de nuevo en el mundo
		if ruta != "":
			var escena_objeto = load(ruta)
			if escena_objeto:
				var nuevo_objeto = escena_objeto.instantiate()
				var mundo = get_tree().current_scene
				mundo.add_child(nuevo_objeto)
				nuevo_objeto.global_position = global_position + (global_transform.basis.z * -1.5) + Vector3(0, 1, 0)

func consumir_item(indice_slot: int):
	if inventario[indice_slot] != null:
		var ruta = inventario[indice_slot]["ruta_escena"]
		
		var escena_objeto = load(ruta)
		if escena_objeto:
			var item_temporal = escena_objeto.instantiate()
			
			if item_temporal is ItemBase:
				item_temporal.usar_item(self) # Ejecutamos el efecto de curar
				
				# Limpiamos el inventario
				inventario[indice_slot] = null
				var icono_visual = slots_ui[indice_slot].get_node("icono")
				icono_visual.texture = null
				
			item_temporal.queue_free()

#Funciones de minijuego
func abrir_minijuego() -> void:
	if minijuego_instance:
		return  # ya está abierto, evitar duplicados
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
	# Desvanece el contenedor 
	var tween = create_tween()
	tween.tween_property($ContenedorMinijuego, "modulate:a", 0.0, 0.5)
	# Espera a que la animación del Tween termine antes de borrar el minijuego
	await tween.finished
	
	minijuego_instance.queue_free()
	minijuego_instance = null
	input_bloqueado = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func intentar_recoger_item():
	if not detector_items: return

	var cuerpos_cercanos = detector_items.get_overlapping_areas() # Usamos areas porque tus items son Area3D
	print("Objetos detectados cerca: ", cuerpos_cercanos.size()) # Para ver si al menos detecta algo
	for cuerpo in cuerpos_cercanos:
		# Godot sabe que la BotellaCerveza ES un ItemBase por la herencia
		print("Revisando objeto: ", cuerpo.name) # Para ver qué detectó
		if cuerpo is ItemBase:
			print("¡Es un ItemBase! Intentando recoger...")
			var exito = recolectar_item(cuerpo.nombre_item, cuerpo.icono, cuerpo.ruta_escena)
			if exito:
				cuerpo.ser_recogido()
				break

func actualizar_modo_combate() -> void:
	arma_equipada = mano_attachment.get_child_count() > 0
	
	if arma_equipada:
		# 1. Configuramos el SpringArm para tercera persona de combate (detrás de la espalda)
		spring_arm.spring_length = distancia_camara_combate
		
		# Opcional: Desplazarlo ligeramente hacia un hombro (hombro derecho)
		spring_arm.position = Vector3(0.5, 1.7, 0.0) # Ajusta según tu modelo
		
		# 2. Mostramos el punto de mira en pantalla
		crosshair.show()
		
		print("Arma equipada: Modo combate activado")
	else:
		# Modo normal (cámara más cerca o libre)
		spring_arm.spring_length = distancia_camara_normal
		spring_arm.position = Vector3(0.0, 1.5, 0.0)
		
		# Ocultamos el punto de mira
		crosshair.hide()
		
		print("Arma guardada")
