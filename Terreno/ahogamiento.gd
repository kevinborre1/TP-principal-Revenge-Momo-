extends Area3D

@export var dano: int = 100

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
	if Global.modo_multijugador == "linea" and not body.is_multiplayer_authority():
		return
	
	_aplicar_dano(body)

func _aplicar_dano(jugador: Node3D) -> void:
	jugador._recibir_danio_red(100)
	jugador.cambioSalud.emit()
