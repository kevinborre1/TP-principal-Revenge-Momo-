class_name JuegoAjedrez
extends Node

var tablero: TableroAjedrez
var turno_actual: PiezaAjedrez.ColorPieza = PiezaAjedrez.ColorPieza.BLANCO

func iniciar_partida():
	tablero = TableroAjedrez.new()
	tablero.inicializar_tablero_clasico()

func obtener_movimientos_legales(pos_pieza: Vector2) -> Array[Vector2]:
	var pieza = tablero.obtener_pieza(pos_pieza.x, pos_pieza.y)
	var teoricos = pieza.obtener_movimientos_teoricos(pos_pieza, tablero)
	var legales: Array[Vector2] = []
	
	for mov in teoricos:
		if not deja_rey_en_jaque(pos_pieza, mov, pieza.color):
			legales.append(mov)
			
	# Enroque para Rey estándar (columna 4)
	if pieza.tipo == PiezaAjedrez.Tipo.REY and not pieza.ya_se_movio:
		if not deja_rey_en_jaque(pos_pieza, pos_pieza, pieza.color):
			var y = int(pos_pieza.y)
			# Enroque corto a la derecha (casillas 5 y 6 vacías)
			_verificar_enroque(pieza, pos_pieza, Vector2(7, y), [Vector2(5, y), Vector2(6, y)], legales)
			# Enroque largo a la izquierda (casillas 1, 2 y 3 vacías)
			_verificar_enroque(pieza, pos_pieza, Vector2(0, y), [Vector2(1, y), Vector2(2, y), Vector2(3, y)], legales)
			
	return legales

func _verificar_enroque(rey: PiezaAjedrez, pos_rey: Vector2, pos_torre: Vector2, casillas_intermedias: Array, legales: Array) -> void:
	var torre = tablero.obtener_pieza(pos_torre.x, pos_torre.y)
	if torre != null and torre.tipo == PiezaAjedrez.Tipo.TORRE and torre.color == rey.color and not torre.ya_se_movio:
		var vacio = true
		for pos in casillas_intermedias:
			if tablero.obtener_pieza(pos.x, pos.y) != null:
				vacio = false
				break
		if vacio:
			var casillas_rey_cruza = []
			if pos_torre.x == 7:
				casillas_rey_cruza = [Vector2(5, pos_torre.y), Vector2(6, pos_torre.y)]
			else:
				casillas_rey_cruza = [Vector2(3, pos_torre.y), Vector2(2, pos_torre.y)]
				
			var atacado = false
			for pos in casillas_rey_cruza:
				if deja_rey_en_jaque(pos_rey, pos, rey.color):
					atacado = true
					break
					
			if not atacado:
				legales.append(pos_torre)

func deja_rey_en_jaque(desde: Vector2, hasta: Vector2, color_aliado: int) -> bool:
	var pieza_movida = tablero.casillas[desde.y][desde.x]
	var pieza_capturada = tablero.casillas[hasta.y][hasta.x]
	
	tablero.casillas[hasta.y][hasta.x] = pieza_movida
	tablero.casillas[desde.y][desde.x] = null
	
	var pos_rey = Vector2(-1, -1)
	for y in range(8):
		for x in range(8):
			var p = tablero.casillas[y][x]
			if p != null and p.tipo == PiezaAjedrez.Tipo.REY and p.color == color_aliado:
				pos_rey = Vector2(x, y)
				break
		if pos_rey.x != -1: break
		
	var en_jaque = false
	if pos_rey.x != -1:
		for y in range(8):
			for x in range(8):
				var enemiga = tablero.casillas[y][x]
				if enemiga != null and enemiga.color != color_aliado:
					var teoricos = enemiga.obtener_movimientos_teoricos(Vector2(x, y), tablero)
					if pos_rey in teoricos:
						en_jaque = true
						break
			if en_jaque: break
			
	tablero.casillas[desde.y][desde.x] = pieza_movida
	tablero.casillas[hasta.y][hasta.x] = pieza_capturada
	
	return en_jaque
	
func esta_en_jaque(color_aliado: int) -> bool:
	var pos_rey = Vector2(-1, -1)
	
	# 1. Buscamos dónde está el Rey de este color
	for y in range(8):
		for x in range(8):
			var p = tablero.casillas[y][x]
			if p != null and p.tipo == PiezaAjedrez.Tipo.REY and p.color == color_aliado:
				pos_rey = Vector2(x, y)
				break
		if pos_rey.x != -1: break
		
	# 2. Verificamos si algún enemigo puede caer en la casilla del Rey
	if pos_rey.x != -1:
		for y in range(8):
			for x in range(8):
				var enemiga = tablero.casillas[y][x]
				if enemiga != null and enemiga.color != color_aliado:
					var teoricos = enemiga.obtener_movimientos_teoricos(Vector2(x, y), tablero)
					if pos_rey in teoricos:
						return true
	return false
	# Revisa si el jugador de un color tiene al menos UN movimiento legal en todo el tablero
func tiene_movimientos_disponibles(color: PiezaAjedrez.ColorPieza) -> bool:
	for y in range(8):
		for x in range(8):
			var p = tablero.obtener_pieza(x, y)
			if p != null and p.color == color:
				var legales = obtener_movimientos_legales(Vector2(x, y))
				if legales.size() > 0:
					return true # Encontró al menos un movimiento válido
	return false

# Verifica si es jaque mate para el color indicado
func es_jaque_mate(color: PiezaAjedrez.ColorPieza) -> bool:
	return esta_en_jaque(color) and not tiene_movimientos_disponibles(color)
