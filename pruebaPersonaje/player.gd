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
var camera_rotation := Vector2.ZERO


func _ready() -> void:
	# Asignar autoridad al nodo principal y sincronizador
	var id_player = name.to_int()
	set_multiplayer_authority(id_player)
	
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(id_player)
	
	# prender la camara y usar solo el mouse si somos los due;os
	if is_multiplayer_authority():
		if camara:
			camara.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		configurar_barraStamina()
	else:
		if camara:
			camara.current = false
		if barraStamina:
			barraStamina.visible = false


func _input(event: InputEvent) -> void:
	# si no es nuestro personaje ignoramos el mouse
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * mouse_sensitivy
		camera_rotation.y -= event.relative.x * mouse_sensitivy
		
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-60), deg_to_rad(30))
		
		spring_arm_3d.rotation.x = camera_rotation.x
		spring_arm_3d.rotation.y = camera_rotation.y

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("ui_accept") and not is_on_floor():
		activar_ragdoll()

func _physics_process(delta: float) -> void:
	# si no es nuestro personaje no calculamos sus fisicas con nuestro teclado
	if not is_multiplayer_authority():
		return
	var velocidadActual = SPEED
	actualizar_barraStamina()
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_pressed("Correr") and StaminaActual>0:
		velocidadActual = SPEED * multiplicadorDeCarrera
		StaminaActual -= StaminaPerdida
	elif (StaminaActual< StaminaMax):
		StaminaActual += StaminaRegeneracion
	var input_dir := Input.get_vector("Izquierda", "Derecha", "Adelante", "Atras")
	
	# Vector de movimiento horizontal corregido
	var move_vector = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, spring_arm_3d.rotation.y)
	var direction = move_vector.normalized()
	
	if direction:
		velocity.x = direction.x * velocidadActual
		velocity.z = direction.z * velocidadActual
		
		# Buscamos el nodo visual del personaje
		var modelo = $"Walk (1)" if has_node("Walk (1)") else ($perso if has_node("perso") else ($personaje if has_node("personaje") else null))
		if modelo:
			# Sumamos PI (180 grados) para darlo vuelta exactamente de frente a la marcha
			var target_angle = atan2(-direction.x, -direction.z) + PI
			modelo.rotation.y = lerp_angle(modelo.rotation.y, target_angle, 15.0 * delta)
	else:
		# Frenado rápido
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
