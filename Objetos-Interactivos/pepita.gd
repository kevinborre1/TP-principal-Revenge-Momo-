extends Area3D

func ser_recogido() -> void:
	# 1. Incrementa el contador compartido en el GameManager y actualiza el HUD
	GameManager.register_event()
	
	# 2. Desaparece del mapa
	queue_free()
