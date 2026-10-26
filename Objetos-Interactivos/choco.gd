extends ItemBase
class_name choco
@export var segundos_estamina: int = 7 #Por cuanto pausa la estamina al 100

func ser_recogido() -> void:
	destruir_item_rpc.rpc()
	
func usar_item(jugador) -> bool:
	var pudo_usarse_choco = await jugador.recibir_estamina(segundos_estamina)
	return  pudo_usarse_choco
