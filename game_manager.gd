extends Node

enum GameMode { RECOLECCION, VIDAS_BALSA }
var papas_atacan: bool = false 
var current_mode: GameMode = GameMode.RECOLECCION
var max_count: int = 3
var current_count: int = 0

var tiempo_restante: float = 900.0 # 15 minutos (15 * 60)
var timer_activo: bool = false

signal mode_changed(new_mode: GameMode, max_count: int)
signal count_changed(current_count: int)
signal objective_completed(mode: GameMode)

func _process(delta: float) -> void:
	# El reloj corre para todos, PERO se detiene si el menú de pausa está abierto
	if Global.modo_de_juego == "contrarreloj" and timer_activo and not Global.menu_pausa_abierto:
		tiempo_restante -= delta
		
		# --- ESTO ES LO QUE FALTABA: Comprobar si el tiempo llegó a 0 ---
		if tiempo_restante <= 0:
			tiempo_restante = 0
			timer_activo = false
			
			# Solo el Host decide si el tiempo se acabó para enviar la orden a todos
			if Global.modo_multijugador != "linea" or multiplayer.is_server():
				_tiempo_agotado.rpc()
# --- FUNCIONES DE CONTROL DEL RELOJ ---
func iniciar_timer() -> void:
	tiempo_restante = 240.0
	timer_activo = true
	if Global.modo_multijugador == "linea" and multiplayer.is_server():
		_sincronizar_timer.rpc(tiempo_restante, timer_activo, Global.modo_de_juego)

func pausar_timer() -> void:
	timer_activo = false
	if Global.modo_multijugador == "linea" and multiplayer.is_server():
		_sincronizar_timer.rpc(tiempo_restante, timer_activo, Global.modo_de_juego)

func reanudar_timer() -> void:
	timer_activo = true
	if Global.modo_multijugador == "linea" and multiplayer.is_server():
		_sincronizar_timer.rpc(tiempo_restante, timer_activo, Global.modo_de_juego)

# NUEVO: El Cliente llama a esto al entrar para robarse los datos del Host
@rpc("any_peer", "call_remote", "reliable")
func _pedir_estado_al_host() -> void:
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		_sincronizar_timer.rpc_id(peer_id, tiempo_restante, timer_activo, Global.modo_de_juego)

# Actualizamos el RPC para que también sincronice la variable del modo de juego
@rpc("authority", "call_local", "reliable")
func _sincronizar_timer(tiempo: float, activo: bool, modo: String) -> void:
	tiempo_restante = tiempo
	timer_activo = activo
	Global.modo_de_juego = modo # ¡Aquí el Cliente se entera de que es Contrarreloj!

func set_mode(mode: GameMode, max_items: int = 3) -> void:
	current_mode = mode
	max_count = max_items
	current_count = 0
	mode_changed.emit(current_mode, max_count)


func register_event() -> void:
	if current_count >= max_count:
		return
		
	if Global.modo_multijugador == "linea":
		# Como ya configuramos que solo el Host entra aquí, el Host le avisa del nuevo número a todos
		rpc("_actualizar_conteo_red", current_count + 1)
	else:
		_actualizar_conteo_red(current_count + 1)

# Esta función actualiza el HUD y dispara la puerta para AMBOS jugadores al mismo tiempo
@rpc("call_local", "reliable")
func _actualizar_conteo_red(nuevo_conteo: int) -> void:
	current_count = nuevo_conteo
	count_changed.emit(current_count) # ¡Acá la puerta escucha la señal y se abre sola!
	
	if current_count >= max_count:
		objective_completed.emit(current_mode)
		_handle_mode_completion()

func _handle_mode_completion() -> void:
	match current_mode:
		GameMode.RECOLECCION:
			print("Recolección completa")
			# ej: desbloquear puerta, avanzar diálogo, etc.
		GameMode.VIDAS_BALSA:
			print("Game over - balsa destruida")
			get_tree().change_scene_to_file("res://ui/game_over.tscn")
@rpc("call_local", "reliable")
func _tiempo_agotado() -> void:
	print("¡Se acabó el tiempo del Contrarreloj!")
	
	# Obtenemos todos los jugadores en el mapa
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	
	for jugador in jugadores:
		# Verificamos si el jugador tiene la función de daño
		if jugador.has_method("_recibir_danio_red"):
			# Le enviamos un daño masivo (ej: 999) para asegurar la muerte instantánea.
			# Usamos call() o la ejecución directa porque _tiempo_agotado ya es un RPC 
			# que se está ejecutando en todas las máquinas.
			jugador._recibir_danio_red(999)
