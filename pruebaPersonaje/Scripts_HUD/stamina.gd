extends ProgressBar

@export var player: Player

func _ready() -> void:
	# Nos aseguramos de que el jugador esté asignado en el Inspector
	if player:
		# Conectamos la señal al método que actualiza la barra
		player.cambioStamina.connect(actualizar_ui)
		
		# Forzamos una primera actualización al cargar el juego
		actualizar_ui()

func actualizar_ui() -> void:
	max_value = player.StaminaMax
	value = player.StaminaActual
