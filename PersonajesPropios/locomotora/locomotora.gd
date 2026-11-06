extends StaticBody3D 

@onready var exclamation_mark = $ExclamationMark
var is_player_close = false

func _ready() -> void:
	# Nos aseguramos de que el signo de exclamación empiece oculto
	if exclamation_mark:
		exclamation_mark.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Usamos una acción personalizada (por ejemplo, "interact") en lugar de ui_accept
	# para evitar conflictos si el jugador presiona espacio cerca del NPC.
	if is_player_close and event.is_action_pressed("interact"):
		print("Iniciar dialogo")

# Cambiado a body_entered para detectar al Jugador (CharacterBody3D)
func _on_area_3d_body_entered(body: Node3D) -> void:
	# Verificamos que sea el jugador (puedes agregar al jugador al grupo "player")
	if body.is_in_group("player"):
		exclamation_mark.visible = true
		is_player_close = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		exclamation_mark.visible = false
		is_player_close = false
