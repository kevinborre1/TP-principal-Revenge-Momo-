extends ItemBase 
class_name BotellaCerveza

@export var cantidad_curacion: int = 30 # Cuánta vida cura

func usar_item(jugador) -> void:
	# Lógica para curar al jugador cuando aprieta la tecla E
	if jugador.saludActual >= jugador.saludMax:
		print("Salud llena. No puedes usar la botella.")
		return
		
	jugador.saludActual += cantidad_curacion
	
	if jugador.saludActual > jugador.saludMax:
		jugador.saludActual = jugador.saludMax
		
	jugador.cambioSalud.emit()
	print("Te curaste. Tu salud ahora es: ", jugador.saludActual)
