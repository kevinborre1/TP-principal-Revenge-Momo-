extends Area3D
class_name BotonPuerta # (OOP) Buena práctica: dar nombre a la clase para identificarla en el proyecto

@export var id_boton: int = 1
@export var puerta_destino: Node # Asigná la puerta desde el Inspector

var jugador_cerca: bool = false
var esta_activado: bool = false

# Guardamos la referencia a la malla para no tener que buscarla repetidas veces
@onready var malla_boton: MeshInstance3D = $MeshInstance3D

# Sonidos
const SFX_BOTON_PARED = preload("res://sonidos/boton_pared.wav")

@export var texto_interaccion: String = "Presiona E para activar"
@export var margen_label: float = 0.25
var label_3d: Label3D = null # Guardamos la referencia para prenderlo/apagarlo rápido


func _ready() -> void:
	# 1. CREAR EL LABEL 3D POR CÓDIGO
	label_3d = Label3D.new()
	label_3d.text = texto_interaccion
	label_3d.visible = false
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# Configuración visual para que se vea bien en el mundo
	label_3d.pixel_size = 0.005 # Tamaño del texto (ajustalo si lo ves muy grande o chico)
	label_3d.position = _calcular_posicion_sobre_colision()
	label_3d.outline_modulate = Color.BLACK
	label_3d.outline_size = 4

	# Lo añadimos como hijo del objeto interactuable
	add_child(label_3d)

	add_to_group("BotonesPuerta")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _calcular_posicion_sobre_colision() -> Vector3:
	var colision := _obtener_collision_shape()
	if not is_instance_valid(colision):
		return Vector3(0.0, 0.8 + margen_label, 0.0)

	var mitad_alto := _obtener_mitad_altura_shape(colision.shape) * absf(colision.scale.y)
	var margen_local := margen_label / maxf(absf(scale.y), 0.01)
	return Vector3(
		colision.position.x,
		colision.position.y + mitad_alto + margen_local,
		colision.position.z
	)


func _obtener_collision_shape() -> CollisionShape3D:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			return hijo as CollisionShape3D
	return null


func _obtener_mitad_altura_shape(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y * 0.5
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height * 0.5
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height * 0.5
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	return 0.5
	
func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and event.is_action_pressed("interactuar"):
		interactuar()

# Método público único: lo usa el input del jugador humano y también BotNico al llegar
func interactuar() -> void:
	if not esta_activado:
		if Global.modo_multijugador == "local":
			presionar_boton()
		else:	
			presionar_boton.rpc()

## (Red): any_peer permite que cualquier cliente dispare el botón.
## call_local asegura que el que lo presiona también vea el cambio inmediatamente.
@rpc("any_peer", "call_local", "reliable")
func presionar_boton() -> void:
	if not esta_activado:
		esta_activado = true
		reproducir_sfx_3d(SFX_BOTON_PARED)
		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, esta_activado)
			
		# Al ejecutarse en todas las PCs, todos verán el cambio visual
		_actualizar_visual_boton()

## (SOLID - Responsabilidad Única): El botón es el único responsable de saber 
## cómo desactivarse a sí mismo y actualizar sus propios gráficos.
# ¡ATENCIÓN!: Esta función NO necesita @rpc.
func desactivar_externamente() -> void:
	if esta_activado: # Solo actuamos si realmente estaba activado
		esta_activado = false
		_actualizar_visual_boton()
		
## (SOLID - Responsabilidad Única): Esta función se encarga EXCLUSIVAMENTE 
## de manejar cómo se ve el botón, separándola de la lógica de las puertas.
func _actualizar_visual_boton() -> void:
	if malla_boton != null:
		malla_boton.visible = esta_activado
	else:
		push_warning("BotonPuerta: No se encontró el MeshInstance3D para hacer visible.")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador") and not body.is_in_group("BotCompanero"):
		label_3d.show()
		jugador_cerca = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador") and not body.is_in_group("BotCompanero"):
		label_3d.hide()
		jugador_cerca = false

# Sonidos en 3D que el otro escuchará
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
