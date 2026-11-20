extends Node3D

@export var altura_apertura: float = 20.0
@export var duracion_movimiento: float = 1.0

var esta_abierta: bool = false
var _botones_activos: Dictionary = {}
var _tween_activo: Tween

@onready var _posicion_inicial_y: float = position.y

#sonidos
const SFX_APERTURA = preload("res://sonidos/puerta_metal_a.wav")
const SFX_CIERRE = preload("res://sonidos/puerta_metal_c.wav")

func actualizar_estado_boton(id: int, activo: bool) -> void:
	_botones_activos[id] = activo
	_verificar_apertura()

func _verificar_apertura() -> void:
	var algun_boton_activo := _botones_activos.values().has(true)
	
	if algun_boton_activo and not esta_abierta:
		abrir_puerta()
	elif not algun_boton_activo and esta_abierta:
		cerrar_puerta()

func abrir_puerta() -> void:
	esta_abierta = true
	reproducir_sfx_3d(SFX_APERTURA)
	_mover_puerta(_posicion_inicial_y + altura_apertura)

func cerrar_puerta() -> void:
	esta_abierta = false
	reproducir_sfx_3d(SFX_CIERRE)
	_mover_puerta(_posicion_inicial_y)

func _mover_puerta(destino_y: float) -> void:
	# Si había un movimiento en curso, lo cancela antes de iniciar el nuevo
	if _tween_activo and _tween_activo.is_valid():
		_tween_activo.kill()
	
	_tween_activo = create_tween()
	_tween_activo.tween_property(self, "position:y", destino_y, duracion_movimiento)

# Sonidos en 3D que el otro escuchará
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0 # Distance in meters at which the other player can hear it
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
	add_child(player_3d)
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
