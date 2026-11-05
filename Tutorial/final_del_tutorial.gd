extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador") and not body.is_in_group("jugadores"):
		return
	
	var escena_actual = get_tree().current_scene
	if escena_actual and escena_actual.has_method("ir_al_juego_principal"):
		escena_actual.ir_al_juego_principal()
	else:
		get_tree().change_scene_to_file("res://Terreno/terreno.tscn")
