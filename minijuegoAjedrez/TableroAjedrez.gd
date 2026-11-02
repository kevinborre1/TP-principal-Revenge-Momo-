class_name TableroAjedrez
extends RefCounted

var casillas: Array = [] 

func inicializar_tablero_clasico() -> void:
	casillas.clear()
	for i in range(8):
		var fila = []
		fila.resize(8)
		fila.fill(null)
		casillas.append(fila)

	# Peones
	for x in range(8):
		casillas[1][x] = PiezaAjedrez.new(PiezaAjedrez.Tipo.PEON, PiezaAjedrez.ColorPieza.NEGRO)
		casillas[6][x] = PiezaAjedrez.new(PiezaAjedrez.Tipo.PEON, PiezaAjedrez.ColorPieza.BLANCO)
		
	# Negras (Reina en 3, Rey en 4)
	casillas[0][0] = PiezaAjedrez.new(PiezaAjedrez.Tipo.TORRE, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][1] = PiezaAjedrez.new(PiezaAjedrez.Tipo.CABALLO, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][2] = PiezaAjedrez.new(PiezaAjedrez.Tipo.ALFIL, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][3] = PiezaAjedrez.new(PiezaAjedrez.Tipo.REINA, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][4] = PiezaAjedrez.new(PiezaAjedrez.Tipo.REY, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][5] = PiezaAjedrez.new(PiezaAjedrez.Tipo.ALFIL, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][6] = PiezaAjedrez.new(PiezaAjedrez.Tipo.CABALLO, PiezaAjedrez.ColorPieza.NEGRO)
	casillas[0][7] = PiezaAjedrez.new(PiezaAjedrez.Tipo.TORRE, PiezaAjedrez.ColorPieza.NEGRO)

	# Blancas (Reina en 3, Rey en 4)
	casillas[7][0] = PiezaAjedrez.new(PiezaAjedrez.Tipo.TORRE, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][1] = PiezaAjedrez.new(PiezaAjedrez.Tipo.CABALLO, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][2] = PiezaAjedrez.new(PiezaAjedrez.Tipo.ALFIL, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][3] = PiezaAjedrez.new(PiezaAjedrez.Tipo.REINA, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][4] = PiezaAjedrez.new(PiezaAjedrez.Tipo.REY, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][5] = PiezaAjedrez.new(PiezaAjedrez.Tipo.ALFIL, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][6] = PiezaAjedrez.new(PiezaAjedrez.Tipo.CABALLO, PiezaAjedrez.ColorPieza.BLANCO)
	casillas[7][7] = PiezaAjedrez.new(PiezaAjedrez.Tipo.TORRE, PiezaAjedrez.ColorPieza.BLANCO)

func obtener_pieza(x: int, y: int) -> PiezaAjedrez:
	return casillas[y][x]

func mover_pieza(desde: Vector2, hasta: Vector2) -> void:
	var pieza_origen = casillas[desde.y][desde.x]
	var pieza_destino = casillas[hasta.y][hasta.x]
	
	# Detectar Enroque
	if pieza_origen.tipo == PiezaAjedrez.Tipo.REY and pieza_destino != null and pieza_destino.color == pieza_origen.color and pieza_destino.tipo == PiezaAjedrez.Tipo.TORRE:
		if hasta.x == 7: # Enroque corto
			casillas[desde.y][6] = pieza_origen
			casillas[desde.y][5] = pieza_destino
			casillas[desde.y][desde.x] = null
			casillas[hasta.y][hasta.x] = null
		elif hasta.x == 0: # Enroque largo
			casillas[desde.y][2] = pieza_origen
			casillas[desde.y][3] = pieza_destino
			casillas[desde.y][desde.x] = null
			casillas[hasta.y][hasta.x] = null
			
		pieza_origen.ya_se_movio = true
		pieza_destino.ya_se_movio = true
		return
		
	# Movimiento normal
	casillas[hasta.y][hasta.x] = pieza_origen
	casillas[desde.y][desde.x] = null
	pieza_origen.ya_se_movio = true

# ¡NUEVO! Detecta si la pieza en 'hasta' es un peón que llegó al fondo
func es_coronacion(hasta: Vector2) -> bool:
	var p = casillas[hasta.y][hasta.x]
	if p != null and p.tipo == PiezaAjedrez.Tipo.PEON:
		if (p.color == PiezaAjedrez.ColorPieza.BLANCO and hasta.y == 0) or \
		   (p.color == PiezaAjedrez.ColorPieza.NEGRO and hasta.y == 7):
			return true
	return false

# ¡NUEVO! Cambia el tipo de pieza cuando el jugador elige en el menú
func coronar_peon(pos: Vector2, nuevo_tipo: PiezaAjedrez.Tipo) -> void:
	var p = casillas[pos.y][pos.x]
	if p != null:
		p.tipo = nuevo_tipo
