extends CanvasLayer

@export var altura: float = 50.0
@export var zoom: float = 40.0   # metros que se ven de lado a lado

var objetivo: Node3D

@onready var camara: Camera3D = $Marco/SubViewportContainer/SubViewport/CamaraMinimapa
@onready var flecha: TextureRect = $Marco/Flecha

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = zoom
	camara.rotation_degrees = Vector3(-90, 0, 0)  # mirando hacia abajo
	camara.current = true  # solo afecta a su SubViewport, no a la pantalla principal

func _process(_delta: float) -> void:
	# Ocultar mientras el menú de pausa está abierto
	visible = not Global.menu_pausa_abierto
	if not visible or objetivo == null or not is_instance_valid(objetivo):
		return
	var pos := objetivo.global_position
	camara.global_position = Vector3(pos.x, pos.y + altura, pos.z)
