extends CanvasLayer

@export var altura: float = 8.0
@export var zoom: float = 120.0

var objetivo: Node3D

@onready var camara: Camera3D = %CamaraMapa
@onready var marcador: TextureRect = %MarcadorJugador
@onready var viewport_mapa: SubViewport = %ViewportMapa

func _ready() -> void:
	visible = false
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = zoom
	camara.rotation_degrees = Vector3(-90, 0, 0)
	camara.current = true
	_actualizar_render()

func _process(_delta: float) -> void:
	if Global.menu_pausa_abierto and visible:
		visible = false
		_actualizar_render()
	if not visible or objetivo == null or not is_instance_valid(objetivo):
		return
	var pos := objetivo.global_position
	camara.global_position = Vector3(pos.x, pos.y + altura, pos.z)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Mapa") and not Global.menu_pausa_abierto:
		visible = not visible
		_actualizar_render()

# Solo renderiza el mundo mientras el mapa está abierto
func _actualizar_render() -> void:
	if visible:
		viewport_mapa.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		viewport_mapa.render_target_update_mode = SubViewport.UPDATE_DISABLED
