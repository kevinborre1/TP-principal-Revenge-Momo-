extends Control
class_name MinijuegoMemoria

signal minijuego_terminado(gano: bool, puntaje: int)

@export var cartas: Array[Button] = [] 
@export var simbolos: Array[Texture2D] = []  # 8 texturas distintas

@onready var label_timer: Label = $Panel/LabelTimer
@onready var label_resultado: Label = $Panel/LabelResultado
@onready var input_nombre: LineEdit = $Panel/InputNombre
@onready var boton_guardar: Button = $Panel/BotonGuardar

var puntaje_final: int = 0

var nombre_jugador: String = "Jugador"
var tiempo_restante: float = 120.0
var cartas_valores: Array[int] = []
var carta_revelada_1: Button = null
var carta_revelada_2: Button = null
var bloqueado: bool = false
var pares_encontrados: int = 0
var juego_terminado: bool = false


func _ready() -> void:
	_armar_mazo()
	for i in cartas.size():
		cartas[i].pressed.connect(_on_carta_pressed.bind(i))
		cartas[i].text = ""  # arranca oculta
	label_resultado.hide()
	
	input_nombre.hide()
	boton_guardar.hide()
	input_nombre.max_length = 12
	input_nombre.text_submitted.connect(_on_nombre_enviado)
	boton_guardar.pressed.connect(func(): _on_nombre_enviado(input_nombre.text))

func _process(delta: float) -> void:
	if juego_terminado:
		return
	tiempo_restante -= delta
	label_timer.text = "%02d:%02d" % [int(tiempo_restante) / 60, int(tiempo_restante) % 60]
	if tiempo_restante <= 0:
		_terminar_juego(false)

func _armar_mazo() -> void:
	var valores: Array[int] = []
	for i in 8:
		valores.append(i)
		valores.append(i)
	valores.shuffle()
	cartas_valores = valores

func _on_carta_pressed(indice: int) -> void:
	if bloqueado or juego_terminado:
		return
	var carta = cartas[indice]
	if carta == carta_revelada_1:
		return  # ya está revelada, ignorar doble click

	_revelar(carta, indice)

	if carta_revelada_1 == null:
		carta_revelada_1 = carta
	else:
		carta_revelada_2 = carta
		bloqueado = true
		await get_tree().create_timer(0.8).timeout
		_resolver_par()

func _revelar(carta: Button, indice: int) -> void:
	carta.icon = simbolos[cartas_valores[indice]]

func _resolver_par() -> void:
	var i1 = cartas.find(carta_revelada_1)
	var i2 = cartas.find(carta_revelada_2)

	if cartas_valores[i1] == cartas_valores[i2]:
		pares_encontrados += 1
		carta_revelada_1.disabled = true
		carta_revelada_2.disabled = true
		if pares_encontrados >= 8:
			_terminar_juego(true)
	else:
		carta_revelada_1.icon = null
		carta_revelada_2.icon = null

	carta_revelada_1 = null
	carta_revelada_2 = null
	bloqueado = false

func _terminar_juego(gano: bool) -> void:
	juego_terminado = true
	$Panel/GridContainer.hide()
	label_timer.hide()

	if gano:
		# El puntaje todavía NO se registra: primero pedimos el nombre
		puntaje_final = int(round(tiempo_restante * 10.0))
		label_resultado.text = "¡Completado!\nTu puntaje: %d\n\nIngresá tu nombre:" % puntaje_final
		label_resultado.show()
		input_nombre.show()
		boton_guardar.show()
		input_nombre.grab_focus()
	else:
		label_resultado.text = _armar_texto_final(false, 0, -1)
		label_resultado.show()
		await get_tree().create_timer(5.0).timeout
		minijuego_terminado.emit(false, 0)


func _on_nombre_enviado(texto: String) -> void:
	if not input_nombre.visible:
		return  # evita registrar dos veces (Enter + clic en el botón)

	var nombre := texto.strip_edges()
	if nombre.is_empty():
		nombre = nombre_jugador  # si lo dejó vacío, usa "Jugador 1/2"

	input_nombre.hide()
	boton_guardar.hide()

	var posicion := ScoreManager.registrar(nombre, puntaje_final)
	label_resultado.text = _armar_texto_final(true, puntaje_final, posicion)

	await get_tree().create_timer(5.0).timeout
	minijuego_terminado.emit(true, puntaje_final)


func _armar_texto_final(gano: bool, puntaje: int, posicion: int) -> String:
	var texto := "MEJORES PUNTAJES\n"
	if ScoreManager.top.is_empty():
		texto += "Todavía no hay puntajes\n"
	for i in ScoreManager.top.size():
		var entrada = ScoreManager.top[i]
		var marca := "  <" if (i + 1) == posicion else ""
		texto += "%d. %s - %d%s\n" % [i + 1, entrada["nombre"], int(entrada["puntaje"]), marca]

	texto += "\n"
	if gano:
		texto += "¡Completado!\nTu puntaje: %d" % puntaje
		if posicion == -1:
			texto += " (no entró al top 5)"
	else:
		texto += "¡Se te acabó el tiempo!"
	return texto
