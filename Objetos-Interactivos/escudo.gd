extends ItemBase
class_name escudo
@export var segundos_escudo: int = 7 #Por cuanto pausa la estamina al 100

func ser_recogido() -> void:
	destruir_item_rpc.rpc()
	
func usar_item(jugador) -> bool:
	var pudo_usarse_escudo = await jugador.recibir_escudo(segundos_escudo)
	return  pudo_usarse_escudo
