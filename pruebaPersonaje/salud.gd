extends ProgressBar

@export var player: Player

func _ready() -> void:
	player.cambioSalud.connect(update)
	update();

func update():
	value = player.saludActual * 100 / player.saludMax
