extends Node3D

@export var Pepitas_necesarias: int = 2
var esta_abierta: bool = false
@onready var animation_player: AnimationPlayer = $AnimationPlayer

#sonidos
const SFX_PUERTA_MADERA = preload("res://sonidos/puerta_madera.wav")

func _ready() -> void:
	if animation_player:
		animation_player.stop()
		
	# Nos conectamos a la señal del GameManager para enterarnos cada vez que cambie el contador de pepitas
	if GameManager.has_signal("count_changed"):
		GameManager.count_changed.connect(_on_count_changed)

# Esta función se ejecuta sola cada vez que el jugador junta una pepita
func _on_count_changed(count: int) -> void:
	ChequeoPepita(count)

func ChequeoPepita(pepitas_del_jugador: int) -> void:
	if pepitas_del_jugador >= Pepitas_necesarias:
		if not esta_abierta:
			abrir_puerta()

func abrir_puerta() -> void:
	esta_abierta = true
	reproducir_sfx_3d(SFX_PUERTA_MADERA)
	if animation_player:
		animation_player.play("Animation")
		print("¡Pepita conseguida! Abriendo puerta automáticamente...")

# Sonidos en 3D que el otro escuchará
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.bus = &"SFX"
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0 # Distance in meters at which the other player can hear it
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
