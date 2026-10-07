extends Control
class_name MinijuegoMemoria

signal minijuego_terminado

@export var cartas: Array[Button] = [] 
@export var simbolos: Array[Texture2D] = []  # 8 texturas distintas

@onready var label_timer: Label = $Panel/LabelTimer
@onready var label_resultado: Label = $Panel/LabelResultado

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
	label_resultado.text = "¡Completado!" if gano else "¡Se te acabó el tiempo!"
	label_resultado.show()
	await get_tree().create_timer(2.0).timeout
	minijuego_terminado.emit()
