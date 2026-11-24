extends CanvasLayer

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var boton_creditos: Button = $Button # O el nombre exacto de tu nodo botón
@onready var ruta: String = ""
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)
	
	video_player.visible = false

func _on_button_pressed() -> void:
	SaveAndLoad.actualizar_logro("EscapasteDelMomo")
	boton_creditos.disabled = true
	
	video_player.visible = true
	video_player.play()

func _on_video_finished() -> void:
	get_tree().paused = false
	ruta = SaveAndLoad.rutaUtilizada
	borrar_guardado(ruta)
	_desconectar_red()
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")
	
func _desconectar_red() -> void:
	NetworkManager.notify_disconnection()
	await get_tree().create_timer(0.2).timeout
	NetworkManager.disconnect_game()
	
	SaveAndLoad.destruir_partida_y_limpiar()
func borrar_guardado(ruta: String) -> bool:
	if ruta == "" or not FileAccess.file_exists(ruta):
		print("No hay guardado para borrar en: ", ruta)
		return false
	
	var err := DirAccess.remove_absolute(ruta)
	if err != OK:
		push_warning("No se pudo borrar %s (error %d)" % [ruta, err])
		return false
	
	print("Guardado borrado: ", ruta)
	return true
