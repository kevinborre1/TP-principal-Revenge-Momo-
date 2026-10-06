extends Node

enum GameMode { RECOLECCION, VIDAS_BALSA }

var current_mode: GameMode = GameMode.RECOLECCION
var max_count: int = 3
var current_count: int = 0

signal mode_changed(new_mode: GameMode, max_count: int)
signal count_changed(current_count: int)
signal objective_completed(mode: GameMode)


func set_mode(mode: GameMode, max_items: int = 3) -> void:
	current_mode = mode
	max_count = max_items
	current_count = 0
	mode_changed.emit(current_mode, max_count)


func register_event() -> void:
	# "recolectar grano" o "recibir golpe", según el modo activo
	if current_count >= max_count:
		return
	
	current_count += 1
	count_changed.emit(current_count)
	
	if current_count >= max_count:
		objective_completed.emit(current_mode)
		_handle_mode_completion()


func _handle_mode_completion() -> void:
	match current_mode:
		GameMode.RECOLECCION:
			print("Recolección completa")
			# ej: desbloquear puerta, avanzar diálogo, etc.
		GameMode.VIDAS_BALSA:
			print("Game over - balsa destruida")
			get_tree().change_scene_to_file("res://ui/game_over.tscn")
