extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var atraveso_puerta: Area3D = $AtravesoPuerta
@onready var video_player: VideoStreamPlayer = $"../VideoVictor" # O la ruta a tu nodo de video

@export var botones_necesarios: int = 2
@export var tiempo_espera_maximo: float = 10.0 # Tiempo máxima abierta si nadie pasa
@export var tiempo_limite_botones: float = 5.0 # Margen para apretar el segundo botón en solitario

var estado_botones: Dictionary = {
	1: false,
	2: false
}

var esta_abierta: bool = false
var cerrando: bool = false
var cinematica_reproducida: bool = false
var timer_reinicio: SceneTreeTimer = null

func _ready() -> void:
	if animation_player:
		animation_player.stop()
		
	if atraveso_puerta:
		if not atraveso_puerta.body_entered.is_connected(_on_atraveso_puerta_body_entered):
			atraveso_puerta.body_entered.connect(_on_atraveso_puerta_body_entered)
	else:
		print("ERROR: El nodo 'AtravesoPuerta' debe ser un Area3D hijo de la puerta.")

func actualizar_estado_boton(id_boton: int, activado: bool) -> void:
	estado_botones[id_boton] = activado
	
	if contar_botones_activos() >= botones_necesarios:
		if timer_reinicio:
			timer_reinicio = null
		if not esta_abierta and not cerrando:
			abrir_puerta()
	else:
		if contar_botones_activos() > 0 and not esta_abierta:
			iniciar_timer_tolerancia()

func iniciar_timer_tolerancia() -> void:
	timer_reinicio = get_tree().create_timer(tiempo_limite_botones)
	await timer_reinicio.timeout
	if contar_botones_activos() < botones_necesarios and not esta_abierta:
		reiniciar_botones()

func reiniciar_botones() -> void:
	estado_botones[1] = false
	estado_botones[2] = false
	var botones = get_tree().get_nodes_in_group("BotonesPuerta")
	for b in botones:
		if "esta_activado" in b:
			b.esta_activado = false

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
		
	# Cierre automático de seguridad si nadie cruza tras tiempo_espera_maximo
	await get_tree().create_timer(tiempo_espera_maximo).timeout
	if esta_abierta and not cerrando and not cinematica_reproducida:
		cerrar_puerta()

# --- DETECCIÓN AL CRUZAR LA COLISIÓN ---
func _on_atraveso_puerta_body_entered(body: Node3D) -> void:
	# Filtramos para asegurarnos de que sea un personaje jugador
	if not body.is_in_group("Jugador") and not body.name.is_valid_int():
		return
		
	if esta_abierta and not cerrando and not cinematica_reproducida:
		cinematica_reproducida = true
		
		# 1. Cerramos la puerta inmediatamente
		cerrar_puerta()
		
		# 2. Reproducimos la cinemática
		reproducir_cinematica()

func cerrar_puerta() -> void:
	if not esta_abierta or cerrando:
		return
		
	cerrando = true
	esta_abierta = false
	reiniciar_botones()
	
	if animation_player:
		animation_player.play_backwards("Armature|Open")
		await animation_player.animation_finished
		
	cerrando = false

func reproducir_cinematica() -> void:
	if video_player:
		video_player.visible = true
		video_player.play()

		# Opcional: esperar a que el video termine para ocultarlo o cambiar de escena
		await video_player.finished
		video_player.visible = false
		print("Video finalizado.")
