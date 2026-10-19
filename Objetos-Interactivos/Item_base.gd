extends Area3D
class_name ItemBase

@export var nombre_item: String = "Pocion"
@export var icono: Texture2D
@export var ruta_escena: String = ""
@export var es_equipable: bool = false # ¡Nueva variable!

#Como maneja la camara el personaje si tiene este item 
@export var activa_mira_combate: bool = false
@export var modifica_camara: bool = false
@export var distancia_camara: float = 2.0 # Se usa solo si modifica_camara es true
@export var offset_camara: Vector3 = Vector3(0.0, 1.5, 0.0) # Se usa solo si modifica_camara es true

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
	
func desactivar_para_mano() -> void:
	# 1. Apagamos las físicas del nodo principal
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	
	# 2. Buscamos todas las colisiones hijas ocultas y las apagamos
	var colisiones = find_children("*", "CollisionShape3D")
	for c in colisiones:
		c.set_deferred("disabled", true)
