extends Node3D
class_name Door

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var atraveso_puerta: Area3D = $AtravesoPuerta
@onready var video_player: VideoStreamPlayer = $"../../CanvasLayerPapas/VideoVictor"
@onready var punto_aparicion: Marker3D = $"../../PuntoAparicionDespCinematica"

# 1. Añadimos la referencia al CollisionShape3D que bloquea el paso (ajusta la ruta si tu nodo se llama distinto)
@onready var collision_shape: CollisionShape3D = $Sketchfab_model/ad94433c0d274c9ca7c09eec2d6cc43a_fbx/Object_2/RootNode/Armature/Object_5/Skeleton3D/Object_13/StaticBody3D/CollisionShape3D

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
	print("Puerta: ", name, " | anim: ", animation_player, " | area: ", atraveso_puerta, " | video: ", video_player)
	if animation_player:
		animation_player.stop()
		
	if atraveso_puerta:
		if not atraveso_puerta.body_entered.is_connected(_on_atraveso_puerta_body_entered):
			atraveso_puerta.body_entered.connect(_on_atraveso_puerta_body_entered)
	else:
		print("ERROR: El nodo 'AtravesoPuerta' debe ser un Area3D hijo de la puerta.")
		
func iniciar_timer_tolerancia() -> void:
	timer_reinicio = get_tree().create_timer(tiempo_limite_botones)
	await timer_reinicio.timeout
	if contar_botones_activos() < botones_necesarios and not esta_abierta:
		reiniciar_botones.rpc() # sincroniza el reinicio tambien
		
@rpc("call_local", "any_peer", "reliable")
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
	
# rpc : call_local (ejecuta en quien llama tambien), any_peer(cualquiera puede llamar)
# reliable (no se pierden paquetes)
@rpc("call_local", "any_peer", "reliable")
func abrir_puerta() -> void:
	esta_abierta = true
	
	if collision_shape:
		collision_shape.disabled = true
	
	if animation_player:
		animation_player.play("Armature|Open")
	
	if multiplayer.is_server():
		await get_tree().create_timer(tiempo_espera_maximo).timeout
		if esta_abierta and not cerrando and not cinematica_reproducida:
			cerrar_puerta.rpc()
			
func _on_atraveso_puerta_body_entered(body: Node3D) -> void:
	if not body.is_in_group("jugadores") and not body.name.is_valid_int():
		return
	# Solo el host/servidor deberia decir si un jugador cruzo para evitar colision doble por red
	if not multiplayer.is_server():
		return
	
	if esta_abierta and not cerrando and not cinematica_reproducida:
		cinematica_reproducida = true
		cerrar_puerta.rpc()
		reproducir_cinematica.rpc()

@rpc("call_local", "any_peer", "reliable")
func cerrar_puerta() -> void:
	if not esta_abierta or cerrando:
		return
	
	cerrando = true
	esta_abierta = false
	
	if animation_player:
		animation_player.play_backwards("Armature|Open")
		await animation_player.animation_finished
	
	if collision_shape:
		collision_shape.disabled = false
	
	cerrando = false

@rpc("call_local", "any_peer", "reliable")
func reproducir_cinematica() -> void:
	# 1. BLOQUEAMOS CONTROLES DE TODOS LOS JUGADORES
	get_tree().call_group("Jugador", "bloquear_controles", true)

	# Teletransportamos a todos los jugadores cuando empieza el video
	if punto_aparicion:
		var jugadores = get_tree().get_nodes_in_group("Jugador")
		for i in range(jugadores.size()):
			jugadores[i].global_position = punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)
		
		if video_player:
			video_player.visible = true
			video_player.play()
		
			await video_player.finished
			video_player.visible = false
			GameManager.papas_atacan = true

	# 2. DESBLOQUEAMOS CONTROLES AL TERMINAR LA CINEMÁTICA
	get_tree().call_group("Jugador", "bloquear_controles", false)
		
func actualizar_estado_boton(id_boton: int, activado: bool) -> void:
	estado_botones[id_boton] = activado
	
	if contar_botones_activos() >= botones_necesarios:
		if timer_reinicio:
			timer_reinicio = null
		if not esta_abierta and not cerrando:
			abrir_puerta.rpc()
	else:
		if contar_botones_activos() > 0 and not esta_abierta:
			iniciar_timer_tolerancia()
