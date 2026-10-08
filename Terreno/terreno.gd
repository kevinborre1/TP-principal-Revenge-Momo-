extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")


@onready var contenedor_principal = $HBoxContainer
@onready var subviewport_container1 = $HBoxContainer/SubViewportContainer
@onready var subviewport_container2 = $HBoxContainer/SubViewportContainer2
@onready var subviewport1 = $HBoxContainer/SubViewportContainer/SubViewport
@onready var subviewport2 = $HBoxContainer/SubViewportContainer2/SubViewport2

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
		contenedor_principal.show() # Solo la mostramos si es local
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
		# (La UI ya está oculta, no necesitamos hacer contenedor_principal.hide() de nuevo)
		
		if not multiplayer.is_server():
			return

		add_player(1)
		for peer_id in multiplayer.get_peers():
			add_player(peer_id)
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(_disconnected_player)

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	new_player.position = Vector3(randf_range(36, 40), 2, 1150)
	
	add_child(new_player)
func _disconnected_player(peer_id: int) -> void:
	# Buscamos al jugador en el "mundo", no en el SubViewport
	var player_deleted = get_node_or_null(str(peer_id))
	if player_deleted:
		player_deleted.queue_free()
