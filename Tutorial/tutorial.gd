extends Node3D

@export var punto_inicio: Vector3 = Vector3(-3, 0, -36)
const ESCENA_DESTINO := "res://Terreno/terreno.tscn"
const SEGUNDOS_PARA_SALTAR := 2.5

var player_scene = preload("res://pruebaPersonaje/player.tscn")

var _modo_multijugador_original: String = ""
var _tiempo_espacio: float = 0.0
var _cambiando_escena: bool = false

var _barra_progreso: ProgressBar
var _contenedor_ui: PanelContainer

func _ready() -> void:
	MenuOpciones.aplicar_calidad_terreno(get_node_or_null("Entorno/Terrain3D"))

	#TEMPORAL
	# Guardamos el modo elegido ("local" o "linea") y forzamos "local" durante el tutorial
	# para que el jugador se mueva sin esperar conexión de red
	_modo_multijugador_original = Global.modo_multijugador
	Global.modo_multijugador = "local"

	add_player(1)
	_crear_ui_saltar()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if _cambiando_escena:
		return
		
	if Input.is_physical_key_pressed(KEY_SPACE):
		_tiempo_espacio += delta
		_barra_progreso.value = (_tiempo_espacio / SEGUNDOS_PARA_SALTAR) * 100.0
		_contenedor_ui.modulate.a = 1.0
		
		if _tiempo_espacio >= SEGUNDOS_PARA_SALTAR:
			ir_al_juego_principal()
	else:
		if _tiempo_espacio > 0.0:
			_tiempo_espacio = maxf(0.0, _tiempo_espacio - delta * 2.5)
			_barra_progreso.value = (_tiempo_espacio / SEGUNDOS_PARA_SALTAR) * 100.0
		_contenedor_ui.modulate.a = 0.75

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	add_child(new_player)
	new_player.global_position = punto_inicio  

func ir_al_juego_principal() -> void:
	if _cambiando_escena:
		return
	_cambiando_escena = true
	
	# Restauramos "local" o "linea" antes de entrar a terreno.tscn
	Global.modo_multijugador = _modo_multijugador_original
	get_tree().change_scene_to_file(ESCENA_DESTINO)

func _crear_ui_saltar() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	
	_contenedor_ui = PanelContainer.new()
	_contenedor_ui.anchor_left = 0.5
	_contenedor_ui.anchor_right = 0.5
	_contenedor_ui.anchor_top = 1.0
	_contenedor_ui.anchor_bottom = 1.0
	_contenedor_ui.offset_left = -220.0
	_contenedor_ui.offset_right = 220.0
	_contenedor_ui.offset_top = -95.0
	_contenedor_ui.offset_bottom = -25.0
	
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	estilo.border_color = Color(0.85, 0.65, 0.2, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	_contenedor_ui.add_theme_stylebox_override("panel", estilo)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_contenedor_ui.add_child(vbox)
	
	var texto := Label.new()
	texto.text = "Mantené presionado [ESPACIO] para saltar el tutorial"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 16)
	vbox.add_child(texto)
	
	_barra_progreso = ProgressBar.new()
	_barra_progreso.min_value = 0.0
	_barra_progreso.max_value = 100.0
	_barra_progreso.value = 0.0
	_barra_progreso.show_percentage = false
	_barra_progreso.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(_barra_progreso)
	
	canvas.add_child(_contenedor_ui)
