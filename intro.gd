extends Control

const MENU := "res://Menu/MenuPrincipal.tscn"

@onready var video: VideoStreamPlayer = $Video
var _saliendo := false

func _ready() -> void:
	video.bus = &"Cinematicas"   # respeta el volumen de cinemáticas de Opciones
	video.finished.connect(_ir_al_menu)
	video.play()

# Cualquier tecla, clic o botón del joystick saltea el video
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
		_ir_al_menu()

func _ir_al_menu() -> void:
	if _saliendo:
		return
	_saliendo = true
	video.stop()
	get_tree().change_scene_to_file(MENU)
