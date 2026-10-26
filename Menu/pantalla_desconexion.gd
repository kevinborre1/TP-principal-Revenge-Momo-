extends CanvasLayer


func _on_button_pressed() -> void:
	# quitamos la pausa antes de irnos
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")
