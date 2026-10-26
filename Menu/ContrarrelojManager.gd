extends Node
class_name ContrarrelojManager

# TIEMPO TOTAL PARA CONTRARRELOJ
const TIEMPO_TOTAL: float = 10.0

var tiempo_restante: float = TIEMPO_TOTAL
var timer_activo: bool = false


func _process(delta: float) -> void:
	if Global.modo_de_juego == "contrarreloj" and timer_activo and not Global.menu_pausa_abierto:
		tiempo_restante -= delta
		
		if tiempo_restante <= 0:
			tiempo_restante = 0
			timer_activo = false
			if Global.modo_multijugador != "linea" or multiplayer.is_server():
				_tiempo_agotado.rpc()

func iniciar_timer() -> void:
	tiempo_restante = TIEMPO_TOTAL
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

@rpc("any_peer", "call_remote", "reliable")
func _pedir_estado_al_host() -> void:
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		_sincronizar_timer.rpc_id(peer_id, tiempo_restante, timer_activo, Global.modo_de_juego)

@rpc("authority", "call_local", "reliable")
func _sincronizar_timer(tiempo: float, activo: bool, modo: String) -> void:
	tiempo_restante = tiempo
	timer_activo = activo
	Global.modo_de_juego = modo 

@rpc("call_local", "reliable")
func _tiempo_agotado() -> void:
	Global.motivo_derrota = "Se acabo el tiempo"
	print("¡Se acabó el tiempo del Contrarreloj!")
	var jugadores = get_tree().get_nodes_in_group("Jugador")
	for jugador in jugadores:
		get_tree().change_scene_to_file("res://Menu/derrota.tscn")
