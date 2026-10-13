extends Node3D

@export var Pepitas_necesarias: int = 1
var esta_abierta: bool = false
@onready var animation_player: AnimationPlayer = $AnimationPlayer

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
	if animation_player:
		animation_player.play("Animation")
		print("¡Pepita conseguida! Abriendo puerta automáticamente...")
