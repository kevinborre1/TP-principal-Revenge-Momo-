extends Control

func _on_jugar_pressed() -> void:
	if Global.modo_multijugador == "local":
		get_tree().change_scene_to_file("res://pruebaPersonaje/mundo.tscn")
	elif Global.modo_multijugador == "linea":
		get_tree().change_scene_to_file("res://Menu/Jugar en Linea.tscn")
	else:
		get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")
