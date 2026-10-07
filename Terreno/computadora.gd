extends Area3D

signal jugador_interactuo(jugador: Node3D)

var jugador_en_rango: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	print("Body entered: ", body.name, " grupos: ", body.get_groups())
	if body.is_in_group("jugadores"):
		jugador_en_rango = body
		print("Jugador detectado en rango")

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_en_rango:
		jugador_en_rango = null

func _process(_delta: float) -> void:
	if jugador_en_rango and jugador_en_rango.is_multiplayer_authority() and Input.is_action_just_pressed("interactuar"):
		print("Interactuando!")
		jugador_en_rango.abrir_minijuego()
