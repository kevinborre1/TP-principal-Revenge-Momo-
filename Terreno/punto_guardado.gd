extends Area3D

var RUTA_SAVE = ""

func _ready() -> void:
	RUTA_SAVE = SaveAndLoad.rutaUtilizada
	# 1. Detectar cuando un personaje entra al área
	body_entered.connect(_on_body_entered)
	
	# 2. Si es el Servidor/Host, intentamos reubicar a los jugadores si existe un guardado
	if multiplayer.is_server():
		_cargar_posiciones_si_existen()

# --- CADA VEZ QUE PISAN EL AREA ---
func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
		
	# Solo el Host ejecuta el guardado en su PC
	if multiplayer.is_server():
		guardar_partida()

func guardar_partida() -> void:
	var data = SaveData.new()
	data.escena_actual = get_tree().current_scene.scene_file_path
	
	# Obtenemos a los 2 jugadores del mapa
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	
	for jugador in jugadores:
		if jugador.name == "1" or jugador.get_multiplayer_authority() == 1:
			data.pos_host = jugador.global_position
		else:
			data.pos_cliente = jugador.global_position
			
	var err = ResourceSaver.save(data, RUTA_SAVE)
	if err == OK:
		print("¡Checkpoint alcanzado! Partida guardada en el Host.")

# --- AL ENTRAR AL MAPA / CARGAR ---
func _cargar_posiciones_si_existen() -> void:
	if not ResourceLoader.exists(RUTA_SAVE):
		return
		
	# Esperamos 0.2 segundos a que se instancien ambos jugadores
	await get_tree().create_timer(0.2).timeout
	
	var data = ResourceLoader.load(RUTA_SAVE) as SaveData
	if data == null:
		return
		
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	
	for jugador in jugadores:
		if jugador.name == "1" or jugador.get_multiplayer_authority() == 1:
			jugador.global_position = data.pos_host
		else:
			jugador.global_position = data.pos_cliente
			
	print("Posiciones guardadas cargadas correctamente.")
