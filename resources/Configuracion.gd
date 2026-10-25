class_name DataClassConfiguracion
extends Resource
const NOMBRES_CALIDAD := ["Baja", "Media", "Alta"]
# CONTROLES
@export var controles: Dictionary = {
	"Adelante": 87,
	"Atras": 83,
	"Izquierda": 65,
	"Derecha": 68,
	"Salto": 32,
	"disparar": 90,
	"Abordar": MOUSE_BUTTON_RIGHT,
	"bailar": 81,
	"hacer_ragdoll": 78,
	"interactuar": 69
}

# VIDEO
@export var resolucion: Vector2i = Vector2i(1280, 720)
@export var pantalla_completa: bool = false

# AUDIO
@export var volumen: float = 1.0

# GRAFICOS
@export var vsync: bool = true
@export var msaa: int = 0
@export var calidad_graficos: int = 2
