extends CanvasLayer

# --- NUEVAS VARIABLES DE RED ---
signal movimiento_realizado(desde: Vector2, hasta: Vector2, tipo_coronacion: int)
var mi_color: int = -1 # -1: Local, 0: Blancas, 1: Negras
var origen_coronacion: Vector2 = Vector2(-1, -1)

@onready var grid = $GridContainer

var color_claro = Color("F0D9B5")
var color_oscuro = Color("B58863")
var color_resaltado = Color("8CA252") 
var color_movimiento = Color("A3B568") 
var color_jaque = Color("E06666") 

var juego_logico: JuegoAjedrez
var coordenada_seleccionada: Vector2 = Vector2(-1, -1)
var movimientos_resaltados: Array[Vector2] = [] 
var pos_en_coronacion: Vector2 = Vector2(-1, -1) 

var texturas = {
	PiezaAjedrez.ColorPieza.BLANCO: {
		PiezaAjedrez.Tipo.PEON: preload("res://minijuegoAjedrez/assets/w_Pawn.png"),
		PiezaAjedrez.Tipo.TORRE: preload("res://minijuegoAjedrez/assets/w_Rook.png"),
		PiezaAjedrez.Tipo.CABALLO: preload("res://minijuegoAjedrez/assets/w_Knight.png"),
		PiezaAjedrez.Tipo.ALFIL: preload("res://minijuegoAjedrez/assets/w_Bishop.png"),
		PiezaAjedrez.Tipo.REINA: preload("res://minijuegoAjedrez/assets/w_Queen.png"),
		PiezaAjedrez.Tipo.REY: preload("res://minijuegoAjedrez/assets/w_King.png")
	},
	PiezaAjedrez.ColorPieza.NEGRO: {
		PiezaAjedrez.Tipo.PEON: preload("res://minijuegoAjedrez/assets/b_Pawn.png"),
		PiezaAjedrez.Tipo.TORRE: preload("res://minijuegoAjedrez/assets/b_Rook.png"),
		PiezaAjedrez.Tipo.CABALLO: preload("res://minijuegoAjedrez/assets/b_Knight.png"),
		PiezaAjedrez.Tipo.ALFIL: preload("res://minijuegoAjedrez/assets/b_Bishop.png"),
		PiezaAjedrez.Tipo.REINA: preload("res://minijuegoAjedrez/assets/b_Queen.png"),
		PiezaAjedrez.Tipo.REY: preload("res://minijuegoAjedrez/assets/b_King.png")
	}
}

func _ready() -> void:
	generar_tablero_visual()
	juego_logico = JuegoAjedrez.new()
	add_child(juego_logico)
	juego_logico.iniciar_partida()
	actualizar_vista_completa()

func generar_tablero_visual() -> void:
	var rango_filas = range(8)
	var rango_columnas = range(8)
	
	# Si soy el jugador de las Negras, invertimos el orden visual del tablero
	if mi_color == 1:
		rango_filas = range(7, -1, -1)
		rango_columnas = range(7, -1, -1)
		
	for fila in rango_filas:
		for columna in rango_columnas:
			var casilla = ColorRect.new()
			casilla.custom_minimum_size = Vector2(75, 75) 
			
			if (fila + columna) % 2 == 0:
				casilla.color = color_claro
			else:
				casilla.color = color_oscuro
				
			casilla.name = str(fila) + "_" + str(columna)
			casilla.gui_input.connect(_on_casilla_clic.bind(columna, fila))
			grid.add_child(casilla)
			
# --- LÓGICA DE INTERACCIÓN ---
func _on_casilla_clic(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		manejar_seleccion(Vector2(x, y))

func manejar_seleccion(coord_click: Vector2) -> void:
	if pos_en_coronacion != Vector2(-1, -1):
		return
	if mi_color != -1 and mi_color != juego_logico.turno_actual:
		return

	var pieza_clickeada = juego_logico.tablero.obtener_pieza(coord_click.x, coord_click.y)
	
	if coordenada_seleccionada == Vector2(-1, -1):
		if pieza_clickeada != null and pieza_clickeada.color == juego_logico.turno_actual:
			coordenada_seleccionada = coord_click
			resaltar_casilla(coordenada_seleccionada, true)
			movimientos_resaltados = juego_logico.obtener_movimientos_legales(coordenada_seleccionada)
			dibujar_movimientos_legales(movimientos_resaltados, true)
			
	else:
		if coordenada_seleccionada == coord_click:
			resaltar_casilla(coordenada_seleccionada, false)
			dibujar_movimientos_legales(movimientos_resaltados, false)
			movimientos_resaltados.clear()
			coordenada_seleccionada = Vector2(-1, -1)
			
		elif coord_click in movimientos_resaltados:
			var origen = coordenada_seleccionada
			# --- ACTUALIZADO: Usa la función que gestiona el En Passant ---
			juego_logico.ejecutar_movimiento(origen, coord_click)
			
			resaltar_casilla(origen, false)
			dibujar_movimientos_legales(movimientos_resaltados, false) 
			movimientos_resaltados.clear()
			
			if juego_logico.tablero.es_coronacion(coord_click):
				pos_en_coronacion = coord_click
				origen_coronacion = origen
				mostrar_menu_coronacion(juego_logico.turno_actual)
				coordenada_seleccionada = Vector2(-1, -1)
			else:
				cambiar_turno()
				verificar_fin_partida() # Comprueba si alguien ganó
				
				coordenada_seleccionada = Vector2(-1, -1)
				actualizar_vista_completa()
				movimiento_realizado.emit(origen, coord_click, -1) 
			
		elif pieza_clickeada != null and pieza_clickeada.color == juego_logico.turno_actual:
			resaltar_casilla(coordenada_seleccionada, false)
			dibujar_movimientos_legales(movimientos_resaltados, false)
			coordenada_seleccionada = coord_click
			resaltar_casilla(coordenada_seleccionada, true)
			movimientos_resaltados = juego_logico.obtener_movimientos_legales(coordenada_seleccionada)
			dibujar_movimientos_legales(movimientos_resaltados, true)

func cambiar_turno() -> void:
	if juego_logico.turno_actual == PiezaAjedrez.ColorPieza.BLANCO:
		juego_logico.turno_actual = PiezaAjedrez.ColorPieza.NEGRO
	else:
		juego_logico.turno_actual = PiezaAjedrez.ColorPieza.BLANCO

# --- NUEVO: FUNCIÓN PARA RECIBIR MOVIMIENTOS DEL RIVAL ---
func aplicar_movimiento_red(desde: Vector2, hasta: Vector2, tipo_coronacion: int) -> void:
	juego_logico.ejecutar_movimiento(desde, hasta) # --- ACTUALIZADO ---
	
	if tipo_coronacion != -1:
		juego_logico.tablero.coronar_peon(hasta, tipo_coronacion as PiezaAjedrez.Tipo)
		
	cambiar_turno()
	verificar_fin_partida() # Comprueba si alguien ganó
	
	coordenada_seleccionada = Vector2(-1, -1)
	dibujar_movimientos_legales(movimientos_resaltados, false)
	movimientos_resaltados.clear()
	
	actualizar_vista_completa()

func actualizar_vista_completa() -> void:
	for fila in range(8):
		for columna in range(8):
			var casilla_visual = grid.get_node(str(fila) + "_" + str(columna))
			for hijo in casilla_visual.get_children():
				hijo.queue_free()
				
			repintar_casilla_base(casilla_visual, columna, fila)
				
			var pieza_logica = juego_logico.tablero.obtener_pieza(columna, fila)
			if pieza_logica != null:
				var textura_pieza = TextureRect.new()
				textura_pieza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				textura_pieza.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				textura_pieza.set_anchors_preset(Control.PRESET_FULL_RECT)
				textura_pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE 
				textura_pieza.texture = texturas[pieza_logica.color][pieza_logica.tipo]
				casilla_visual.add_child(textura_pieza)

func resaltar_casilla(coord: Vector2, activar: bool) -> void:
	if coord.x < 0 or coord.y < 0:
		return
	var casilla = grid.get_node(str(int(coord.y)) + "_" + str(int(coord.x)))
	if activar:
		casilla.color = color_resaltado
	else:
		repintar_casilla_base(casilla, int(coord.x), int(coord.y))

func dibujar_movimientos_legales(movimientos: Array[Vector2], mostrar: bool) -> void:
	for mov in movimientos:
		var casilla = grid.get_node(str(int(mov.y)) + "_" + str(int(mov.x)))
		if mostrar:
			casilla.color = color_movimiento
		else:
			repintar_casilla_base(casilla, int(mov.x), int(mov.y))

func repintar_casilla_base(casilla: ColorRect, x: int, y: int) -> void:
	if (x + y) % 2 == 0:
		casilla.color = color_claro
	else:
		casilla.color = color_oscuro
		
	var pieza = juego_logico.tablero.obtener_pieza(x, y)
	if pieza != null and pieza.tipo == PiezaAjedrez.Tipo.REY:
		if juego_logico.esta_en_jaque(pieza.color):
			casilla.color = color_jaque

func mostrar_menu_coronacion(color: PiezaAjedrez.ColorPieza) -> void:
	var panel = PanelContainer.new()
	panel.name = "MenuCoronacion"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var titulo = Label.new()
	titulo.text = "¡Elige coronación!"
	vbox.add_child(titulo)
	
	var opciones = [
		{"tipo": PiezaAjedrez.Tipo.REINA, "nombre": "Reina"},
		{"tipo": PiezaAjedrez.Tipo.TORRE, "nombre": "Torre"},
		{"tipo": PiezaAjedrez.Tipo.ALFIL, "nombre": "Alfil"},
		{"tipo": PiezaAjedrez.Tipo.CABALLO, "nombre": "Caballo"}
	]
	
	for op in opciones:
		var btn = Button.new()
		btn.text = op["nombre"]
		btn.pressed.connect(_on_pieza_coronada_seleccionada.bind(op["tipo"], panel))
		vbox.add_child(btn)
		
	add_child(panel)

func _on_pieza_coronada_seleccionada(tipo: PiezaAjedrez.Tipo, panel: PanelContainer) -> void:
	juego_logico.tablero.coronar_peon(pos_en_coronacion, tipo)
	panel.queue_free()
	
	var hasta = pos_en_coronacion
	var desde = origen_coronacion
	pos_en_coronacion = Vector2(-1, -1)
	origen_coronacion = Vector2(-1, -1)
	
	cambiar_turno()
	verificar_fin_partida() # Comprueba si alguien ganó
	
	actualizar_vista_completa()
	movimiento_realizado.emit(desde, hasta, tipo)

func verificar_fin_partida() -> void:
	if juego_logico.es_jaque_mate(juego_logico.turno_actual):
		var ganador = "Blancas" if juego_logico.turno_actual == PiezaAjedrez.ColorPieza.NEGRO else "Negras"
		mostrar_cartel_final("¡JAQUE MATE!\nGanaron las " + ganador)

func mostrar_cartel_final(mensaje: String) -> void:
	# 1. Usamos un CenterContainer que ocupe toda la pantalla para un centrado absoluto
	var center = CenterContainer.new()
	center.name = "CartelVictoria"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var label = Label.new()
	label.text = mensaje
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("E06666"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(label)
	
	# Espaciador para separar el texto del botón
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "Aceptar y Salir"
	btn.custom_minimum_size = Vector2(200, 50)
	
	# 2. Conectamos el botón a nuestra nueva función de salida
	btn.pressed.connect(_on_boton_aceptar_victoria)
	
	vbox.add_child(btn)
	add_child(center)

func _on_boton_aceptar_victoria() -> void:
	# Simulamos por código que el jugador presionó la tecla ESC.
	# Esto hará que zonaAjedrez.gd capture la tecla, cierre la interfaz, 
	# devuelva el control al jugador y avise al servidor si estabas online.
	var ev = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
