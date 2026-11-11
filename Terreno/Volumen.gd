extends CanvasLayer

@onready var fondo: TextureRect = $TextureRect
var _etiqueta: Label
var _deslizador: HSlider


func _ready() -> void:
	hide()
	
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE

	var valor := int(round(SaveAndLoad.configuracion.volumen * 100.0))

	# Contenedor centrado encima del fondo
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caja.offset_top += 40     
	caja.offset_bottom += 40
	caja.custom_minimum_size = Vector2(400, 0)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.add_theme_constant_override("separation", 16)
	fondo.add_child(caja)

	_etiqueta = Label.new()
	_etiqueta.text = "Volumen general: %d%%" % valor
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 28)
	caja.add_child(_etiqueta)

	_deslizador = HSlider.new()
	_deslizador.min_value = 0
	_deslizador.max_value = 100
	_deslizador.step = 1
	_deslizador.value = valor
	_deslizador.custom_minimum_size = Vector2(400, 30)
	_deslizador.value_changed.connect(_on_volumen_cambiado)
	caja.add_child(_deslizador)


func _on_volumen_cambiado(valor: float) -> void:
	_etiqueta.text = "Volumen general: %d%%" % int(valor)
	SaveAndLoad.configuracion.volumen = valor / 100.0
	MenuOpciones._aplicar_volumen()  # aplica el cambio al bus de audio en el momento


# Guarda al soltar, no en cada movimiento, para no escribir el archivo cientos de veces
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SaveAndLoad.guardar_configuracion()

func _on_button_pressed() -> void:
	SaveAndLoad.guardar_configuracion()
	hide() 
