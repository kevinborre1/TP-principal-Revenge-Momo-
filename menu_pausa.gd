extends CanvasLayer

func _ready() -> void:
	hide()
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
func _on_salir_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

func _on_salir_escritorio_pressed() -> void:
	get_tree().quit()
