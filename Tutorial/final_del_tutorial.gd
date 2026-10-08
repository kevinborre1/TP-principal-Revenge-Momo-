extends Area3D

const escena_destino = "res://Terreno/terreno.tscn"

var jugadores_dentro: Array[Node3D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
	if body not in jugadores_dentro:
		jugadores_dentro.append(body)
	_revisar()

func _on_body_exited(body: Node3D) -> void:
	jugadores_dentro.erase(body)

func _revisar() -> void:
	var total = get_tree().get_nodes_in_group("Jugador").size()
	if jugadores_dentro.size() < total:
		return
	
	if Global.modo_multijugador == "linea":
		# Solo el host decide y le avisa a todos
		if multiplayer.is_server():
			cambiar_escena.rpc(escena_destino)
	else:
		cambiar_escena(escena_destino)

@rpc("authority", "call_local", "reliable")
func cambiar_escena(ruta: String) -> void:
	if Global.modo_multijugador == "linea":
		await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(ruta)
