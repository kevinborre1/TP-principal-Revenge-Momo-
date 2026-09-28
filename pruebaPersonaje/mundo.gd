extends Node3D

var player_scene = preload("res://pruebaPersonaje/player.tscn")

@onready var spawn1: Marker3D = $Terreno/Spawn1
@onready var spawn2: Marker3D = $Terreno/Spawn2
@onready var contenedor_principal = $HBoxContainer
@onready var subviewport_container1 = $HBoxContainer/SubViewportContainer
@onready var subviewport_container2 = $HBoxContainer/SubViewportContainer2
@onready var subviewport1 = $HBoxContainer/SubViewportContainer/SubViewport
@onready var subviewport2 = $HBoxContainer/SubViewportContainer2/SubViewport2

func _ready() -> void:
	# 1. Forzar al contenedor principal a ocupar TODA la ventana ignorando márgenes
	contenedor_principal.set_anchors_preset(Control.PRESET_FULL_RECT)
	subviewport_container1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subviewport_container1.stretch = true
	subviewport_container2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subviewport_container2.stretch = true

	if Global.modo_multijugador == "local":
		# MODO LOCAL: Usamos la UI de pantalla dividida
		contenedor_principal.show() # Aseguramos que la interfaz sea visible
		subviewport_container2.show()
		subviewport2.world_3d = subviewport1.world_3d
		
		# Instanciar Jugador 1
		var p1 = player_scene.instantiate()
		p1.name = "1"
		p1.position = Vector3(36, 2, 1250)
		subviewport1.add_child(p1)
		
		# Instanciar Jugador 2
		var p2 = player_scene.instantiate()
		p2.name = "2" 
		p2.position = Vector3(40, 2, 1250)
		subviewport2.add_child(p2)
		
	elif Global.modo_multijugador == "linea":
		# MODO EN LÍNEA: Apagamos la UI dividida y volvemos a la pantalla normal
		contenedor_principal.hide() 
		
		if not multiplayer.is_server():
			return

		add_player(1)
		
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(_disconnected_player)

func add_player(peer_id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id) 
	new_player.position = Vector3(randf_range(-2, 2), 5, 0)
	
	# SOLUCIÓN: Agregamos al jugador directo al "mundo" para que el MultiplayerSpawner lo detecte
	add_child(new_player)
	
func _disconnected_player(peer_id: int) -> void:
	# SOLUCIÓN: Buscamos al jugador en el "mundo", no en el SubViewport
	var player_deleted = get_node_or_null(str(peer_id))
	if player_deleted:
		player_deleted.queue_free()
