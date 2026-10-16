extends Area3D

@export var oleada_1: Array[CharacterBody3D]
@export var oleada_2: Array[CharacterBody3D]
@export var jefe: CharacterBody3D

var fase_actual: int = 0
var enemigos_restantes: int = 0
var ataque_iniciado: bool = false

func _ready() -> void:
	add_to_group("ActivadorOleadas")
	body_entered.connect(_on_puerta_cruzada)
	
func _on_puerta_cruzada(body: Node3D) -> void:
	if not multiplayer.is_server() or ataque_iniciado:
		return
	
	if body.is_in_group("Jugador"):
		ataque_iniciado = true
		GameManager.papas_atacan = true # Asegura que puedan moverse y atacar
		print("El jugador activó el ataque enemigo")
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
		# Fase 4: Ya murieron las 2 oleadas y el jefe
		print("¡Todas las oleadas y el jefe fueron derrotados!")
		return
	
	enemigos_restantes = 0
	
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and not enemigo.is_queued_for_deletion():
			if not enemigo.murio.is_connected(_on_enemigo_muerto):
				enemigo.murio.connect(_on_enemigo_muerto)
				
			enemigo.activar_enemigo.rpc()
			enemigos_restantes += 1
	
	if enemigos_restantes == 0:
		iniciar_fase(fase_actual + 1)

func _on_enemigo_muerto() -> void:
	enemigos_restantes -= 1
	
	if enemigos_restantes <= 0:
		iniciar_fase(fase_actual + 1)

# Restaura el estado exacto de las oleadas al cargar partida (en Host y Cliente) ---
@rpc("authority", "call_local", "reliable")
func restaurar_oleada_guardada(iniciado: bool, fase_guardada: int, atacan: bool) -> void:
	ataque_iniciado = iniciado
	fase_actual = fase_guardada
	GameManager.papas_atacan = atacan
	
	if not ataque_iniciado or fase_guardada <= 0:
		return
		
	# 1. Borrar oleadas que ya habían sido derrotadas antes de guardar
	if fase_guardada > 1:
		for e in oleada_1:
			if is_instance_valid(e): e.queue_free()
	if fase_guardada > 2:
		for e in oleada_2:
			if is_instance_valid(e): e.queue_free()
	if fase_guardada > 3:
		if is_instance_valid(jefe): jefe.queue_free()
		
	# 2. Si el combate seguía en curso (fases 1, 2 o 3), el Servidor reactiva la fase actual
	if multiplayer.is_server() and fase_guardada >= 1 and fase_guardada <= 3:
		iniciar_fase(fase_guardada)
