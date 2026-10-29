extends CanvasLayer

@export var altura: float = 8.0      # la misma que te funcionó en el minimapa
@export var zoom: float = 120.0      # metros que se ven de lado a lado (más grande que el minimapa)

var objetivo: Node3D

@onready var camara: Camera3D = %CamaraMapa
@onready var marcador: TextureRect = %MarcadorJugador

func _ready() -> void:
	visible = false
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = zoom
	camara.rotation_degrees = Vector3(-90, 0, 0)
	camara.current = true

func _process(_delta: float) -> void:
	if Global.menu_pausa_abierto:
		visible = false
	if not visible or objetivo == null or not is_instance_valid(objetivo):
		return
	var pos := objetivo.global_position
	camara.global_position = Vector3(pos.x, pos.y + altura, pos.z)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Mapa") and not Global.menu_pausa_abierto:
		visible = not visible
