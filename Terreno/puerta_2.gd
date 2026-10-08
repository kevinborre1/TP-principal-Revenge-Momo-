extends AnimatableBody3D

@export var botones_necesarios: int = 1
@export var desplazamiento_abrir: Vector3 = Vector3(0, 4, 0)
@export var duracion_animacion: float = 1.0

var estado_botones: Dictionary = {}
var posicion_inicial: Vector3
var tween_animacion: Tween

func _ready() -> void:
	posicion_inicial = global_position


func actualizar_estado_boton(id_boton: int, presionado: bool) -> void:
	estado_botones[id_boton] = presionado

	if contar_botones_presionados() >= botones_necesarios:
		abrir_puerta()
	else:
		cerrar_puerta()


func contar_botones_presionados() -> int:
	var activos = 0

	for presionado in estado_botones.values():
		if presionado:
			activos += 1

	return activos


func abrir_puerta() -> void:
	if tween_animacion and tween_animacion.is_running():
		tween_animacion.kill()

	tween_animacion = create_tween()
	tween_animacion.set_trans(Tween.TRANS_SINE)
	tween_animacion.set_ease(Tween.EASE_OUT)

	tween_animacion.tween_property(
		self,
		"global_position",
		posicion_inicial + desplazamiento_abrir,
		duracion_animacion
	)


func cerrar_puerta() -> void:
	if tween_animacion and tween_animacion.is_running():
		tween_animacion.kill()

	tween_animacion = create_tween()
	tween_animacion.set_trans(Tween.TRANS_SINE)
	tween_animacion.set_ease(Tween.EASE_IN)

	tween_animacion.tween_property(
		self,
		"global_position",
		posicion_inicial,
		duracion_animacion
	)
