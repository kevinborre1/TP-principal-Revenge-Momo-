class_name JuegoAjedrez
extends Node

var tablero: TableroAjedrez
var turno_actual: PiezaAjedrez.ColorPieza = PiezaAjedrez.ColorPieza.BLANCO

# --- ¡NUEVO! Variable para rastrear la captura al paso ---
var casilla_en_passant: Vector2 = Vector2(-1, -1)

func iniciar_partida():
	tablero = TableroAjedrez.new()
	tablero.inicializar_tablero_clasico()
	casilla_en_passant = Vector2(-1, -1)
	turno_actual = PiezaAjedrez.ColorPieza.BLANCO

# --- ¡NUEVO! Función centralizada que ejecuta el movimiento y detecta el En Passant ---
func ejecutar_movimiento(desde: Vector2, hasta: Vector2) -> void:
	var pieza = tablero.obtener_pieza(desde.x, desde.y)
	var es_salto_doble = false
	
	if pieza != null and pieza.tipo == PiezaAjedrez.Tipo.PEON:
		if abs(desde.y - hasta.y) == 2:
			es_salto_doble = true
		# Si se mueve en diagonal hacia una casilla vacía, es captura al paso
		elif desde.x != hasta.x and tablero.obtener_pieza(hasta.x, hasta.y) == null:
			tablero.casillas[desde.y][hasta.x] = null # Borramos el peón rival
			
	tablero.mover_pieza(desde, hasta)
	
	# Guardar la casilla vulnerable para el siguiente turno
	if es_salto_doble:
		casilla_en_passant = Vector2(desde.x, (desde.y + hasta.y) / 2.0)
	else:
		casilla_en_passant = Vector2(-1, -1)

func obtener_movimientos_legales(pos_pieza: Vector2) -> Array[Vector2]:
	var pieza = tablero.obtener_pieza(pos_pieza.x, pos_pieza.y)
	if pieza == null:
		return []
		
	var teoricos = pieza.obtener_movimientos_teoricos(pos_pieza, tablero)
	var legales: Array[Vector2] = []
	
	# --- Añadir movimiento teórico de En Passant ---
	if pieza.tipo == PiezaAjedrez.Tipo.PEON and casilla_en_passant != Vector2(-1, -1):
		var dir = -1 if pieza.color == PiezaAjedrez.ColorPieza.BLANCO else 1
		var fila_valida = 3 if pieza.color == PiezaAjedrez.ColorPieza.BLANCO else 4
		if int(pos_pieza.y) == fila_valida:
			if abs(pos_pieza.x - casilla_en_passant.x) == 1 and (pos_pieza.y + dir) == casilla_en_passant.y:
				teoricos.append(casilla_en_passant)
	
	for mov in teoricos:
		if not deja_rey_en_jaque(pos_pieza, mov, pieza.color):
			legales.append(mov)
			
	if pieza.tipo == PiezaAjedrez.Tipo.REY and not pieza.ya_se_movio:
		if not deja_rey_en_jaque(pos_pieza, pos_pieza, pieza.color):
			var y = int(pos_pieza.y)
			_verificar_enroque(pieza, pos_pieza, Vector2(7, y), [Vector2(5, y), Vector2(6, y)], legales)
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
	
	# Simulación especial si es captura al paso
	var peon_ep_capturado = null
	var pos_ep = Vector2(-1, -1)
	if pieza_movida != null and pieza_movida.tipo == PiezaAjedrez.Tipo.PEON and hasta == casilla_en_passant and pieza_capturada == null:
		pos_ep = Vector2(hasta.x, desde.y)
		peon_ep_capturado = tablero.casillas[pos_ep.y][pos_ep.x]
		tablero.casillas[pos_ep.y][pos_ep.x] = null
		
	tablero.casillas[hasta.y][hasta.x] = pieza_movida
	tablero.casillas[desde.y][desde.x] = null
	
	var en_jaque = esta_en_jaque(color_aliado)
	
	# Revertir el tablero a la normalidad
	tablero.casillas[desde.y][desde.x] = pieza_movida
	tablero.casillas[hasta.y][hasta.x] = pieza_capturada
	if peon_ep_capturado != null:
		tablero.casillas[pos_ep.y][pos_ep.x] = peon_ep_capturado
		
	return en_jaque

func esta_en_jaque(color_aliado: int) -> bool:
	var pos_rey = Vector2(-1, -1)
	for y in range(8):
		for x in range(8):
			var p = tablero.casillas[y][x]
			if p != null and p.tipo == PiezaAjedrez.Tipo.REY and p.color == color_aliado:
				pos_rey = Vector2(x, y)
				break
		if pos_rey.x != -1: break
		
	if pos_rey.x != -1:
		for y in range(8):
			for x in range(8):
				var enemiga = tablero.casillas[y][x]
				if enemiga != null and enemiga.color != color_aliado:
					var teoricos = enemiga.obtener_movimientos_teoricos(Vector2(x, y), tablero)
					if pos_rey in teoricos:
						return true
	return false

func tiene_movimientos_disponibles(color: PiezaAjedrez.ColorPieza) -> bool:
	for y in range(8):
		for x in range(8):
			var p = tablero.obtener_pieza(x, y)
			if p != null and p.color == color:
				var legales = obtener_movimientos_legales(Vector2(x, y))
				if legales.size() > 0:
					return true
	return false

func es_jaque_mate(color: PiezaAjedrez.ColorPieza) -> bool:
	return esta_en_jaque(color) and not tiene_movimientos_disponibles(color)
