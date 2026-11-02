class_name PiezaAjedrez
extends RefCounted

enum Tipo { PEON, TORRE, CABALLO, ALFIL, REINA, REY }
enum ColorPieza { BLANCO, NEGRO }

var tipo: Tipo
var color: ColorPieza
var ya_se_movio: bool = false

func _init(_tipo: Tipo, _color: ColorPieza):
	tipo = _tipo
	color = _color

func obtener_movimientos_teoricos(posicion_actual: Vector2, tablero: TableroAjedrez) -> Array[Vector2]:
	var movimientos: Array[Vector2] = []
	var x = int(posicion_actual.x)
	var y = int(posicion_actual.y)

	# Función interna que revisa si la casilla está vacía o tiene un enemigo
	var verificar_casilla = func(nx: int, ny: int) -> bool:
		if nx < 0 or nx >= 8 or ny < 0 or ny >= 8:
			return false # Fuera del tablero
		var p = tablero.obtener_pieza(nx, ny)
		if p == null:
			movimientos.append(Vector2(nx, ny))
			return true # Vacío, la pieza puede seguir avanzando
		elif p.color != self.color:
			movimientos.append(Vector2(nx, ny))
			return false # Es enemigo: puede capturar, pero frena su avance
		return false # Es aliado: no puede pasar

	match tipo:
		Tipo.PEON:
			var dir = -1 if color == ColorPieza.BLANCO else 1
			var pos_ini = 6 if color == ColorPieza.BLANCO else 1
			
			# Avanzar 1 paso
			if y + dir >= 0 and y + dir < 8 and tablero.obtener_pieza(x, y + dir) == null:
				movimientos.append(Vector2(x, y + dir))
				# Avanzar 2 pasos (solo si está en su inicio y el paso 1 estaba libre)
				if y == pos_ini and tablero.obtener_pieza(x, y + (dir * 2)) == null:
					movimientos.append(Vector2(x, y + (dir * 2)))
			# Capturar en diagonal
			for dx in [-1, 1]:
				if x + dx >= 0 and x + dx < 8 and y + dir >= 0 and y + dir < 8:
					var p = tablero.obtener_pieza(x + dx, y + dir)
					if p != null and p.color != self.color:
						movimientos.append(Vector2(x + dx, y + dir))
		Tipo.CABALLO:
			var saltos = [Vector2(1,2), Vector2(2,1), Vector2(-1,2), Vector2(-2,1), Vector2(1,-2), Vector2(2,-1), Vector2(-1,-2), Vector2(-2,-1)]
			for s in saltos:
				verificar_casilla.call(x + int(s.x), y + int(s.y))
		Tipo.TORRE:
			for d in [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0)]:
				for i in range(1, 8):
					if not verificar_casilla.call(x + int(d.x)*i, y + int(d.y)*i): break
		Tipo.ALFIL:
			for d in [Vector2(1,1), Vector2(1,-1), Vector2(-1,1), Vector2(-1,-1)]:
				for i in range(1, 8):
					if not verificar_casilla.call(x + int(d.x)*i, y + int(d.y)*i): break
		Tipo.REINA: # LA REINA TIENE EL BUCLE (Se mueve ilimitado)
			var dirs = [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0), Vector2(1,1), Vector2(1,-1), Vector2(-1,1), Vector2(-1,-1)]
			for d in dirs:
				for i in range(1, 8):
					if not verificar_casilla.call(x + int(d.x)*i, y + int(d.y)*i): break
		Tipo.REY: # EL REY NO TIENE BUCLE (Solo se mueve 1 paso)
			var dirs = [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0), Vector2(1,1), Vector2(1,-1), Vector2(-1,1), Vector2(-1,-1)]
			for d in dirs:
				verificar_casilla.call(x + int(d.x), y + int(d.y))

	return movimientos
