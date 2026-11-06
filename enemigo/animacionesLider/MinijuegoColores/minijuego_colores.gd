extends Node3D

@export var jefe: CharacterBody3D
@export var aciertos_necesarios: int = 5
@export var tiempo_por_ronda: float = 12.0 # 0 = sin límite
@export var pausa_entre_rondas: float = 1.5

@export_group("Furia")
@export var max_fallos: int = 3
@export var fallos_para_reiniciar: int = 2 # 0 = nunca se reinicia
@export var reiniciar_vida_jefe: bool = true # al reiniciar, el líder recupera toda la vida
@export var el_tiempo_activa_furia: bool = true # si es false, el tiempo agotado cuenta como un fallo
@export var multiplicador_velocidad_furia: float = 2.5
@export var cooldown_ataque_furia: float = 0.3
@export var duracion_maxima_furia: float = 30.0 # por seguridad, si no mata a nadie se calma igual (0 = sin límite)

const NOMBRES: Array[String] = ["ROJO", "VERDE", "AZUL", "AMARILLO", "VIOLETA", "NARANJA"]
const COLORES: Array[Color] = [
	Color(0.9, 0.1, 0.1), Color(0.1, 0.75, 0.2), Color(0.15, 0.35, 1.0),
	Color(1.0, 0.9, 0.1), Color(0.6, 0.2, 0.85), Color(1.0, 0.5, 0.0)]

var pantallas: Array[PantallaColor] = []
var activo := false
var esperando := true
var en_furia := false
var indice_correcto := -1
var aciertos := 0
var fallos := 0
var _ultima_consigna: Array = []
var _ultimos_datos: Array = []

var _timer_ronda: Timer
var _timer_furia: Timer
var _hud: CanvasLayer
var _estilo: StyleBoxFlat
var _consigna: Label
var _info: Label

func _ready() -> void:
	for hijo in get_children():
		if hijo is PantallaColor:
			hijo.minijuego = self
			hijo.indice = pantallas.size()
			pantallas.append(hijo)
	_crear_hud()
	_timer_ronda = Timer.new()
	_timer_ronda.one_shot = true
	_timer_ronda.timeout.connect(_on_tiempo_agotado)
	add_child(_timer_ronda)
	_timer_furia = Timer.new()
	_timer_furia.one_shot = true
	_timer_furia.timeout.connect(_terminar_furia)
	add_child(_timer_furia)
	multiplayer.peer_connected.connect(_on_peer_connected)
	GameManager.jugador_caido.connect(_on_jugador_caido)
	if jefe:
		jefe.connect("activado", _on_jefe_activado)
		jefe.connect("murio", _on_jefe_murio)

# ---- Solo el host ----
func _on_jefe_activado() -> void:
	if not multiplayer.is_server() or activo:
		return
	activo = true
	aciertos = 0
	fallos = 0
	_nueva_ronda()

func _nueva_ronda() -> void:
	var palabra_c := randi_range(0, NOMBRES.size() - 1)
	var letra_c := _azar_excepto([palabra_c])
	var fondo_c := _azar_excepto([palabra_c, letra_c])

	# Cada pantalla dice un color distinto y solo una dice el color de la letra
	var otras: Array = []
	for i in NOMBRES.size():
		if i != letra_c:
			otras.append(i)
	otras.shuffle()
	var palabras: Array = [letra_c]
	for i in mini(pantallas.size() - 1, otras.size()):
		palabras.append(otras[i])
	palabras.shuffle()

	var datos: Array = []
	for p in palabras:
		var l := _azar_excepto([p])
		datos.append([p, l, _azar_excepto([l])])
	indice_correcto = palabras.find(letra_c)

	_ultima_consigna = [palabra_c, letra_c, fondo_c]
	_ultimos_datos = datos
	esperando = false
	_aplicar_ronda.rpc(_ultima_consigna, datos, aciertos, fallos)
	if tiempo_por_ronda > 0:
		_timer_ronda.start(tiempo_por_ronda)

func pantalla_disparada(indice: int) -> void:
	if not activo or esperando or en_furia:
		return
	esperando = true
	_timer_ronda.stop()
	var acierto := indice == indice_correcto
	if not acierto:
		fallos += 1
	_mostrar_resultado.rpc(indice, acierto, fallos)
	if acierto:
		aciertos += 1
		if is_instance_valid(jefe):
			var danio := ceili(float(jefe.get("vida_maxima")) / aciertos_necesarios)
			jefe.call("_daniar", danio) # si muere, _on_jefe_murio apaga el minijuego
	elif fallos >= max_fallos:
		_reiniciar_progreso()
		_activar_furia()
		return
	elif fallos_para_reiniciar > 0 and fallos >= fallos_para_reiniciar:
		_reiniciar_minijuego()
		return
	_siguiente_ronda()

func _on_tiempo_agotado() -> void:
	if not activo or esperando or en_furia:
		return
	esperando = true
	if el_tiempo_activa_furia:
		_mostrar_resultado.rpc(-1, false, fallos)
		_activar_furia()
		return
	fallos += 1
	_mostrar_resultado.rpc(-1, false, fallos)
	if fallos >= max_fallos:
		_reiniciar_progreso()
		_activar_furia()
		return
	if fallos_para_reiniciar > 0 and fallos >= fallos_para_reiniciar:
		_reiniciar_minijuego()
		return
	_siguiente_ronda()

func _siguiente_ronda() -> void:
	await get_tree().create_timer(pausa_entre_rondas).timeout
	if activo and not en_furia:
		_nueva_ronda()

# Solo el host: borra el progreso (aciertos, fallos y vida del líder)
func _reiniciar_progreso() -> void:
	aciertos = 0
	fallos = 0
	if reiniciar_vida_jefe and is_instance_valid(jefe):
		jefe.set("vida_actual", jefe.get("vida_maxima"))

# Solo el host: vuelve el minijuego a cero
func _reiniciar_minijuego() -> void:
	_reiniciar_progreso()
	_mostrar_reinicio.rpc()
	_siguiente_ronda()

func _activar_furia() -> void:
	if en_furia or not is_instance_valid(jefe):
		return
	en_furia = true
	esperando = true
	_timer_ronda.stop()
	jefe.rpc("set_furia", true, multiplicador_velocidad_furia, cooldown_ataque_furia)
	_mostrar_furia.rpc(true)
	if duracion_maxima_furia > 0:
		_timer_furia.start(duracion_maxima_furia)

func _terminar_furia() -> void:
	if not en_furia:
		return
	en_furia = false
	fallos = 0
	_timer_furia.stop()
	if is_instance_valid(jefe):
		jefe.rpc("set_furia", false)
	_mostrar_furia.rpc(false)
	if activo:
		_siguiente_ronda()

# GameManager solo emite esto en el host
func _on_jugador_caido(_jugador: Node) -> void:
	if multiplayer.is_server() and en_furia:
		_terminar_furia()

func _on_jefe_murio() -> void:
	if not multiplayer.is_server():
		return
	activo = false
	en_furia = false
	_timer_ronda.stop()
	_timer_furia.stop()
	_terminar.rpc()

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server() or not activo:
		return
	if en_furia:
		_mostrar_furia.rpc_id(id, true)
		jefe.rpc_id(id, "set_furia", true, multiplicador_velocidad_furia, cooldown_ataque_furia)
	elif not esperando:
		_aplicar_ronda.rpc_id(id, _ultima_consigna, _ultimos_datos, aciertos, fallos)

func _azar_excepto(excluir: Array) -> int:
	var n := randi_range(0, NOMBRES.size() - 1)
	while excluir.has(n):
		n = randi_range(0, NOMBRES.size() - 1)
	return n

# ---- En todos los peers ----
@rpc("authority", "call_local", "reliable")
func _aplicar_ronda(consigna: Array, datos: Array, aciertos_actuales: int, fallos_actuales: int) -> void:
	_hud.visible = true
	_consigna.text = NOMBRES[consigna[0]]
	_consigna.add_theme_color_override("font_color", COLORES[consigna[1]])
	_estilo.bg_color = COLORES[consigna[2]]
	_info.text = "Disparen a la pantalla que dice el COLOR DE LA LETRA\nAciertos: %d/%d   Fallos: %d/%d" % [aciertos_actuales, aciertos_necesarios, fallos_actuales, max_fallos]
	for i in pantallas.size():
		if i < datos.size():
			pantallas[i].mostrar(NOMBRES[datos[i][0]], COLORES[datos[i][1]], COLORES[datos[i][2]])

@rpc("authority", "call_local", "reliable")
func _mostrar_resultado(indice: int, acierto: bool, fallos_actuales: int) -> void:
	if indice >= 0 and indice < pantallas.size():
		pantallas[indice].marcar(acierto)
	if acierto:
		_info.text = "¡BIEN! El líder recibió daño"
	elif indice < 0:
		_info.text = "¡Se acabó el tiempo!"
	else:
		_info.text = "¡Pantalla equivocada! Fallos: %d/%d" % [fallos_actuales, max_fallos]

@rpc("authority", "call_local", "reliable")
func _mostrar_reinicio() -> void:
	_info.text = "¡Fallaron %d veces! El minijuego vuelve a empezar" % fallos_para_reiniciar

@rpc("authority", "call_local", "reliable")
func _mostrar_furia(activa: bool) -> void:
	_hud.visible = true
	if activa:
		for p in pantallas:
			p.apagar()
		_consigna.text = "¡FURIA!"
		_consigna.add_theme_color_override("font_color", Color(1, 0.15, 0.1))
		_estilo.bg_color = Color(0.05, 0.05, 0.05)
		_info.text = "¡El líder está furioso! ¡Corran!"
	else:
		_info.text = "El líder se calmó... ¡vuelvan a las pantallas!"

@rpc("authority", "call_local", "reliable")
func _terminar() -> void:
	_hud.visible = false
	for p in pantallas:
		p.apagar()

func _crear_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	_hud.visible = false
	add_child(_hud)

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.anchor_left = 0.5
	caja.anchor_right = 0.5
	caja.offset_left = -260
	caja.offset_right = 260
	caja.offset_top = 50
	_hud.add_child(caja)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo = StyleBoxFlat.new()
	_estilo.set_corner_radius_all(12)
	_estilo.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", _estilo)
	caja.add_child(panel)

	_consigna = Label.new()
	_consigna.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consigna.add_theme_font_size_override("font_size", 56)
	panel.add_child(_consigna)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 6)
	caja.add_child(_info)
