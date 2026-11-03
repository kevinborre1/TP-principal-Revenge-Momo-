extends CanvasLayer

@export var altura: float = 50.0
@export var zoom: float = 40.0   # metros que se ven de lado a lado
@export var intervalo_refresco: float = 0.1   # segundos entre renders del minimapa

var objetivo: Node3D
var _tiempo := 0.0

@onready var viewport: SubViewport = $Marco/SubViewportContainer/SubViewport
@onready var camara: Camera3D = $Marco/SubViewportContainer/SubViewport/CamaraMinimapa
@onready var flecha: TextureRect = $Marco/Flecha

func _ready() -> void:
	viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	camara.near = 0.1
	camara.far = altura + 20.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = zoom
	camara.rotation_degrees = Vector3(-90, 0, 0)  # mirando hacia abajo
	camara.current = true

	# Ajustes baratos para un viewport chico y cenital
	viewport.use_occlusion_culling = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 0

	# Ya no renderiza solo: lo disparamos nosotros
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	# Ocultar mientras el menú de pausa está abierto
	visible = not Global.menu_pausa_abierto
	if not visible or objetivo == null or not is_instance_valid(objetivo):
		return

	_tiempo += delta
	if _tiempo < intervalo_refresco:
		return
	_tiempo = 0.0

	var pos := objetivo.global_position
	camara.global_position = Vector3(pos.x, pos.y + altura, pos.z)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
