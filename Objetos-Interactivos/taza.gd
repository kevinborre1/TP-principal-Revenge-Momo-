extends ItemBase
class_name taza

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
		GameManager.contrarreloj.pausar_timer()
		GameManager.get_tree().create_timer(30.0).timeout.connect(GameManager.contrarreloj.reanudar_timer)
		print("Tiempo pausado con éxito.")
		return true
	else:
		return false
