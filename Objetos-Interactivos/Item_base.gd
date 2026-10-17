extends Area3D
class_name ItemBase

@export var nombre_item: String = "Pocion"
@export var icono: Texture2D
@export var ruta_escena: String = ""
@export var es_equipable: bool = false # ¡Nueva variable!

# Esta función es llamada por el servidor tras agregarse al inventario
func ser_recogido() -> void:
	destruir_item_rpc.rpc()
	
	# Un método "virtual" vacío que los hijos podrán sobrescribir usando polimorfismo
func usar_item(jugador) -> bool:
	return false

@rpc("call_local", "any_peer", "reliable")
func destruir_item_rpc() -> void:
	# Ocultamos y desactivamos colisiones de inmediato para todos
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Borramos el objeto del juego de forma limpia
	queue_free()
