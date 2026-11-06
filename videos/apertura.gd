extends VideoStreamPlayer

func _ready() -> void:
	# Nos aseguramos de conectar la señal por código por si no quedó vinculada en el editor
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)
	
	# Reproducimos el video automáticamente al entrar
	play()

func _on_finished() -> void:
	# 1. Ocultamos o detenemos el video para que no quede la imagen congelada de fondo
	stop()
	visible = false
	
	# 2. Cambiamos inmediatamente al terreno del juego
	get_tree().change_scene_to_file("res://Terreno/terreno.tscn")
