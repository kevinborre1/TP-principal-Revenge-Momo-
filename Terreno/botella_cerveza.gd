extends ItemBase 
class_name BotellaCerveza

@export var cantidad_curacion: int = 30 # Cuánta vida cura

func usar_item(jugador) -> void:
	if jugador.recibir_cura(cantidad_curacion):
		queue_free()
	
	
