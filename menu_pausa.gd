extends CanvasLayer
var codigo = NetworkManager.get_node("TubeClient").session_id
@onready var panel_logros = $"../Logros"

func _ready() -> void:
	Global.menu_pausa_abierto = false
	hide()
	Ponercodigo()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = not visible
		Global.menu_pausa_abierto = visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			panel_logros.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
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
	cartel.text = codigo


func _on_logros_pressed() -> void:
	panel_logros.visible = not panel_logros.visible
