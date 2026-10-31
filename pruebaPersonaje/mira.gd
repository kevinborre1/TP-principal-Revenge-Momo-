extends Control

@export var largo: float = 8.0      # largo de cada brazo desde el centro
@export var grosor: float = 2.0
@export var borde: float = 1.0
@export var color_borde: Color = Color(0, 0, 0, 0.7)

func _draw() -> void:
	var horizontal = Rect2(-largo, -grosor / 2, largo * 2, grosor)
	var vertical = Rect2(-grosor / 2, -largo, grosor, largo * 2)
	# primero el borde oscuro, después la cruz blanca encima
	draw_rect(horizontal.grow(borde), color_borde)
	draw_rect(vertical.grow(borde), color_borde)
	draw_rect(horizontal, Color.WHITE)
	draw_rect(vertical, Color.WHITE)
