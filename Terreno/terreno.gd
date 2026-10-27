extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")

@onready var contenedor_principal = $HBoxContainer
@onready var subviewport_container1 = $HBoxContainer/SubViewportContainer
@onready var subviewport_container2 = $HBoxContainer/SubViewportContainer2
@onready var subviewport1 = $HBoxContainer/SubViewportContainer/SubViewport
@onready var subviewport2 = $HBoxContainer/SubViewportContainer2/SubViewport2
@onready var pantalla_desconexion: CanvasLayer = $PantallaDesconexion
@onready var texto_modo: Label = $Label
@onready var activador_victoria: Area3D = $ActivadorVictoria

const TIEMPO_MAX_CONEXION := 40.0

var cartel_conexion: Label
var timer_conexion: Timer
var conexion_resuelta := false
var saliendo := false

func _ready() -> void:
	if Global.modo_de_juego == "normal":
		texto_modo.text = "Modo: Normal"
	elif Global.modo_de_juego == "vida_compartida":
		texto_modo.text = "Modo: Vida Compartida"
	elif Global.modo_de_juego == "contrarreloj":
		texto_modo.text = "Modo: Contrarreloj"

	GameManager.set_mode(GameManager.GameMode.RECOLECCION, 3)
	
	# Configurar la UI
	contenedor_principal.set_anchors_preset(Control.PRESET_FULL_RECT)
	subviewport_container1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subviewport_container1.stretch = true
	subviewport_container2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subviewport_container2.stretch = true

	# Ocultamos la UI por defecto para evitar pantallas grises
	contenedor_principal.hide() 

	if Global.modo_multijugador == "local":
		# MODO LOCAL
		contenedor_principal.show()
		subviewport_container2.show()
		subviewport2.world_3d = subviewport1.world_3d
		
		var p1 = player_scene.instantiate()
		p1.name = "1"
		p1.position = Vector3(36, 2, 1250)
		subviewport1.add_child(p1)
		
		var p2 = player_scene.instantiate()
		p2.name = "2" 
		p2.position = Vector3(40, 2, 1250)
		subviewport2.add_child(p2)
		
	if Global.modo_multijugador == "linea":
		# MODO EN LÍNEA
		if NetworkManager.quiero_ser_host:
			# El host escucha cuando alguien se conecta para crearle su personaje
			multiplayer.peer_connected.connect(_on_peer_connected)
			
			# Copiamos el código al portapapeles cuando se crea la sesión
			NetworkManager.tube_client.session_created.connect(_on_session_created)
			NetworkManager.tube_client.create_session()
			
			add_player(1) 
		else:
			NetworkManager.host_cerro_partida.connect(_on_servidor_desconectado)
			_iniciar_espera_conexion()
			NetworkManager.tube_client.join_session(NetworkManager.codigo_para_unirse)
			
	activador_victoria.body_entered.connect(_on_activador_victoria_body_entered)

# El Host ejecuta esto automáticamente cuando un cliente entra
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		add_player(id)

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	new_player.position = Vector3(randf_range(36, 40), 2, 1150)
	new_player.add_to_group("jugadores")
	add_child(new_player)

# Función para que el Host copie el código al portapapeles
func _on_session_created() -> void:
	var codigo = NetworkManager.tube_client.session_id
	DisplayServer.clipboard_set(codigo)
	print("Sesión creada. Código copiado: ", codigo)
	NetworkManager.tube_client.session_created.disconnect(_on_session_created)

func _on_servidor_desconectado() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	print("El host se ha desconectado. Encendiendo pantalla de aviso...")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pantalla_desconexion.show()

func _on_boton_volver_menu_pressed() -> void:
	get_tree().paused = false
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")
	
func _on_activador_victoria_body_entered(body: Node3D) -> void:
	# Verificamos si el objeto que entró al área pertenece al grupo 'jugadores'
	if body.is_in_group("jugadores"):
		print("¡Jugador tocó la meta! Cambiando a escena de victoria...")

		get_tree().change_scene_to_file("res://Menu/Victoria.tscn")

# Cliente mientras no aparezca el cliente no hay camara, asi que mostramos un aviso
func _iniciar_espera_conexion() -> void:
	cartel_conexion = Label.new()
	cartel_conexion.text = "Conectando con el host..."
	cartel_conexion.add_theme_font_size_override("font_size", 32)
	cartel_conexion.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(cartel_conexion)
	
	timer_conexion = Timer.new()
	timer_conexion.one_shot = true
	timer_conexion.wait_time = TIEMPO_MAX_CONEXION
	timer_conexion.timeout.connect(_on_timeout_conexion)
	add_child(timer_conexion)
	timer_conexion.start()
	
	child_entered_tree.connect(_on_hijo_agregado)
	NetworkManager.tube_client.error_raised.connect(_on_error_tube)
	NetworkManager.escena_distinta_del_host.connect(_on_escena_distinta_del_host)
	
# El multiplayerSpawner agrega los jugadores en la raiz cuando llega le nuestro, ya estamos conectados
func _on_hijo_agregado(nodo: Node) -> void:
	if conexion_resuelta or not NetworkManager.red_conectada():
		return
	if nodo.name == str(multiplayer.get_unique_id()):
		conexion_resuelta = true
		timer_conexion.stop()
		cartel_conexion.hide()
		child_entered_tree.disconnect(_on_hijo_agregado)
		print("[Red] Conectado como peer ", multiplayer.get_unique_id(), ". Jugador local listo.")

func _on_timeout_conexion() -> void:
	if not conexion_resuelta:
		_abortar_conexion("No se pudo conectar con el host (tiempo agotado).\nRevisá el código o probá con otra red.")

func _on_conexion_fallida() -> void:
	if not conexion_resuelta:
		_abortar_conexion.call_deferred("La conexión con el host falló.")

func _on_escena_distinta_del_host(ruta: String) -> void:
	_abortar_conexion.call_deferred("El host está en otra escena (%s).\nNo se puede unir a esa partida." % ruta)

func _abortar_conexion(mensaje: String) -> void:
	if saliendo:
		return
	saliendo = true
	timer_conexion.stop()
	print("[Red] Conexión cancelada: ", mensaje)
	
	if NetworkManager.host_cerro_partida.is_connected(_on_servidor_desconectado):
		NetworkManager.host_cerro_partida.disconnect(_on_servidor_desconectado)
	NetworkManager.mensaje_error_conexion = mensaje
	NetworkManager.disconnect_game()
	var menu := NetworkManager.escena_menu_en_linea
	if menu == "":
		menu = "res://Menu/MenuPrincipal.tscn"
	get_tree().change_scene_to_file(menu)

# Tube se rindió (trackers caídos, falla de WebRTC o código inválido)
func _on_error_tube(_codigo: int, mensaje: String) -> void:
	if not conexion_resuelta:
		_abortar_conexion.call_deferred("No se pudo conectar con el host.\n(" + mensaje + ")")
