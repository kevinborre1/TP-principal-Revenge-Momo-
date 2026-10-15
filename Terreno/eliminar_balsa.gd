extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Balsa"):
		return

	if Global.modo_multijugador == "linea":
		if not multiplayer.is_server():
			return

	body.eliminar_balsa()
