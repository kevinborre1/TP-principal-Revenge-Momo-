class_name AtaqueArea
extends Node3D

var radio: float = 4.0
var dano: int = 30
var retraso: float = 2.0

var _zona: Area3D
var _material: StandardMaterial3D

func _ready() -> void:
	# Marca roja en el piso
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = 0.05
	
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1, 0, 0, 0.25)
	
	var marca := MeshInstance3D.new()
	marca.mesh = cilindro
	marca.material_override = _material
	marca.position.y = 0.05  # apenas arriba del piso, para que no parpadee
	add_child(marca)
	
	# Zona de daño (se consulta recién cuando el ataque cae)
	var forma := CylinderShape3D.new()
	forma.radius = radio
	forma.height = 4.0
	var colision := CollisionShape3D.new()
	colision.shape = forma
	_zona = Area3D.new()
	_zona.add_child(colision)
	add_child(_zona)
	
	# La marca se va poniendo más intensa hasta que cae
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.7, retraso)
	tween.tween_callback(_caer)


func _caer() -> void:
	for cuerpo in _zona.get_overlapping_bodies():
		if not cuerpo.is_in_group("Jugador"):
			continue
		# En línea, cada PC solo le resta vida a su propio jugador
		if Global.modo_multijugador == "linea" and not cuerpo.is_multiplayer_authority():
			continue
		cuerpo.saludActual = max(cuerpo.saludActual - dano, 0)
		cuerpo.cambioSalud.emit()
	
	# Destello y desaparece
	_material.albedo_color = Color(1.0, 0.325, 0.263, 0.765)
	await get_tree().create_timer(0.15).timeout
	queue_free()
