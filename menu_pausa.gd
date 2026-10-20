extends CanvasLayer
@onready var panel_logros = $"../Logros"

func _ready() -> void:
	Global.menu_pausa_abierto = false
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = not visible
		Global.menu_pausa_abierto = visible
		if visible:
			Ponercodigo()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			panel_logros.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if _jugador_local_en_minijuego():
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _jugador_local_en_minijuego() -> bool:
	for j in get_tree().get_nodes_in_group("Jugador"):
		var es_mio = (Global.modo_multijugador != "linea") or j.is_multiplayer_authority()
		if es_mio and j.get("minijuego_instance") != null:
			return true
	return false
			
func _on_salir_menu_pressed() -> void:
	NetworkManager.notify_disconnection()
	await get_tree().create_timer(0.2).timeout
	NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

func _on_salir_escritorio_pressed() -> void:
	NetworkManager.notify_disconnection()
	await get_tree().create_timer(0.2).timeout
	NetworkManager.disconnect_game()
	get_tree().quit()
	
func Ponercodigo() -> void:
	var cartel = $CodigoSesion
	cartel.text = NetworkManager.get_node("TubeClient").session_id


func _on_logros_pressed() -> void:
	panel_logros.visible = not panel_logros.visible

func _on_boton_copiar_codigo_pressed() -> void:
	var codigo_actual = NetworkManager.get_node("TubeClient").session_id
	if codigo_actual != "":
		DisplayServer.clipboard_set(codigo_actual)
		print("Código copiado al portapapeles desde el menú de pausa: ", codigo_actual)
