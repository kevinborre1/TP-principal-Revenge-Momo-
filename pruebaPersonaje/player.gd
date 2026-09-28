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
# Referencias a los nodos
@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var skeleton_3d: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
@onready var barraStamina = $BarraDeStamina
@onready var camara: Camera3D = find_child("Camera3D", true, false) as Camera3D
@onready var animation = $"Walk (1)/AnimationPlayer"
@onready var macarena: AudioStreamPlayer = $musicaBaile2
var camera_rotation := Vector2.ZERO


func _ready() -> void:
	var id_player = name.to_int()
	set_multiplayer_authority(id_player)
	
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id_player)
	
	# Lógica de encendido de cámara y UI
	if Global.modo_multijugador == "local":
		# En local, AMBOS jugadores necesitan su cámara y barra activas
		if camara:
			camara.make_current()
		if barraStamina:
			barraStamina.visible = true
		configurar_barraStamina()
		# Nota: El mouse capturado en pantalla dividida en PC requiere lógica extra para 2 ratones, 
		# se asume que un jugador usará teclado y otro un joystick/teclado.
	else:
		# En línea, solo prendemos las cosas si somos los dueños
		if is_multiplayer_authority():
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


func _input(event: InputEvent) -> void:
	# Bloqueamos inputs si estamos en línea y no somos el dueño del personaje
	if Global.modo_multijugador == "linea" and not is_multiplayer_authority():
		return
		
	# --- TRUCO PARA PRUEBAS ---
	# Si haces clic izquierdo, vuelve a capturar el ratón (útil si inicias la escena directamente)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# --------------------------

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("ui_accept") and not is_on_floor():
		activar_ragdoll()

	# --- LÓGICA DE LA CÁMARA CON EL RATÓN ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# Si estamos en modo local y NO somos el jugador 1, ignoramos el ratón
		if Global.modo_multijugador == "local" and name != "1":
			return 
			
		camera_rotation.x -= event.relative.y * mouse_sensitivy
		camera_rotation.y -= event.relative.x * mouse_sensitivy
		
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-60), deg_to_rad(30))
		
		spring_arm_3d.rotation.x = camera_rotation.x
		spring_arm_3d.rotation.y = camera_rotation.y
func _physics_process(delta: float) -> void:
	
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
		
	if Input.is_action_pressed(act_correr) and StaminaActual > 0:
		velocidadActual = SPEED * multiplicadorDeCarrera
		StaminaActual -= StaminaPerdida
	elif (StaminaActual < StaminaMax):
		StaminaActual += StaminaRegeneracion
		
	var input_dir := Input.get_vector(act_izq, act_der, act_ade, act_atr)
	
	var move_vector = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, spring_arm_3d.rotation.y)
	var direction = move_vector.normalized()
	
	if direction:
		velocity.x = direction.x * velocidadActual
		velocity.z = direction.z * velocidadActual
		
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
		if modelo:
			var target_angle = atan2(-direction.x, -direction.z) + PI
			modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle, 15.0 * delta)
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


# Función auxiliar para frenar la canción
func detener_musica_baile():
	if macarena and macarena.playing:
		macarena.stop()
