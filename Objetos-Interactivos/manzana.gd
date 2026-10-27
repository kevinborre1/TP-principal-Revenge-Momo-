extends ItemBase
class_name Manzana

# Porcentaje de vida máxima que quitará (por ejemplo, 20 = 20%)
@export var porcentaje_danio: float = 20.0

func ser_recogido() -> void:
	destruir_item_rpc.rpc()

func usar_item(jugador) -> bool:
	# Intentamos aplicar el daño porcentual al jugador
	var pudo_usarse_manzana = jugador.recibir_danio_porcentaje(porcentaje_danio)
	return pudo_usarse_manzana

func desactivar_para_mano() -> void:
	# Desactiva las colisiones del área para que no moleste en la mano
	monitoring = false
	monitorable = false
	
	# Reduce la escala de la manzana cuando se equipa en la mano
	scale = Vector3(0.4, 0.4, 0.4)
