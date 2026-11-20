extends Node3D

@export var altura_apertura: float = 20.0
@export var duracion_movimiento: float = 1.0

var esta_abierta: bool = false
var _botones_activos: Dictionary = {}
var _tween_activo: Tween

@onready var _posicion_inicial_y: float = position.y

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
	_mover_puerta(_posicion_inicial_y + altura_apertura)

func cerrar_puerta() -> void:
	esta_abierta = false
	_mover_puerta(_posicion_inicial_y)

func _mover_puerta(destino_y: float) -> void:
	# Si había un movimiento en curso, lo cancela antes de iniciar el nuevo
	if _tween_activo and _tween_activo.is_valid():
		_tween_activo.kill()
	
	_tween_activo = create_tween()
	_tween_activo.tween_property(self, "position:y", destino_y, duracion_movimiento)
