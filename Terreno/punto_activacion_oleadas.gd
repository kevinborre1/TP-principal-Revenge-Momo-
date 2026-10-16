extends Area3D

@export var oleada_1: Array[CharacterBody3D]
@export var oleada_2: Array[CharacterBody3D]
@export var jefe: CharacterBody3D

var fase_actual: int = 0
var enemigos_restantes: int = 0
var ataque_iniciado: bool = false

func _ready() -> void:
	body_entered.connect(_on_puerta_cruzada)
	
func _on_puerta_cruzada(body: Node3D) -> void:
	if not multiplayer.is_server() or ataque_iniciado:
		return
	
	if body.is_in_group("Jugador"):
		ataque_iniciado = true
		print("El jugador activo el ataque enemigo")
		iniciar_fase(1)
	
func iniciar_fase(fase: int) -> void:
	fase_actual = fase
	var enemigos: Array = []
	
	if fase == 1:
		enemigos = oleada_1
	elif fase == 2:
		enemigos = oleada_2
	elif fase == 3:
		if is_instance_valid(jefe):
			enemigos = [jefe]
	else:
		return
	
	enemigos_restantes = 0
	
	for enemigo in enemigos:
		if is_instance_valid(enemigo):
			if not enemigo.murio.is_connected(_on_enemigo_muerto):
				enemigo.murio.connect(_on_enemigo_muerto)
				
			enemigo.rpc("activar_enemigo")
			enemigos_restantes += 1
	
	if enemigos_restantes == 0:
		iniciar_fase(fase_actual + 1)

func _on_enemigo_muerto() -> void:
	enemigos_restantes -= 1
	
	if enemigos_restantes <= 0:
		iniciar_fase(fase_actual + 1)
