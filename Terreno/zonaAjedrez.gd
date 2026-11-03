
extends Area3D
## Zona de la mesa de ajedrez.
## - Al entrar el jugador muestra "Presiona E".
## - E abre el minijuego 2D de ajedrez.
## - Escape lo cierra.
##
## Requisitos:
##  * El jugador debe estar en el grupo "player" (Nodo > Grupos).
##  * Este script va en un Area3D con un CollisionShape3D (BoxShape3D).

const ESCENA_MINIJUEGO := preload("res://minijuegoAjedrez/InterfazAjedrez.tscn")
const GRUPO_JUGADOR := "jugadores"
const TEXTO_AVISO := "Presiona E"

var jugador_dentro := false
var minijuego: Node = null
var capa: CanvasLayer
var etiqueta: Label
var modo_mouse_previo: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	# Necesario para seguir recibiendo input (Escape) mientras el juego esta pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Capa 2D por encima del mundo 3D: aca van el label y el minijuego.
	capa = CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	etiqueta = Label.new()
	etiqueta.text = TEXTO_AVISO
	etiqueta.visible = false
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta.add_theme_font_size_override("font_size", 32)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 8)
	capa.add_child(etiqueta)
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	etiqueta.offset_bottom = -80.0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(GRUPO_JUGADOR):
		jugador_dentro = true
		_actualizar_etiqueta()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(GRUPO_JUGADOR):
		jugador_dentro = false
		_actualizar_etiqueta()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_E and jugador_dentro and minijuego == null:
		_abrir_minijuego()
		get_tree().call_group("ocultar_en_minijuego", "hide")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and minijuego != null:
		_cerrar_minijuego()
		get_tree().call_group("ocultar_en_minijuego", "show")
		get_viewport().set_input_as_handled()


func _abrir_minijuego() -> void:
	minijuego = ESCENA_MINIJUEGO.instantiate()
	capa.add_child(minijuego)

	# Pausa el mundo 3D (jugador, enemigos) y libera el mouse para jugar.
	get_tree().paused = true
	modo_mouse_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_actualizar_etiqueta()


func _cerrar_minijuego() -> void:
	if is_instance_valid(minijuego):
		minijuego.queue_free()
	minijuego = null

	get_tree().paused = false
	Input.mouse_mode = modo_mouse_previo
	_actualizar_etiqueta()


func _actualizar_etiqueta() -> void:
	etiqueta.visible = jugador_dentro and minijuego == null
