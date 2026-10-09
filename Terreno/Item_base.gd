extends Area3D
class_name ItemBase

# Variables comunes para todos los ítems
@export var nombre_item: String
@export var icono: Texture2D
@export var ruta_escena: String

# Comportamiento común al ser recogido
func ser_recogido() -> void:
	queue_free()

# Un método "virtual" vacío que los hijos podrán sobrescribir usando polimorfismo
func usar_item(jugador) -> void:
	pass
	
