extends Area3D

@onready var label_3d: Label3D = $Label3D
var jugador_en_rango: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label_3d.hide()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador") and body.is_multiplayer_authority():
		jugador_en_rango = body
		label_3d.show()

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_en_rango:
		jugador_en_rango = null
		label_3d.hide()

func _unhandled_input(event: InputEvent) -> void:
	if jugador_en_rango and event.is_action_pressed("interactuar"): # Asegúrate de que interactuar sea la tecla E
		# Aquí bloqueas los controles del jugador y le abres el CanvasLayer del ajedrez
		jugador_en_rango.bloquear_controles(true)
		jugador_en_rango.abrir_ajedrez()
