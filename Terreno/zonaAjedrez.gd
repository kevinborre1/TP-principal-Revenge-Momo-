extends Area3D

const ESCENA_MINIJUEGO := preload("res://minijuegoAjedrez/InterfazAjedrez.tscn")
const GRUPO_JUGADOR := "jugadores"
const TEXTO_AVISO := "Presiona E"

var jugador_dentro := false
var minijuego: Node = null
var capa: CanvasLayer
var etiqueta: Label
var modo_mouse_previo: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

# --- VARIABLES MULTIJUGADOR ---
var jugador_blancas: int = 0
var jugador_negras: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Detectar si alguien se desconecta bruscamente para liberar su asiento
	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	capa = CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	etiqueta = Label.new()
	etiqueta.text = TEXTO_AVISO
	etiqueta.visible = false
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta.add_theme_font_size_override("font_size", 32)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 8)
	capa.add_child(etiqueta)
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	etiqueta.offset_bottom = -80.0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(GRUPO_JUGADOR):
		jugador_dentro = true
		_actualizar_etiqueta()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(GRUPO_JUGADOR):
		jugador_dentro = false
		_actualizar_etiqueta()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_E and jugador_dentro and minijuego == null:
		if _estoy_en_red():
			# Pide asiento al servidor
			rpc_id(1, "solicitar_sentarse", multiplayer.get_unique_id())
		else:
			# Juega localmente offline (Controla ambos colores)
			_abrir_minijuego(-1) 
			
		get_viewport().set_input_as_handled()
		
	elif event.keycode == KEY_ESCAPE and minijuego != null:
		_cerrar_minijuego()
		if _estoy_en_red():
			# Libera el asiento al servidor
			rpc_id(1, "solicitar_levantarse", multiplayer.get_unique_id())
		get_viewport().set_input_as_handled()


func _estoy_en_red() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# --- LÓGICA DE ASIENTOS (SERVIDOR) ---
@rpc("any_peer", "call_local", "reliable")
func solicitar_sentarse(id_jugador: int) -> void:
	if not multiplayer.is_server(): return
	
	if jugador_blancas == 0:
		jugador_blancas = id_jugador
	elif jugador_negras == 0 and jugador_blancas != id_jugador:
		jugador_negras = id_jugador
	else:
		return # Mesa llena
		
	rpc("sync_asientos", jugador_blancas, jugador_negras)

@rpc("any_peer", "call_local", "reliable")
func solicitar_levantarse(id_jugador: int) -> void:
	if not multiplayer.is_server(): return
	
	if jugador_blancas == id_jugador:
		jugador_blancas = 0
	elif jugador_negras == id_jugador:
		jugador_negras = 0
		
	rpc("sync_asientos", jugador_blancas, jugador_negras)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		solicitar_levantarse(id) # Si alguien se cae del server, libera su silla


# --- LÓGICA DE ASIENTOS (CLIENTES) ---
@rpc("authority", "call_local", "reliable")
func sync_asientos(blancas: int, negras: int) -> void:
	jugador_blancas = blancas
	jugador_negras = negras
	
	var mi_id = multiplayer.get_unique_id() if _estoy_en_red() else 0
	
	if minijuego == null:
		if mi_id == blancas:
			_abrir_minijuego(0) # 0 = BLANCAS
		elif mi_id == negras:
			_abrir_minijuego(1) # 1 = NEGRAS


# --- INSTANCIA DEL JUEGO ---
func _abrir_minijuego(mi_color_asignado: int) -> void:
	minijuego = ESCENA_MINIJUEGO.instantiate()
	
	# Le pasamos a la interfaz qué color maneja este jugador
	minijuego.mi_color = mi_color_asignado
	
	# Escuchamos cuando este jugador mueva una pieza para enviarlo por red
	minijuego.movimiento_realizado.connect(_on_jugador_movio_pieza)
	
	capa.add_child(minijuego)
	get_tree().call_group("ocultar_en_minijuego", "hide")

	# Si es local pausamos el mundo. Si es online, NO pausamos para no romperle el juego al otro
	if not _estoy_en_red():
		get_tree().paused = true
		
	modo_mouse_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_actualizar_etiqueta()


func _cerrar_minijuego() -> void:
	if is_instance_valid(minijuego):
		minijuego.queue_free()
	minijuego = null

	get_tree().call_group("ocultar_en_minijuego", "show")
	
	if get_tree().paused:
		get_tree().paused = false
		
	Input.mouse_mode = modo_mouse_previo
	_actualizar_etiqueta()
	
func _actualizar_etiqueta() -> void:
	etiqueta.visible = jugador_dentro and minijuego == null


# --- SINCRONIZACIÓN DE MOVIMIENTOS ---
func _on_jugador_movio_pieza(desde: Vector2, hasta: Vector2, tipo_coronacion: int) -> void:
	if _estoy_en_red():
		rpc("sync_movimiento", desde, hasta, tipo_coronacion)

@rpc("any_peer", "call_remote", "reliable")
func sync_movimiento(desde: Vector2, hasta: Vector2, tipo_coronacion: int) -> void:
	if minijuego != null:
		minijuego.aplicar_movimiento_red(desde, hasta, tipo_coronacion)
