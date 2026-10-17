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
		
	elif Global.modo_multijugador == "linea":
		# MODO EN LÍNEA
		if multiplayer.is_server():
			# El Host solo crea su propio personaje
			add_player(1)
		else:
			# El Cliente escucha si el servidor se cae
			NetworkManager.host_cerro_partida.connect(_on_servidor_desconectado)
			
		# RED DE SEGURIDAD: Llamamos a la corrutina que evitará perder los paquetes
		_reclamar_personajes()

# 1. El cliente espera a cargar y exige sus personajes
func _reclamar_personajes() -> void:
	if multiplayer.is_server(): return
	
	# Le damos 1 segundo vital a la PC del cliente para armar todo el nivel
	await get_tree().create_timer(1.0).timeout
	rpc_id(1, "solicitar_sincronizacion", multiplayer.get_unique_id())

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	new_player.position = Vector3(randf_range(36, 40), 2, 1150)
	new_player.add_to_group("jugadores")
	add_child(new_player)

func _on_servidor_desconectado() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	print("El host se ha desconectado. Encendiendo pantalla de aviso...")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pantalla_desconexion.show()

func _on_boton_volver_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

# 2. El Host recibe el aviso del cliente y acciona
@rpc("any_peer", "call_remote", "reliable")
func solicitar_sincronizacion(peer_id: int) -> void:
	if multiplayer.is_server():
		# Creamos el personaje del cliente si no existe
		if not has_node(str(peer_id)):
			add_player(peer_id)
		
		# Forzamos al cliente a instanciar al Host y a cualquier otro jugador conectado.
		# Esto recupera mágicamente los paquetes que se perdieron en la pantalla de carga.
		for child in get_children():
			if child.is_in_group("jugadores"):
				rpc_id(peer_id, "forzar_aparicion", child.name, child.global_position)

# El Cliente obedece y crea los personajes faltantes manualmente
@rpc("authority", "call_remote", "reliable")
func forzar_aparicion(nombre_nodo: String, pos: Vector3) -> void:
	if not has_node(nombre_nodo):
		var new_player = player_scene.instantiate()
		new_player.name = nombre_nodo
		new_player.position = pos
		new_player.add_to_group("jugadores")
		add_child(new_player)
