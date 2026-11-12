extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var esta_abierta: bool = false
var distancia_maxima: float = 3.0 # Distancia en metros para poder abrirla

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interactuar"):
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= distancia_maxima:
			toggle_puerta()

func toggle_puerta() -> void:
	if not esta_abierta:
		animation_player.play("abrir") # Cambiá por el nombre de tu animación
		esta_abierta = true
	else:
		animation_player.play("cerrar") # Cambiá por el nombre de tu animación
		esta_abierta = false
