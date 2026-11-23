extends Node3D

@export var anim_abrir: StringName = &"ArmatureAction"
@export var velocidad_anim: float = 1.0
@export var empieza_abierta: bool = false

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var area_interaccion: Area3D = get_node_or_null("Area3D")
@onready var cartel_interaccion: Label3D = get_node_or_null("Label3D")



var esta_abierta: bool = false
var animando: bool = false
var jugador_cerca: bool = false

func _ready() -> void:
	esta_abierta = empieza_abierta

	if cartel_interaccion != null:
		cartel_interaccion.visible = false

	if animation_player != null and animation_player.has_animation(anim_abrir):
		animation_player.speed_scale = velocidad_anim
		animation_player.play(anim_abrir)
		if esta_abierta:
			var duracion := animation_player.get_animation(anim_abrir).length
			animation_player.seek(duracion, true)
			animation_player.pause()
		else:
			animation_player.seek(0.0, true)
			animation_player.stop()

	if area_interaccion != null:
		if not area_interaccion.body_entered.is_connected(_on_area_3d_body_entered):
			area_interaccion.body_entered.connect(_on_area_3d_body_entered)
		if not area_interaccion.body_exited.is_connected(_on_area_3d_body_exited):
			area_interaccion.body_exited.connect(_on_area_3d_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and not animando and event.is_action_pressed("interactuar"):
		if multiplayer.has_multiplayer_peer():
			alternar_puerta.rpc()
		else:
			alternar_puerta()

@rpc("call_local", "any_peer", "reliable")
func alternar_puerta() -> void:
	if animando:
		return

	animando = true


	if not esta_abierta:
		esta_abierta = true
		if animation_player != null and animation_player.has_animation(anim_abrir):
			animation_player.speed_scale = velocidad_anim
			animation_player.play(anim_abrir)
			await animation_player.animation_finished
	else:
		esta_abierta = false
		if animation_player != null and animation_player.has_animation(anim_abrir):
			animation_player.speed_scale = velocidad_anim
			animation_player.play_backwards(anim_abrir)
			await animation_player.animation_finished

	animando = false
	_actualizar_cartel()

func _es_jugador_local(body: Node3D) -> bool:
	var en_grupo := body.is_in_group("player") or body.is_in_group("jugadores") or body.is_in_group("Jugador")
	if not en_grupo:
		return false
	if body.has_method("is_multiplayer_authority"):
		return body.is_multiplayer_authority()
	return true

func _on_area_3d_body_entered(body: Node3D) -> void:
	if _es_jugador_local(body):
		jugador_cerca = true
		_actualizar_cartel()

func _on_area_3d_body_exited(body: Node3D) -> void:
	if _es_jugador_local(body):
		jugador_cerca = false
		if cartel_interaccion != null:
			cartel_interaccion.visible = false

func _actualizar_cartel() -> void:
	if cartel_interaccion != null:
		cartel_interaccion.visible = jugador_cerca and not animando

func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.bus = &"SFX"
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
