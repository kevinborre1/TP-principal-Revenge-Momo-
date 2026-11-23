extends Node3D   # el tipo que tenga la raíz de tu reja

@export var tiempo_visible := 4.0
@export var tiempo_aparecer := 0.15
@export var tiempo_desaparecer := 0.6

var _mallas := []
var _tween: Tween

func _ready() -> void:
	_mallas = find_children("*", "GeometryInstance3D", true, false)
	_set_transparencia(1.0)
	_set_visible(false)

func revelar() -> void:
	if _tween:
		_tween.kill()
	_set_visible(true)
	_tween = create_tween()
	_tween.tween_method(_set_transparencia, 1.0, 0.0, tiempo_aparecer)
	_tween.tween_interval(tiempo_visible)
	_tween.tween_method(_set_transparencia, 0.0, 1.0, tiempo_desaparecer)
	_tween.tween_callback(_set_visible.bind(false))

func _set_transparencia(valor: float) -> void:
	for m in _mallas:
		m.transparency = valor

func _set_visible(v: bool) -> void:
	for m in _mallas:
		m.visible = v
