extends StaticBody3D

@rpc("any_peer", "call_local", "reliable")
func _daniar(danio: int) -> void:
	print("¡El barril recibió un disparo!")
	# Borra al nodo padre (Sketchfab_Scene) para que desaparezca todo el barril visualmente
	if get_parent():
		get_parent().queue_free()
	else:
		SaveAndLoad.sumar_estadistica("barrilesRotos")
		queue_free()
