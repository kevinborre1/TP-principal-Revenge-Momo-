extends Node3D
class_name Door

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var atraveso_puerta: Area3D = $AtravesoPuerta
@export var video_player: VideoStreamPlayer
@export var punto_aparicion: Marker3D

# 1. Añadimos la referencia al CollisionShape3D que bloquea el paso (ajusta la ruta si tu nodo se llama distinto)
@onready var collision_shape: CollisionShape3D = $Sketchfab_model/ad94433c0d274c9ca7c09eec2d6cc43a_fbx/Object_2/RootNode/Armature/Object_5/Skeleton3D/Object_13/StaticBody3D/CollisionShape3D

@export var botones_necesarios: int = 2
@export var tiempo_espera_maximo: float = 10.0 # Tiempo máxima abierta si nadie pasa
@export var tiempo_limite_botones: float = 5.0 # Margen para apretar el segundo botón en solitario

signal cinematica_terminada

var cinematica_activa: bool = false
var boton_saltear: Button = null

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
		
	_crear_boton_saltear()
	if video_player and not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)
		
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
		# (OOP - Encapsulamiento): Verificamos si el botón tiene la capacidad de desactivarse 
		# y se lo pedimos amablemente, sin tocar sus variables internas.
		if b.has_method("desactivar_externamente"):
			b.desactivar_externamente()

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
	
	reiniciar_botones()

@rpc("call_local", "any_peer", "reliable")
func reproducir_cinematica() -> void:
	# 1. Bloqueamos controles de todos los jugadores
	get_tree().call_group("Jugador", "bloquear_controles", true)

	if punto_aparicion:
		var jugadores = get_tree().get_nodes_in_group("Jugador")
		for i in range(jugadores.size()):
			jugadores[i].global_position = punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)
			jugadores[i].punto_respawn = punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)

		if video_player:
			cinematica_activa = true
			video_player.visible = true
			video_player.play()
			if boton_saltear:
				boton_saltear.show()
				_reposicionar_boton()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # para poder clickear el botón

			await cinematica_terminada   # termina solo o por el botón

			cinematica_activa = false
			video_player.visible = false
			if boton_saltear:
				boton_saltear.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			GameManager.papas_atacan = true
 
	# 2. Desbloqueamos controles al terminar
	get_tree().call_group("Jugador", "bloquear_controles", false)
		
func actualizar_estado_boton(id_boton: int, activado: bool) -> void:
	# 1. TODOS los jugadores actualizan su diccionario local
	estado_botones[id_boton] = activado
	
	# 2. PRINCIPIO DE AUTORIDAD: Cortamos la ejecución aquí para los clientes.
	# Solo el Servidor (Host) tiene la responsabilidad de pensar qué hacer a continuación.
	if not multiplayer.is_server():
		return
	
	# De aquí para abajo, SOLO el servidor lo ejecuta.
	if contar_botones_activos() >= botones_necesarios:
		if timer_reinicio:
			timer_reinicio = null
		if not esta_abierta and not cerrando:
			abrir_puerta.rpc() # El servidor le avisa a todos que se abre
	else:
		if contar_botones_activos() > 0 and not esta_abierta:
			iniciar_timer_tolerancia() # Solo el servidor cuenta el tiempo
			
func _crear_boton_saltear() -> void:
	if boton_saltear or not video_player:
		return
	boton_saltear = Button.new()
	boton_saltear.text = "Saltar"
	boton_saltear.custom_minimum_size = Vector2(110, 40)
	boton_saltear.focus_mode = Control.FOCUS_NONE
	boton_saltear.visible = false
	boton_saltear.pressed.connect(_on_saltear_pressed)

	# Estilo visible sobre cualquier fondo
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.65)
	normal.border_color = Color.WHITE
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.25, 0.25, 0.85)

	boton_saltear.add_theme_stylebox_override("normal", normal)
	boton_saltear.add_theme_stylebox_override("hover", hover)
	boton_saltear.add_theme_stylebox_override("pressed", hover)
	boton_saltear.add_theme_color_override("font_color", Color.WHITE)
	boton_saltear.add_theme_color_override("font_hover_color", Color.WHITE)
	boton_saltear.add_theme_font_size_override("font_size", 18)

	video_player.get_parent().add_child(boton_saltear)   # hijo del CanvasLayer, no del video
	boton_saltear.z_index = 10
	get_viewport().size_changed.connect(_reposicionar_boton)
	_reposicionar_boton()
	
func _on_video_finished() -> void:
	if cinematica_activa:
		cinematica_terminada.emit()

func _on_saltear_pressed() -> void:
	saltear_cinematica.rpc()   # lo saltean todos a la vez, nadie queda trabado

@rpc("call_local", "any_peer", "reliable")
func saltear_cinematica() -> void:
	if not cinematica_activa:
		return
	if video_player:
		video_player.stop()
	cinematica_terminada.emit()

func _reposicionar_boton() -> void:
	if not boton_saltear:
		return
	var tam_ventana := get_viewport().get_visible_rect().size
	boton_saltear.size = boton_saltear.get_combined_minimum_size()
	boton_saltear.position = tam_ventana - boton_saltear.size - Vector2(40, 40)
