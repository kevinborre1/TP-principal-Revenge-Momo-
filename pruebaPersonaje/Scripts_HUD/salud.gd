extends HBoxContainer

@export var player: Player
@export var tex_completo: Texture2D
@export var tex_medio: Texture2D
@export var tex_vacio: Texture2D

var cantidad_corazones: int = 5
var array_corazones: Array[TextureRect] = []

func _ready() -> void:
	
	add_theme_constant_override("separation", -4)
	# 1. Creamos los 5 corazones visuales y los guardamos en el array
	for i in range(cantidad_corazones):
		var corazon = TextureRect.new()
		corazon.texture = tex_completo
		
		# --- NUEVO: Configuración para agrandarlos ---
		# Cambia estos números (ej. 48, 48) para hacerlos más grandes o más chicos
		corazon.custom_minimum_size = Vector2(48, 48) 
		
		# Permite que la imagen se expanda al nuevo tamaño sin deformarse
		corazon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
		corazon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# ------------------------------------------
		
		add_child(corazon)
		array_corazones.append(corazon)
		
	if player:
		player.cambioSalud.connect(actualizar_ui)
		actualizar_ui()

func actualizar_ui() -> void:
	if not player: return
	
	# Matemáticas dinámicas: Si tienes 100 de salud, cada corazón vale 20. Medio vale 10.
	var hp_por_corazon = player.saludMax / float(cantidad_corazones)
	var hp_por_mitad = hp_por_corazon / 2.0
	
	for i in range(cantidad_corazones):
		# Vemos en qué tramo de salud actúa este corazón específico (ej: el primero ve de 0 a 20)
		var hp_base_del_corazon = i * hp_por_corazon
		var hp_sobrante = player.saludActual - hp_base_del_corazon
		
		# Decidimos qué textura poner según la salud restante del jugador en ese tramo
		if hp_sobrante >= hp_por_corazon:
			array_corazones[i].texture = tex_completo
		elif hp_sobrante >= hp_por_mitad:
			array_corazones[i].texture = tex_medio
		else:
			array_corazones[i].texture = tex_vacio
