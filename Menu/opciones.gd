class_name MenuOpciones
extends Control

const RESOLUCIONES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const NOMBRES_MSAA := ["Apagado", "2x", "4x"]
const NOMBRES_CALIDAD := ["Baja", "Media", "Alta"]
const ESCALAS_3D := [0.6, 0.8, 1.0]

# Acciones del Input Map que se pueden cambiar -> nombre que se muestra
const ACCIONES := {
	"Adelante": "Avanzar",
	"Atras": "Retroceder",
	"Izquierda": "Izquierda",
	"Derecha": "Derecha",
	"Salto": "Saltar",
	"disparar": "Disparar",
	"Abordar": "Subir/bajar de la balsa",
	"bailar": "Bailar",
	"hacer_ragdoll": "Ragdoll",
	"interactuar": "Interaccion"
}

const OPCIONES_FPS: Array[int] = [30, 60, 75, 144, 250]
const NOMBRES_FPS: Array[String] = ["30 FPS", "60 FPS", "75 FPS", "144 FPS", "250 FPS"]

var _panel: PanelContainer
var _contenido: VBoxContainer
var _accion_esperando := ""
var _boton_esperando: Button = null
var _boton_vsync: CheckButton = null

# Atajo a la configuración que vive en el autoload
static func _cfg() -> DataClassConfiguracion:
	return SaveAndLoad.configuracion


func _ready() -> void:
	_crear_panel()


# ---------- BOTONES DEL MENÚ ----------

func _on_salir_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")


func _on_controles_pressed() -> void:
	_nueva_pagina("Controles")
	for accion in ACCIONES:
		if not InputMap.has_action(accion):
			continue
		var fila := HBoxContainer.new()
		var etiqueta := Label.new()
		etiqueta.text = ACCIONES[accion]
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(180, 0)
		boton.text = _texto_accion(accion)
		boton.pressed.connect(_esperar_tecla.bind(accion, boton))
		fila.add_child(etiqueta)
		fila.add_child(boton)
		_contenido.add_child(fila)

	var restablecer := Button.new()
	restablecer.text = "Restablecer controles"
	restablecer.pressed.connect(_restablecer_controles)
	_contenido.add_child(restablecer)

	var guardar := Button.new()
	guardar.text = "Guardar controles"
	guardar.pressed.connect(_guardar_controles.bind(guardar))
	_contenido.add_child(guardar)


func _guardar_controles(boton: Button) -> void:
	for accion in ACCIONES:
		if not InputMap.has_action(accion):
			continue
		var eventos := InputMap.action_get_events(accion)
		if eventos.is_empty():
			continue
		var codigo := _evento_a_codigo(eventos[0])
		if codigo != 0:
			_cfg().controles[accion] = codigo

	SaveAndLoad.guardar_configuracion()  # SAVE

	boton.text = "¡Controles guardados!"
	boton.disabled = true


func _on_resolucion_pressed() -> void:
	_nueva_pagina("Resolución")
	var pantalla := DisplayServer.screen_get_size()
	var guardada := RESOLUCIONES.find(_cfg().resolucion)

	var fila := HBoxContainer.new()
	var etiqueta := Label.new()
	etiqueta.text = "Tamaño de ventana"
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lista := OptionButton.new()
	for i in RESOLUCIONES.size():
		var r: Vector2i = RESOLUCIONES[i]
		if r.x <= pantalla.x and r.y <= pantalla.y:  # solo las que entran en tu pantalla
			lista.add_item("%d x %d" % [r.x, r.y], i)
	var pos := lista.get_item_index(guardada)
	if pos >= 0:
		lista.select(pos)
	lista.item_selected.connect(_elegir_resolucion.bind(lista))
	fila.add_child(etiqueta)
	fila.add_child(lista)
	_contenido.add_child(fila)

	var completa := CheckButton.new()
	completa.text = "Pantalla completa"
	completa.button_pressed = _cfg().pantalla_completa
	completa.toggled.connect(_cambiar_pantalla_completa)
	_contenido.add_child(completa)


func _on_volumen_pressed() -> void:
	_nueva_pagina("Volumen")
	var valor := int(round(_cfg().volumen * 100.0))

	var etiqueta := Label.new()
	etiqueta.text = "Volumen general: %d%%" % valor
	_contenido.add_child(etiqueta)

	var deslizador := HSlider.new()
	deslizador.min_value = 0
	deslizador.max_value = 100
	deslizador.step = 1
	deslizador.value = valor
	deslizador.custom_minimum_size = Vector2(300, 24)
	deslizador.value_changed.connect(_cambiar_volumen.bind(etiqueta))
	_contenido.add_child(deslizador)


func _on_graficos_pressed() -> void:
	_nueva_pagina("Gráficos")

	_boton_vsync = CheckButton.new()
	_boton_vsync.text = "Sincronización vertical (VSync)"
	_boton_vsync.button_pressed = _cfg().vsync
	_boton_vsync.toggled.connect(_cambiar_vsync)
	_contenido.add_child(_boton_vsync)

	var idx_fps := OPCIONES_FPS.find(_cfg().max_fps if "max_fps" in _cfg() else 60)
	if idx_fps == -1:
		idx_fps = 1 # 60 FPS por defecto
	_contenido.add_child(_fila_opciones("Límite de FPS", NOMBRES_FPS, idx_fps, _cambiar_fps))

	_contenido.add_child(_fila_opciones("Suavizado de bordes (MSAA)", NOMBRES_MSAA, _cfg().msaa, _cambiar_msaa))
	_contenido.add_child(_fila_opciones("Calidad 3D", NOMBRES_CALIDAD, _cfg().calidad_graficos, _cambiar_escala))


# ---------- EL RECUADRO MARRÓN ----------

func _crear_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.45
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.36, 0.23, 0.13)
	estilo.border_color = Color(0.2, 0.12, 0.06)
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", estilo)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 12)
	scroll.add_child(_contenido)

	add_child(_panel)
	_panel.hide()


func _nueva_pagina(titulo: String) -> void:
	_cancelar_espera()
	for hijo in _contenido.get_children():
		hijo.queue_free()

	var encabezado := HBoxContainer.new()
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cerrar := Button.new()
	cerrar.text = "Volver"
	cerrar.pressed.connect(_cerrar_panel)
	encabezado.add_child(t)
	encabezado.add_child(cerrar)
	_contenido.add_child(encabezado)
	_panel.show()


func _cerrar_panel() -> void:
	_cancelar_espera()
	_panel.hide()


func _fila_opciones(titulo: String, opciones: Array, seleccionada: int, al_elegir: Callable) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var etiqueta := Label.new()
	etiqueta.text = titulo
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lista := OptionButton.new()
	for o in opciones:
		lista.add_item(o)
	lista.select(seleccionada)
	lista.item_selected.connect(al_elegir)
	fila.add_child(etiqueta)
	fila.add_child(lista)
	return fila


# ---------- CONTROLES ----------

func _esperar_tecla(accion: String, boton: Button) -> void:
	_cancelar_espera()
	_accion_esperando = accion
	_boton_esperando = boton
	boton.text = "Presioná una tecla..."


func _cancelar_espera() -> void:
	if _boton_esperando and is_instance_valid(_boton_esperando):
		_boton_esperando.text = _texto_accion(_accion_esperando)
	_accion_esperando = ""
	_boton_esperando = null


func _input(event: InputEvent) -> void:
	if _accion_esperando == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_cancelar_espera()
			return
		_asignar(event)
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_asignar(event)


func _asignar(evento: InputEvent) -> void:
	var accion := _accion_esperando
	var codigo := _evento_a_codigo(evento)
	if codigo != 0:
		_aplicar_control(accion, codigo)
		_cfg().controles[accion] = codigo
		SaveAndLoad.guardar_configuracion()  # SAVE
	if _boton_esperando and is_instance_valid(_boton_esperando):
		_boton_esperando.text = _texto_accion(accion)
	_accion_esperando = ""
	_boton_esperando = null


func _restablecer_controles() -> void:
	_cfg().controles = DataClassConfiguracion.new().controles
	SaveAndLoad.guardar_configuracion()  # SAVE
	InputMap.load_from_project_settings()
	_on_controles_pressed()


func _texto_accion(accion: String) -> String:
	var eventos := InputMap.action_get_events(accion)
	if eventos.is_empty():
		return "(sin asignar)"
	return _texto_evento(eventos[0])


static func _texto_evento(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var codigo: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(codigo)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "Click izquierdo"
			MOUSE_BUTTON_RIGHT:
				return "Click derecho"
			MOUSE_BUTTON_MIDDLE:
				return "Click central"
		return "Mouse %d" % ev.button_index
	return ev.as_text()


# Teclado -> keycode (siempre > 9) | Mouse -> número de botón (1 a 9)
static func _evento_a_codigo(ev: InputEvent) -> int:
	if ev is InputEventKey:
		return ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	if ev is InputEventMouseButton:
		return ev.button_index
	return 0


static func _aplicar_control(accion: String, codigo: int) -> void:
	if not InputMap.has_action(accion) or codigo == 0:
		return
	var ev: InputEvent
	if codigo <= 9:
		var m := InputEventMouseButton.new()
		m.button_index = codigo
		ev = m
	else:
		var k := InputEventKey.new()
		k.physical_keycode = codigo
		ev = k
	InputMap.action_erase_events(accion)
	InputMap.action_add_event(accion, ev)


# ---------- RESOLUCIÓN, VOLUMEN Y GRÁFICOS ----------

func _elegir_resolucion(indice: int, lista: OptionButton) -> void:
	_cfg().resolucion = RESOLUCIONES[lista.get_item_id(indice)]
	SaveAndLoad.guardar_configuracion()  # SAVE
	_aplicar_video()


func _cambiar_pantalla_completa(activa: bool) -> void:
	_cfg().pantalla_completa = activa
	SaveAndLoad.guardar_configuracion()  # SAVE
	_aplicar_video()


func _cambiar_volumen(valor: float, etiqueta: Label) -> void:
	etiqueta.text = "Volumen general: %d%%" % int(valor)
	_cfg().volumen = valor / 100.0
	SaveAndLoad.guardar_configuracion()  # SAVE
	_aplicar_volumen()


func _cambiar_vsync(activo: bool) -> void:
	_cfg().vsync = activo
	SaveAndLoad.guardar_configuracion() # SAVE
	_aplicar_graficos()

func _cambiar_fps(indice_o_valor: int) -> void:
	var fps_elegido: int = OPCIONES_FPS[indice_o_valor] if indice_o_valor < OPCIONES_FPS.size() else indice_o_valor
	_cfg().max_fps = fps_elegido
	
	# Si elige más de 60 FPS (75, 144, 250), apagamos V-Sync para no bloquear en 60 Hz
	if fps_elegido > 60:
		_cfg().vsync = false
		if _boton_vsync and is_instance_valid(_boton_vsync):
			_boton_vsync.set_pressed_no_signal(false)
		
	SaveAndLoad.guardar_configuracion() # SAVE
	_aplicar_graficos()


func _cambiar_msaa(indice: int) -> void:
	_cfg().msaa = indice
	SaveAndLoad.guardar_configuracion()  # SAVE
	_aplicar_graficos()


func _cambiar_escala(indice: int) -> void:
	_cfg().calidad_graficos = indice
	SaveAndLoad.guardar_configuracion()  # SAVE
	_aplicar_graficos()


static func _aplicar_video() -> void:
	var cfg := _cfg()
	var ventana := (Engine.get_main_loop() as SceneTree).root

	if cfg.pantalla_completa:
		ventana.mode = Window.MODE_FULLSCREEN
		return

	ventana.mode = Window.MODE_WINDOWED
	ventana.size = cfg.resolucion

	# Centrar solo cuando se ejecuta en una ventana independiente
	if DisplayServer.get_name() != "headless":
		ventana.position = (DisplayServer.screen_get_size() - cfg.resolucion) / 2


static func _aplicar_volumen() -> void:
	var v := _cfg().volumen
	AudioServer.set_bus_mute(0, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(0, linear_to_db(v))


static func _aplicar_graficos() -> void:
	var cfg := _cfg()
	var ventana := (Engine.get_main_loop() as SceneTree).root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cfg.vsync else DisplayServer.VSYNC_DISABLED)
	ventana.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][cfg.msaa]
	ventana.scaling_3d_scale = ESCALAS_3D[cfg.calidad_graficos]
	Engine.max_fps = cfg.max_fps if "max_fps" in cfg else 60

# ---------- CARGAR AL ARRANCAR ----------

# LOAD: lo llama el _ready() del autoload DataAndLoad una sola vez al iniciar el juego
static func aplicar_guardados() -> void:
	var cfg := _cfg()
	for accion in cfg.controles:
		_aplicar_control(accion, int(cfg.controles[accion]))
	_aplicar_volumen()
	_aplicar_video()
	_aplicar_graficos()
