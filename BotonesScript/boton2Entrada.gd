extends Area3D

@export var id_boton: int = 2 # Pon 1 para el primer botón y 2 para el segundo
@export var puerta_destino: Node3D  # Arrastra la puerta aquí desde el Inspector

#sonidos
const SFX_BOTON = preload("res://sonidos/boton.wav")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Puedes cambiar "is_in_group(\"Jugador\")" según cómo identifiques a tus personajes
	reproducir_sfx_3d(SFX_BOTON)
	print("Entre")
	if body.is_in_group("Jugador"):
		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
			puerta_destino.actualizar_estado_boton(id_boton, false)
			
# Sonidos en 3D que el otro escuchará
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_2d.bus = &"SFX"
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0 # Distance in meters at which the other player can hear it
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
