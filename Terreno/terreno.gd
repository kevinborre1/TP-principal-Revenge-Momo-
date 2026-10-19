extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")

@onready var contenedor_principal = $HBoxContainer
@onready var subviewport_container1 = $HBoxContainer/SubViewportContainer
@onready var subviewport_container2 = $HBoxContainer/SubViewportContainer2
@onready var subviewport1 = $HBoxContainer/SubViewportContainer/SubViewport
@onready var subviewport2 = $HBoxContainer/SubViewportContainer2/SubViewport2
@onready var pantalla_desconexion: CanvasLayer = $PantallaDesconexion

func _ready() -> void:
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
			NetworkManager.tube_client.join_session(NetworkManager.codigo_para_unirse)

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
