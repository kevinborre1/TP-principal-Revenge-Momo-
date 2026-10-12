extends ProgressBar

@export var player: Player

func _ready() -> void:
	player.cambioSalud.connect(actualizar_ui)
	actualizar_ui();

func actualizar_ui():
	value = player.saludActual * 100 / player.saludMax
