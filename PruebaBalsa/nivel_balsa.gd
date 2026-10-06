extends Node3D

func _ready() -> void:
	print("Nivel balsa ready")
	GameManager.set_mode(GameManager.GameMode.VIDAS_BALSA, 3)
