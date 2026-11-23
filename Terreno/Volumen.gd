extends CanvasLayer

@onready var fondo: TextureRect = $TextureRect


func _ready() -> void:
	hide()

	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE

	# Contenedor centrado encima del fondo
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caja.offset_top += 75
	caja.offset_bottom += 80
	caja.custom_minimum_size = Vector2(400, 0)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.add_theme_constant_override("separation", 5)
	fondo.add_child(caja)

	var c = SaveAndLoad.configuracion
	_crear_fila(caja, "Volumen general", "volumen", c.volumen)
	_crear_fila(caja, "Música", "volumen_musica", c.volumen_musica)
	_crear_fila(caja, "Efectos", "volumen_sfx", c.volumen_sfx)
	_crear_fila(caja, "Cinemáticas", "volumen_cinematicas", c.volumen_cinematicas)


func _crear_fila(padre: Control, titulo: String, propiedad: String, valor_lineal: float) -> void:
	var valor := int(round(valor_lineal * 100.0))
	
	var grupo := VBoxContainer.new()
	grupo.add_theme_constant_override("separation", -3)   # texto pegado al slider
	padre.add_child(grupo)
	
	var etiqueta := Label.new()
	etiqueta.text = "%s: %d%%" % [titulo, valor]
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 28)
	padre.add_child(etiqueta)

	var deslizador := HSlider.new()
	deslizador.min_value = 0
	deslizador.max_value = 100
	deslizador.step = 1
	deslizador.value = valor
	deslizador.custom_minimum_size = Vector2(400, 24)
	deslizador.value_changed.connect(func(v: float) -> void:
		etiqueta.text = "%s: %d%%" % [titulo, int(v)]
		SaveAndLoad.configuracion.set(propiedad, v / 100.0)
		MenuOpciones._aplicar_volumen()  # aplica el cambio a los buses en el momento
	)
	padre.add_child(deslizador)


# Guarda al soltar, no en cada movimiento, para no escribir el archivo cientos de veces
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # evita que el Escape llegue al minimapa
		SaveAndLoad.guardar_configuracion()
		hide()
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SaveAndLoad.guardar_configuracion()


func _on_button_pressed() -> void:
	SaveAndLoad.guardar_configuracion()
	hide()
