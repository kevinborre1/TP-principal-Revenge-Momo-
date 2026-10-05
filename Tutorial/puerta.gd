extends Node3D

var boton_1_activo: bool = false
var boton_2_activo: bool = false
var esta_abierta: bool = false

# Guarda la posición inicial en Y para saber a dónde volver o cuánto subir
@onready var posicion_inicial_y: float = position.y

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
	var tween = create_tween()
	# Sube la puerta 3 metros en 1 segundo de forma fluida
	tween.tween_property(self, "position:y", posicion_inicial_y + 103.0, 1.0)

func cerrar_puerta():
	esta_abierta = false
	var tween = create_tween()
	# Vuelve a su posición inicial
	tween.tween_property(self, "position:y", posicion_inicial_y, 1.0)
