extends Area3D

@export var nombre_logro: String = ""
@export var punto_de_aparicion: Marker3D
@export var muertoMomo: bool

var ya_activado: bool = false
var puede_guardar: bool = false
static var posiciones_cargadas_en_escena: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	tree_exiting.connect(func(): posiciones_cargadas_en_escena = false)
	
	if multiplayer.is_server() and not posiciones_cargadas_en_escena:
		posiciones_cargadas_en_escena = true
		await get_tree().create_timer(0.3).timeout
		await get_tree().physics_frame
		SaveAndLoad.load_game()
		
	await get_tree().create_timer(1.0).timeout
	puede_guardar = true

func _on_body_entered(body: Node3D) -> void:
	if ya_activado or not puede_guardar:
		return
	if not body.is_in_group("Jugador") or body.is_in_group("BotCompanero"):
		return
	
	var pos_respawn := _obtener_posicion_respawn()
	
	# Actualizamos el respawn de todos los jugadores y del bot hacia el Marker3D de esta zona
	for miembro in get_tree().get_nodes_in_group("Jugador"):
		if is_instance_valid(miembro) and "punto_respawn" in miembro:
			miembro.punto_respawn = pos_respawn
	
	if multiplayer.is_server():
		ya_activado = true
		SaveAndLoad.guardarEstadoMomo(muertoMomo)
		SaveAndLoad.establecer_posicion_predeterminada(pos_respawn)
		print("Guardando checkpoint en: ", pos_respawn)

		if nombre_logro != "":
			_dar_logro.rpc(nombre_logro)

		SaveAndLoad.save_game()

func _obtener_posicion_respawn() -> Vector3:
	if is_instance_valid(punto_de_aparicion):
		return punto_de_aparicion.global_position
	push_warning("[Checkpoint] '%s' no tiene asignado 'punto_de_aparicion'. Usando posición del área." % name)
	return global_position + Vector3(0.0, 0.5, 0.0)

@rpc("authority", "call_local", "reliable")
func _dar_logro(nombre: String) -> void:
	if nombre != "":
		SaveAndLoad.actualizar_logro(nombre)
		
