extends Node3D

var boton_1_activo: bool = false
var boton_2_activo: bool = false
var esta_abierta: bool = false

# Guarda la posición inicial en Y para saber a dónde volver o cuánto subir
@onready var posicion_inicial_y: float = position.y

#sonidos
const SFX_APERTURA = preload("res://sonidos/puerta_metal_a.wav")
const SFX_CIERRE = preload("res://sonidos/puerta_metal_c.wav")

func actualizar_estado_boton(id: int, activo: bool):
	if id == 1:
		boton_1_activo = activo
	elif id == 2:
		boton_2_activo = activo
		
	verificar_apertura()

func verificar_apertura():
	# Si los dos están presionados y la puerta está cerrada, se abre
	if boton_1_activo or boton_2_activo and not esta_abierta:
		abrir_puerta()
	# Si alguno se baja y la puerta estaba abierta, se cierra (opcional)
	elif (not boton_1_activo and not boton_2_activo) and esta_abierta:
		cerrar_puerta()

func abrir_puerta():
	esta_abierta = true
	reproducir_sfx_3d(SFX_APERTURA)
	var tween = create_tween()
	# Sube la puerta 3 metros en 1 segundo de forma fluida
	tween.tween_property(self, "position:y", posicion_inicial_y + 103.0, 1.0)

func cerrar_puerta():
	esta_abierta = false
	reproducir_sfx_3d(SFX_CIERRE)
	var tween = create_tween()
	# Vuelve a su posición inicial
	tween.tween_property(self, "position:y", posicion_inicial_y, 1.0)

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
