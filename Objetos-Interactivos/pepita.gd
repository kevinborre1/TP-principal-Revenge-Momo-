extends Area3D

func ser_recogido() -> void:
	if Global.modo_multijugador == "linea":
		# En lugar de borrarse a sí misma, le pide al Host (ID 1) que la procese
		rpc_id(1, "_procesar_pepita_host")
	else:
		_procesar_pepita_host()

# Esta función la recibe cualquiera, pero el "if" asegura que solo el Host trabaje
@rpc("any_peer", "call_local", "reliable")
func _procesar_pepita_host() -> void:
	if multiplayer.is_server() or Global.modo_multijugador == "local":
		# 1. El Host suma el punto oficial
		GameManager.register_event()
		
		# 2. El Host le ordena a TODAS las computadoras que borren esta pepita visualmente
		if Global.modo_multijugador == "linea":
			rpc("_borrar_pepita_visual")
		else:
			_borrar_pepita_visual()

# Esta orden viaja por internet para todos
@rpc("call_local", "reliable")
func _borrar_pepita_visual() -> void:
	queue_free()
