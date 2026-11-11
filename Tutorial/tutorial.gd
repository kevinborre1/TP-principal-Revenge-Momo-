extends Node3D

@export var punto_inicio: Vector3 = Vector3(-3, 0, -36)
@export var escena_personaje_host: PackedScene = preload("res://pruebaPersonaje/player.tscn")
@export var escena_personaje_cliente: PackedScene = preload("res://pruebaPersonaje/player2.tscn")

const ESCENA_DESTINO := "res://Terreno/terreno.tscn"
const ESCENA_VIDEO := "res://videos/apertura.tscn"
const SEGUNDOS_PARA_SALTAR := 2.5
const TIEMPO_MAX_CONEXION := 40.0
const MAX_JUGADORES := 2   # host + 1 cliente

enum Rol { SOLO, HOST, CLIENTE }

var _rol: Rol = Rol.SOLO
var _modo_multijugador_original: String = ""
var _tiempo_espacio: float = 0.0
var _cambiando_escena: bool = false

var _canvas: CanvasLayer
var _barra_progreso: ProgressBar
var _contenedor_ui: PanelContainer
var _label_codigo: Label
var _cartel_conexion: ColorRect

var _timer_conexion: Timer
var _conexion_resuelta := false
var _saliendo := false


func _ready() -> void:
	MenuOpciones.aplicar_calidad_terreno(get_node_or_null("Entorno/Terrain3D"))

	_rol = _determinar_rol()

	_canvas = CanvasLayer.new()
	_canvas.layer = 20
	add_child(_canvas)

	
	if _rol != Rol.CLIENTE:
		_crear_ui_saltar()

	match _rol:
		Rol.SOLO:
			_iniciar_solo()
		Rol.HOST:
			_iniciar_host()
		Rol.CLIENTE:
			_iniciar_cliente()


func _determinar_rol() -> Rol:
	if Global.modo_multijugador != "linea":
		return Rol.SOLO
	if NetworkManager.quiero_ser_host:
		return Rol.HOST
	if NetworkManager.codigo_para_unirse != "":
		return Rol.CLIENTE
	return Rol.SOLO   # práctica desde el menú, sin sesión


# ---------------------------------------------------------------- SOLO

func _iniciar_solo() -> void:
	# Igual que antes: forzamos "local" para moverse sin esperar conexión de red
	_modo_multijugador_original = Global.modo_multijugador
	Global.modo_multijugador = "local"

	var jugador := _crear_jugador(1)
	add_child(jugador)
	jugador.global_position = punto_inicio
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- HOST

func _iniciar_host() -> void:
	_crear_label_codigo()
	multiplayer.peer_connected.connect(_on_peer_connected)

	if NetworkManager.sesion_host_activa():
		_mostrar_codigo(NetworkManager.tube_client.session_id)
	else:
		NetworkManager.tube_client.session_created.connect(_on_session_created)
		NetworkManager.tube_client.create_session()

	add_player(1)


func _on_session_created() -> void:
	var codigo: String = NetworkManager.tube_client.session_id
	DisplayServer.clipboard_set(codigo)
	print("Sesión creada. Código copiado: ", codigo)
	_mostrar_codigo(codigo)
	NetworkManager.tube_client.session_created.disconnect(_on_session_created)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	# get_peers() no incluye al host, por eso se suma 1
	if multiplayer.get_peers().size() + 1 > MAX_JUGADORES:
		print("[Red] Sala llena, expulsando al peer ", id)
		NetworkManager.tube_client.kick_peer(id)
		return

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or not multiplayer.get_peers().has(id):
		return

	add_player(id)
	if multiplayer.get_peers().size() + 1 >= MAX_JUGADORES:
		NetworkManager.tube_client.refuse_new_connections = true   # cerramos la sala


func add_player(peer_id: int) -> void:
	# En línea, la posición inicial final la fija player.gd (escena llamada "Tutorial")
	add_child(_crear_jugador(peer_id), true)


func _crear_jugador(peer_id: int) -> Node3D:
	var escena := escena_personaje_host if peer_id == 1 else escena_personaje_cliente
	var nuevo := escena.instantiate() as Node3D
	# Es obligatorio que el nombre sea el id para que set_multiplayer_authority funcione
	nuevo.name = str(peer_id)
	nuevo.add_to_group("jugadores")
	nuevo.position = punto_inicio
	if peer_id != 1:
		nuevo.position.z += 3.0
	return nuevo


# ------------------------------------------------------------- CLIENTE

func _iniciar_cliente() -> void:
	_crear_cartel_conexion()

	NetworkManager.host_cerro_partida.connect(_on_servidor_desconectado)
	NetworkManager.escena_distinta_del_host.connect(_on_escena_distinta_del_host)
	NetworkManager.tube_client.error_raised.connect(_on_error_tube)
	child_entered_tree.connect(_on_hijo_agregado)

	_timer_conexion = Timer.new()
	_timer_conexion.one_shot = true
	_timer_conexion.wait_time = TIEMPO_MAX_CONEXION
	_timer_conexion.timeout.connect(_on_timeout_conexion)
	add_child(_timer_conexion)
	_timer_conexion.start()

	NetworkManager.unirse_a_sesion(NetworkManager.codigo_para_unirse)


# El MultiplayerSpawner agrega los jugadores en la raíz: cuando llega el nuestro, ya estamos dentro
func _on_hijo_agregado(nodo: Node) -> void:
	if _conexion_resuelta or not NetworkManager.red_conectada():
		return
	if nodo.name == str(multiplayer.get_unique_id()):
		_conexion_resuelta = true
		_timer_conexion.stop()
		_cartel_conexion.hide()
		child_entered_tree.disconnect(_on_hijo_agregado)
		print("[Red] Conectado al tutorial como peer ", multiplayer.get_unique_id())


func _on_escena_distinta_del_host(ruta: String) -> void:
	if NetworkManager.es_escena_transicion(ruta):
		NetworkManager.reintentar_union.call_deferred()   # el host sigue viendo el video
	elif NetworkManager.puede_seguir_al_host(ruta):
		NetworkManager.seguir_al_host.call_deferred(ruta)
	else:
		_abortar_conexion.call_deferred("El host está en otra escena (%s).\nNo se puede unir a esa partida." % ruta)


func _on_timeout_conexion() -> void:
	if not _conexion_resuelta:
		_abortar_conexion("No se pudo conectar con el host (tiempo agotado).\nRevisá el código o probá con otra red.")


func _on_servidor_desconectado() -> void:
	_abortar_conexion.call_deferred("El host cerró la partida.")


func _on_error_tube(_codigo: int, mensaje: String) -> void:
	if not _conexion_resuelta:
		_abortar_conexion.call_deferred("No se pudo conectar con el host.\n(" + mensaje + ")")


func _abortar_conexion(mensaje: String) -> void:
	if _saliendo:
		return
	_saliendo = true
	if _timer_conexion:
		_timer_conexion.stop()
	print("[Red] Conexión cancelada: ", mensaje)

	if NetworkManager.host_cerro_partida.is_connected(_on_servidor_desconectado):
		NetworkManager.host_cerro_partida.disconnect(_on_servidor_desconectado)
	NetworkManager.mensaje_error_conexion = mensaje
	NetworkManager.disconnect_game()
	var menu := NetworkManager.escena_menu_en_linea
	if menu == "":
		menu = "res://Menu/MenuPrincipal.tscn"
	get_tree().change_scene_to_file(menu)


# ------------------------------------------------------- SALTAR TUTORIAL

func _process(delta: float) -> void:
	if _cambiando_escena or _rol == Rol.CLIENTE:
		return

	if Input.is_physical_key_pressed(KEY_SPACE):
		_tiempo_espacio += delta
		_barra_progreso.value = (_tiempo_espacio / SEGUNDOS_PARA_SALTAR) * 100.0
		_contenedor_ui.modulate.a = 1.0

		if _tiempo_espacio >= SEGUNDOS_PARA_SALTAR:
			ir_al_juego_principal()
	else:
		if _tiempo_espacio > 0.0:
			_tiempo_espacio = maxf(0.0, _tiempo_espacio - delta * 2.5)
			_barra_progreso.value = (_tiempo_espacio / SEGUNDOS_PARA_SALTAR) * 100.0
		_contenedor_ui.modulate.a = 0.75


func ir_al_juego_principal() -> void:
	if _cambiando_escena:
		return

	if _rol == Rol.CLIENTE:
		_cambiando_escena = true
		_solicitar_fin_tutorial_al_host.rpc_id(1)
		return
		
	_cambiando_escena = true

	if _rol == Rol.HOST:
		var ruta := ESCENA_DESTINO
		print("[Tutorial] nueva=", Global.es_partida_nueva, " peers=", multiplayer.get_peers().size())
		if Global.es_partida_nueva:
			Global.es_partida_nueva = false
			ruta = ESCENA_VIDEO
			# Solo si el host está solo cerramos la sala durante el video
			if multiplayer.get_peers().is_empty():
				NetworkManager.tube_client.refuse_new_connections = true
		NetworkManager.host_cambia_escena(ruta)
		return

# SOLO: únicamente si realmente estamos en Rol.SOLO
	if _rol == Rol.SOLO:
		Global.modo_multijugador = _modo_multijugador_original
		if Global.es_partida_nueva:
			Global.es_partida_nueva = false
			get_tree().change_scene_to_file(ESCENA_VIDEO)
		else:
			get_tree().change_scene_to_file(ESCENA_DESTINO)

@rpc("any_peer", "reliable")
func _solicitar_fin_tutorial_al_host() -> void:
	if _rol == Rol.HOST and not _cambiando_escena:
		ir_al_juego_principal()

# ------------------------------------------------------------------- UI

func _crear_ui_saltar() -> void:
	_contenedor_ui = PanelContainer.new()
	_contenedor_ui.anchor_left = 0.5
	_contenedor_ui.anchor_right = 0.5
	_contenedor_ui.anchor_top = 1.0
	_contenedor_ui.anchor_bottom = 1.0
	_contenedor_ui.offset_left = -220.0
	_contenedor_ui.offset_right = 220.0
	_contenedor_ui.offset_top = -95.0
	_contenedor_ui.offset_bottom = -25.0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	estilo.border_color = Color(0.85, 0.65, 0.2, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	_contenedor_ui.add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_contenedor_ui.add_child(vbox)

	var texto := Label.new()
	texto.text = "Mantené presionado [ESPACIO] para saltar el tutorial"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 16)
	vbox.add_child(texto)

	_barra_progreso = ProgressBar.new()
	_barra_progreso.min_value = 0.0
	_barra_progreso.max_value = 100.0
	_barra_progreso.value = 0.0
	_barra_progreso.show_percentage = false
	_barra_progreso.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(_barra_progreso)

	_canvas.add_child(_contenedor_ui)


func _crear_label_codigo() -> void:
	_label_codigo = Label.new()
	_label_codigo.text = "Creando sala..."
	_label_codigo.add_theme_font_size_override("font_size", 18)
	_label_codigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_codigo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label_codigo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_canvas.add_child(_label_codigo)


func _mostrar_codigo(codigo: String) -> void:
	if _label_codigo == null:
		return
	if codigo == "":
		_label_codigo.text = "Creando sala..."
	else:
		_label_codigo.text = "Código de sala: %s  (copiado al portapapeles)" % codigo


func _crear_cartel_conexion() -> void:
	_cartel_conexion = ColorRect.new()
	_cartel_conexion.color = Color(0, 0, 0, 0.9)
	_cartel_conexion.set_anchors_preset(Control.PRESET_FULL_RECT)

	var texto := Label.new()
	texto.text = "Conectando con el host..."
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 22)
	_cartel_conexion.add_child(texto)

	_canvas.add_child(_cartel_conexion)
