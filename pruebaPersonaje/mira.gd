extends Control

@export var largo: float = 8.0      # largo de cada brazo desde el centro
@export var grosor: float = 2.0
@export var borde: float = 1.0
@export var color_borde: Color = Color(0, 0, 0, 0.7)

func _ready() -> void:
	add_to_group("mira")
	# Asegura que siga ejecutándose aunque se pause el árbol
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# 1. Si pausás con get_tree().paused = true, se oculta sola:
	if get_tree().paused:
		visible = false
		return
	
	# 2. Si tu menú de pausa no pausa el árbol (multijugador), 
	# detecta si el mouse está libre (Input.MOUSE_MODE_VISIBLE) para ocultarse:
	visible = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func _draw() -> void:
	var horizontal = Rect2(-largo, -grosor / 2, largo * 2, grosor)
	var vertical = Rect2(-grosor / 2, -largo, grosor, largo * 2)
	# primero el borde oscuro, después la cruz blanca encima
	draw_rect(horizontal.grow(borde), color_borde)
	draw_rect(vertical.grow(borde), color_borde)
	draw_rect(horizontal, Color.WHITE)
	draw_rect(vertical, Color.WHITE)
