extends Node3D

@export var Pepitas_necesarias: int = 1
@export var area_cruzar: Area3D # Podés asignarlo desde el Inspector o dejarlo como hijo AreaCruzarPuerta
@export var video_player: VideoStreamPlayer
@export var video_cinematica: VideoStream
@export var punto_aparicion: Marker3D
@export var esperar_animacion_puerta: bool = true

# Música al cruzar la puerta
@export_enum("ninguna", "papas", "jefe_final", "escape_momo") var musica_al_cruzar: String = "ninguna"
@export var musica_personalizada: AudioStream

signal cinematica_terminada

var esta_abierta: bool = false
var cinematica_reproducida: bool = false
var musica_reproducida: bool = false
var cinematica_activa: bool = false
var boton_saltear: Button = null

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Sonidos
const SFX_PUERTA_MADERA = preload("res://sonidos/puerta_madera.wav")

func _ready() -> void:
	if animation_player:
		animation_player.stop()

	# Si ya se vio la cinemática antes (al cargar partida o volver a entrar), dejamos la puerta abierta sin video
	if Global.cinematica_agua_vista:
		esta_abierta = true
		cinematica_reproducida = true
		var oclusor := get_node_or_null("OccluderPuerta")
		if oclusor:
			oclusor.visible = false
		if animation_player and animation_player.has_animation("Animation"):
			animation_player.play("Animation")
			animation_player.seek(animation_player.get_animation("Animation").length, true)
			animation_player.pause()

	if area_cruzar == null:
		area_cruzar = get_node_or_null("AreaCruzarPuerta")

	if area_cruzar:
		if not area_cruzar.body_entered.is_connected(_on_area_cruzar_body_entered):
			area_cruzar.body_entered.connect(_on_area_cruzar_body_entered)

	_crear_boton_saltear()

	if GameManager.has_signal("count_changed"):
		GameManager.count_changed.connect(_on_count_changed)

func _on_count_changed(count: int) -> void:
	ChequeoPepita(count)

func ChequeoPepita(pepitas_del_jugador: int) -> void:
	if pepitas_del_jugador >= Pepitas_necesarias and not esta_abierta:
		abrir_puerta.rpc()

@rpc("call_local", "any_peer", "reliable")
func abrir_puerta() -> void:
	if esta_abierta:
		return
	esta_abierta = true

	var oclusor := get_node_or_null("OccluderPuerta")
	if oclusor:
		oclusor.visible = false

	if animation_player:
		animation_player.play("Animation")
		print("¡Pepita conseguida! Abriendo puerta automáticamente...")

	reproducir_sfx_3d(SFX_PUERTA_MADERA)

	if not cinematica_reproducida and not Global.cinematica_agua_vista:
		cinematica_reproducida = true
		Global.cinematica_agua_vista = true
		reproducir_cinematica()

func _on_area_cruzar_body_entered(body: Node3D) -> void:
	if musica_reproducida:
		return

	var es_jugador := body.is_in_group("jugadores") or body.is_in_group("Jugador") or body.name.is_valid_int()
	if not es_jugador:
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	disparar_musica_cruzar.rpc()

@rpc("call_local", "any_peer", "reliable")
func disparar_musica_cruzar() -> void:
	if musica_reproducida:
		return
	musica_reproducida = true
	_reproducir_musica_evento()

func _reproducir_musica_evento() -> void:
	if musica_personalizada != null:
		if MusicManager.has_method("play_stream"):
			MusicManager.play_stream(musica_personalizada)
		elif "stream" in MusicManager:
			MusicManager.stream = musica_personalizada
			MusicManager.play()
		return

	match musica_al_cruzar:
		"ninguna":
			pass
		"papas":
			MusicManager.play_papas()
		"jefe_final":
			MusicManager.play_jefe_final()
		"escape_momo":
			MusicManager.play_escape_momo()

func _conectar_senal_video_exclusiva() -> void:
	if not video_player:
		return
	for conn in video_player.finished.get_connections():
		video_player.finished.disconnect(conn.callable)
	video_player.finished.connect(_on_video_finished, CONNECT_ONE_SHOT)

func reproducir_cinematica() -> void:
	get_tree().call_group("Jugador", "bloquear_controles", true)

	if punto_aparicion:
		var jugadores := get_tree().get_nodes_in_group("Jugador")
		for i in range(jugadores.size()):
			jugadores[i].global_position = punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)
			jugadores[i].punto_respawn = punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)

	if video_player:
		if video_cinematica:
			video_player.stream = video_cinematica
		_conectar_senal_video_exclusiva()

		cinematica_activa = true
		video_player.visible = true
		video_player.play()

		if boton_saltear:
			boton_saltear.show()
			_reposicionar_boton()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		await cinematica_terminada

		cinematica_activa = false
		video_player.visible = false
		if boton_saltear:
			boton_saltear.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	get_tree().call_group("Jugador", "bloquear_controles", false)

func _crear_boton_saltear() -> void:
	if boton_saltear or not video_player:
		return
	boton_saltear = Button.new()
	boton_saltear.text = "Saltar"
	boton_saltear.custom_minimum_size = Vector2(110, 40)
	boton_saltear.focus_mode = Control.FOCUS_NONE
	boton_saltear.visible = false
	boton_saltear.pressed.connect(_on_saltear_pressed)

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

	video_player.get_parent().add_child(boton_saltear)
	boton_saltear.z_index = 10
	get_viewport().size_changed.connect(_reposicionar_boton)
	_reposicionar_boton()

func _on_video_finished() -> void:
	if cinematica_activa:
		cinematica_terminada.emit()

func _on_saltear_pressed() -> void:
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

# Sonidos en 3D que el otro escuchará
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
