extends TextureRect

@export var player: Player
# Este Array aparecerá en el Inspector para que pongas tus 11 imágenes
@export var texturas: Array[Texture2D] = []

func _ready() -> void:
	if player:
		player.cambioStamina.connect(actualizar_ui)
		actualizar_ui()

func actualizar_ui() -> void:
	# Si no hay jugador o se nos olvidó poner las imágenes en el Inspector, no hacemos nada
	if not player or texturas.is_empty(): 
		return
		
	# 1. Calculamos el porcentaje de estamina (ej: 50 / 100 = 0.5)
	var porcentaje = player.StaminaActual / player.StaminaMax
	
	# 2. Multiplicamos el porcentaje por el índice máximo del Array (11 imágenes - 1 = 10)
	# Usamos round() para que cambie de imagen al acercarse al valor (ej: de 15% ya muestre el icono de 20%)
	var indice = int(round(porcentaje * (texturas.size() - 1)))
	
	# 3. Aseguramos por seguridad que el índice nunca sea menor a 0 o mayor a 10
	indice = clamp(indice, 0, texturas.size() - 1)
	
	# 4. Asignamos la textura correspondiente
	texture = texturas[indice]
