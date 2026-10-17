extends Node

enum GameMode { RECOLECCION, VIDAS_BALSA }
var papas_atacan: bool = false 
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
	if current_count >= max_count:
		return
		
	if Global.modo_multijugador == "linea":
		# Como ya configuramos que solo el Host entra aquí, el Host le avisa del nuevo número a todos
		rpc("_actualizar_conteo_red", current_count + 1)
	else:
		_actualizar_conteo_red(current_count + 1)

# Esta función actualiza el HUD y dispara la puerta para AMBOS jugadores al mismo tiempo
@rpc("call_local", "reliable")
func _actualizar_conteo_red(nuevo_conteo: int) -> void:
	current_count = nuevo_conteo
	count_changed.emit(current_count) # ¡Acá la puerta escucha la señal y se abre sola!
	
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
