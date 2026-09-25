extends Control


func _on_jugar_local_pressed() -> void:
	pass # Replace with function body.


func _on_jugar_en_linea_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/Jugar en Linea.tscn")


func _on_opciones_pressed() -> void:
	pass # Replace with function body.


func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/Creditos.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()
