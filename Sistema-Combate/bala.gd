extends Area3D

const TIEMPO_VIDA: float = 4.0
const VELOCIDAD_BALA: float = 70.0
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
		# Si lo que tocó tiene la función _daniar (Papa, Barril, etc.)
		if body.has_method("_daniar"):
			body._daniar(DANIO_BALA)
		
		golpeo_algo = true
		queue_free() # Destruye la bala tras impactar
func _direccion_salida(dir: Vector3) -> void:
	direccion =dir
