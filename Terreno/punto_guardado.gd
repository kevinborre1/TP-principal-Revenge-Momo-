extends Area3D
@export var nombre_logro: String = ""
# NUEVO: Referencia modular al punto donde queremos que reaparezca el jugador.
@export var punto_de_aparicion: Marker3D
var ya_activado: bool = false
var puede_guardar: bool = false
static var posiciones_cargadas_en_escena: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	tree_exiting.connect(func(): posiciones_cargadas_en_escena = false)
	
	if multiplayer.is_server() and not posiciones_cargadas_en_escena:
		posiciones_cargadas_en_escena = true
		# Esperamos 0.3s a que aparezcan los personajes y el piso cargue sus colisiones
		await get_tree().create_timer(0.3).timeout
		await get_tree().physics_frame
		SaveAndLoad.load_game()
		
	# Esperamos 1 segundo antes de activar el checkpoint para no sobrescribir al aparecer
	await get_tree().create_timer(1.0).timeout
	puede_guardar = true

func _on_body_entered(body: Node3D) -> void:
	if ya_activado:
		return
	if not puede_guardar or not body.is_in_group("Jugador"):
		return
	body.punto_respawn = punto_de_aparicion.global_position
	if multiplayer.is_server():
		ya_activado = true
		
		# NUEVO: Le pasamos la posición predeterminada a nuestro sistema de guardado
		if punto_de_aparicion != null:
			# Asumimos que creas esta función en tu Singleton SaveAndLoad
			SaveAndLoad.establecer_posicion_predeterminada(punto_de_aparicion.global_position)
			print("guardando")
		SaveAndLoad.actualizar_logro(nombre_logro)
		SaveAndLoad.save_game()
		
@rpc("authority", "call_local", "reliable")
func _dar_logro(nombre: String) -> void:
	if nombre != "":
		SaveAndLoad.actualizar_logro(nombre)
		
