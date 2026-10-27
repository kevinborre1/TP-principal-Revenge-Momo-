extends ItemBase
class_name reloj_arena

func _ready() -> void:
	super._ready()
	# Verificamos si NO estamos en el modo contrarreloj
	if Global.modo_de_juego != "contrarreloj":
		# Solo el servidor debe destruirlo si es un juego multijugador, 
		# o lo destruimos directamente si el item se instanció localmente antes de sincronizar.
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			queue_free()
		else:
			queue_free() # En la mayoría de los casos de inicialización de mapa, esto es suficiente

func ser_recogido() -> void:
	destruir_item_rpc.rpc()

func usar_item(jugador) -> bool:
	if GameManager.contrarreloj != null:
		
		GameManager.contrarreloj.tiempo_restante += 120.0
		print("Se anadieron 2 minutos al tiempo.")
		
		if Global.modo_multijugador == "linea" and multiplayer.is_server():
			GameManager.contrarreloj._sincronizar_timer.rpc(
				GameManager.contrarreloj.tiempo_restante, 
				GameManager.contrarreloj.timer_activo, 
				Global.modo_de_juego
				)
		return true
	else:
		return false
