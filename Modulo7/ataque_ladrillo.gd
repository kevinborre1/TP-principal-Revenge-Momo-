extends Node3D

var radio: float = 4.0
var dano: int = 30
var retraso: float = 2.0

@onready var marca_piso: MeshInstance3D = $MeshInstance3D  # El cilindro/marca
@onready var ladrillo_mesh: Node3D = $Sketchfab_Scene      # El modelo 3D del ladrillo

func _ready() -> void:
	# Ajustar el radio de la marca en el piso
	if marca_piso:
		marca_piso.scale = Vector3(radio, 0.02, radio)
	
	# Posición inicial del ladrillo en el aire
	if ladrillo_mesh:
		ladrillo_mesh.position.y = 12.0
		
		# Animar la caída del ladrillo
		var tween := create_tween()
		tween.tween_property(ladrillo_mesh, "position:y", 0.0, retraso).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_impactar)
	else:
		# Si por alguna razón no está el mesh, impactar al terminar el tiempo
		get_tree().create_timer(retraso).timeout.connect(_impactar)

func _impactar() -> void:
	# Aplicar daño a los jugadores en la zona
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		var dist := global_position.distance_to(jugador.global_position)
		if dist <= radio:
			if Global.modo_multijugador != "linea" or jugador.is_multiplayer_authority():
				jugador._recibir_danio_red(dano)
	
	queue_free()
