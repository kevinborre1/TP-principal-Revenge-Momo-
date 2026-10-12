extends Node3D

@export var Pepitas_necesarias: int = 1
var esta_abierta: bool = false
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func ChequeoPepita(pepitas_del_jugador: int) -> void:
	if pepitas_del_jugador >= Pepitas_necesarias:
		if not esta_abierta:
			abrir_puerta()

func abrir_puerta() -> void:
	esta_abierta = true
	if animation_player:
		animation_player.play("Animation")
