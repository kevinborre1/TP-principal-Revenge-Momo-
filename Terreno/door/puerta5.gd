extends Node3D

@export var Pepitas_necesarias: int = 1
@export var area_cruzar: Area3D # Podés asignarlo desde el Inspector o dejarlo como hijo AreaCruzarPuerta

# Música al cruzar la puerta
@export_enum("ninguna", "papas", "jefe_final", "escape_momo") var musica_al_cruzar: String = "ninguna"
@export var musica_personalizada: AudioStream

var esta_abierta: bool = false
var musica_reproducida: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Sonidos
const SFX_PUERTA_MADERA = preload("res://sonidos/puerta_madera.wav")

func _ready() -> void:
	if animation_player:
		animation_player.stop()

	# Si ya se abrió antes (al cargar partida o volver a entrar), dejamos la puerta abierta
	if Global.cinematicas_vistas.has(name):
		esta_abierta = true
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
