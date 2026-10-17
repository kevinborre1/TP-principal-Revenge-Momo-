extends ItemBase 
class_name BotellaCerveza

@export var cantidad_curacion: int = 30 # Cuánta vida cura

func ser_recogido() -> void:
	destruir_item_rpc.rpc()
	
func usar_item(jugador) -> bool:
	var pudo_usarse_curacion = jugador.recibir_cura(cantidad_curacion)
	return  pudo_usarse_curacion
		
	
	
