extends Area3D

const TIEMPO_VIDA: float = 20.0
const VELOCIDAD_BALA: float = 1.0
const DANIO_BALA: int = 10

var tiempo: float = 0.0
var golpeo_algo: bool = false
var direccion: Vector3 = Vector3.FORWARD

func _ready() -> void:
	# En Godot 4 las señales se conectan así:
	body_entered.connect(_al_colisionar)

func _physics_process(delta: float) -> void:
	# Mueve la bala hacia adelante usando su base global Z
	global_position += direccion * VELOCIDAD_BALA * delta
	
	# Control de tiempo de vida
	tiempo += delta
	if tiempo >= TIEMPO_VIDA:
		queue_free()
		print("Desapareci")

func _al_colisionar(body: Node3D) -> void:
	if not golpeo_algo:
		if body.has_method("golpeo_bala"):
			body.golpeo_bala(DANIO_BALA, global_transform)
		golpeo_algo = true
		queue_free()
		
func _direccion_salida(dir: Vector3) -> void:
	direccion =dir
