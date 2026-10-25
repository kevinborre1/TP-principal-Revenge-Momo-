class_name OndaExpansiva
extends Node3D

var velocidad: float = 3.0
var dano: int = 15
var radio_max: float = 25.0
var ancho: float = 1.0            # grosor del anillo
var altura_peligro: float = 0.1   # si el jugador está más alto que esto (saltando), la esquiva

var _radio := 0.0
var _malla: TorusMesh
var _ya_golpeados: Array = []


func _ready() -> void:
	_malla = TorusMesh.new()
	_malla.inner_radius = 0.01
	_malla.outer_radius = 0.02
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.1, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var visual := MeshInstance3D.new()
	visual.mesh = _malla
	visual.material_override = material
	visual.scale = Vector3(1, 0.3, 1)  # tubo aplastado: parece una onda sobre el piso
	visual.position.y = 0
	add_child(visual)


func _physics_process(delta: float) -> void:
	_radio += velocidad * delta
	if _radio >= radio_max:
		queue_free()
		return
	
	_malla.outer_radius = _radio
	_malla.inner_radius = maxf(_radio - ancho, 0.01)
	
	for j in get_tree().get_nodes_in_group("Jugador"):
		if j in _ya_golpeados:
			continue
		var d := Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length()
		var dentro_del_anillo: bool = d <= _radio and d >= _radio - ancho
		var a_ras_de_piso: bool = j.global_position.y - global_position.y < altura_peligro
		
		if dentro_del_anillo and a_ras_de_piso:
			_ya_golpeados.append(j)
			# Cada PC solo le saca vida a su propio jugador
			if Global.modo_multijugador != "linea" or j.is_multiplayer_authority():
				j._recibir_danio_red(dano)
