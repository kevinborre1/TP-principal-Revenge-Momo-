class_name ZonaMensaje
extends Area3D

@export_multiline var mensaje: String = "¡Es momento de navegar!\n1. Quien vaya a disparar a los barriles: Salta sobre el bote.\n2. Quien vaya a conducir el bote: Acércate a él y pulsa click derecho."
@export var duracion: float = 9.0
@export var mostrar_una_sola_vez: bool = true

var _ya_mostrado: bool = false
var _en_cooldown: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _ya_mostrado or _en_cooldown:
		return
		
	if body.is_in_group("Jugador") or body.is_in_group("jugadores"):
		if Global.modo_multijugador == "linea":
			_mostrar_mensaje_en_todos.rpc()
		else:
			_mostrar_mensaje_en_todos()

@rpc("any_peer", "call_local", "reliable")
func _mostrar_mensaje_en_todos() -> void:
	if _ya_mostrado or _en_cooldown:
		return
		
	if mostrar_una_sola_vez:
		_ya_mostrado = true
	else:
		_en_cooldown = true
		
	_crear_o_actualizar_cartel(mensaje, duracion)
	
	if not mostrar_una_sola_vez:
		await get_tree().create_timer(duracion + 2.0).timeout
		_en_cooldown = false

func _crear_o_actualizar_cartel(texto: String, tiempo: float) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
		
	# Si ya había un cartel mostrándose en pantalla, lo eliminamos para poner el nuevo
	var cartel_previo := escena.get_node_or_null("CanvasAvisoZona")
	if cartel_previo:
		cartel_previo.queue_free()
		
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasAvisoZona"
	canvas.layer = 15
	escena.add_child(canvas)
	
	var panel := PanelContainer.new()
	# Lo anclamos a la derecha, justo debajo del minimapa (zona marcada en rojo)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.33
	panel.anchor_bottom = 0.33
	panel.offset_left = -360.0
	panel.offset_right = -16.0
	panel.offset_top = 0.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	
	# Estilo visual del recuadro (semi-transparente con borde)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	estilo.border_color = Color(0.85, 0.65, 0.2, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", estilo)
	
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(310, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(label)
	
	canvas.add_child(panel)
	
	# Animación suave de entrada y salida
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.tween_interval(tiempo)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	if is_instance_valid(canvas):
		canvas.queue_free()
