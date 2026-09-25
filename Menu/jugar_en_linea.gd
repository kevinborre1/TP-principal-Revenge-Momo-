extends Control
var codigo_Ingresado
@onready var cartelError = $CartelError


func _on_hostear_partida_pressed() -> void:
	pass # Replace with function body.


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")
	
func _on_codigo_text_submitted(new_text: String) -> void:
	print("Se presionó Enter. Texto recibido: ", new_text)
	var codigo_Ingresado = $Codigo.text.strip_edges()
	if codigo_Ingresado == "":
		cartelError.text = "INGRESE UN CODIGO VALIDO"
		cartelError.visible = true
		cartelError.show()
		return
	cartelError.visible = false
