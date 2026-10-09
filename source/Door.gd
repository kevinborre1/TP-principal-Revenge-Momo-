extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var botones_necesarios: int = 2

var estado_botones: Dictionary = {}
var esta_abierta: bool = false

func _ready() -> void:
	if animation_player:
		animation_player.stop()

func actualizar_estado_boton(id_boton: int, activado: bool) -> void:
	estado_botones[id_boton] = activado
	
	if contar_botones_activos() >= botones_necesarios:
		if not esta_abierta:
			abrir_puerta()
	else:
		if esta_abierta:
			cerrar_puerta()

func contar_botones_activos() -> int:
	var activos = 0
	for presionado in estado_botones.values():
		if presionado:
			activos += 1
	return activos

func abrir_puerta() -> void:
	esta_abierta = true
	if animation_player:
		animation_player.play("Armature|Open")

func cerrar_puerta() -> void:
	esta_abierta = false
	if animation_player:
		animation_player.play_backwards("Armature|Open")
