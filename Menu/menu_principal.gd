extends Control
func _on_jugar_local_pressed() -> void:
	Global.modo_multijugador = "local"
	Global.mapa_seleccionado = "terreno"
	get_tree().change_scene_to_file("res://Terreno/terreno.tscn")

func _on_jugar_en_linea_pressed() -> void:
	Global.modo_multijugador = "linea"
	Global.mapa_seleccionado = "terreno"
	get_tree().change_scene_to_file("res://Menu/JugarEnLinea.tscn")
	
func _on_opciones_pressed() -> void:
	pass

func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/Creditos.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
func _on_tutorial_pressed() -> void:
	Global.modo_multijugador = "linea"
	Global.mapa_seleccionado = "tutorial"
	get_tree().change_scene_to_file("res://Tutorial/Tutorial.tscn")


func _on_reglas_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/Reglas.tscn")
