extends Area3D

@export var dano: int = 40

var jugadores_danados: Array[String] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
	
	# En línea, solo la PC dueña de ese jugador aplica el daño.
	# Si no, el daño se restaría una vez en cada PC conectada.
	if Global.modo_multijugador == "linea" and not body.is_multiplayer_authority():
		return
	
	# Solo la primera vez que pasa cada jugador
	var id := str(body.name)
	if id in jugadores_danados:
		return
	jugadores_danados.append(id)
	
	_aplicar_dano(body)

func _aplicar_dano(jugador: Node3D) -> void:
	jugador.saludActual = max(jugador.saludActual - dano, 0)
	jugador.cambioSalud.emit()

#
