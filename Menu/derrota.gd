extends CanvasLayer

@onready var texto_derrota = $Label
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	motivo_derrota(Global.motivo_derrota)
		
func _on_button_pressed() -> void:
	# quitamos la pausa antes de irnos
	get_tree().paused = false

	_desconectar_red()
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

func _desconectar_red() -> void:
	NetworkManager.notify_disconnection()
	await get_tree().create_timer(0.2).timeout
	NetworkManager.disconnect_game()
	
	SaveAndLoad.destruir_partida_y_limpiar()

func motivo_derrota(motivo_derrota: String)  -> void :
	if texto_derrota!= null:
		texto_derrota.text = motivo_derrota
