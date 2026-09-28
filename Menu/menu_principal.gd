extends Control
func _on_jugar_local_pressed() -> void:
	Global.modo_multijugador = "local"
	get_tree().change_scene_to_file("res://Menu/Reglas.tscn")

func _on_jugar_en_linea_pressed() -> void:
	Global.modo_multijugador = "linea"
	get_tree().change_scene_to_file("res://Menu/Reglas.tscn")

func _on_opciones_pressed() -> void:
	pass

func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/Creditos.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
