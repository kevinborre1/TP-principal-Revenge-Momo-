extends Control

@onready var host_button = find_child("Hostear Partida", true, false)
@onready var host_button_2 = find_child("Hostear Slot 2", true, false)
@onready var host_button_3 = find_child("Hostear Slot 3", true, false)
@onready var input_code = find_child("Codigo", true, false)
@onready var back_button = find_child("Volver", true, false)
@onready var cartel_error = find_child("CartelError", true, false)

# Referencia al AutoLoad NetworkManager
@onready var tube_client = NetworkManager.get_node("TubeClient")

const RUTA_SAVE1 = "user://partida1.tres"
const RUTA_SAVE2 = "user://partida2.tres"
const RUTA_SAVE3 = "user://partida3.tres"

func _ready() -> void:
	# Si entrás a este menú sin elegir slot (por ejemplo, para unirte), no hay ruta
	SaveAndLoad.rutaUtilizada = ""
	tube_client.session_created.connect(_on_session_created)
	tube_client.session_joined.connect(_on_session_joined)
	tube_client.error_raised.connect(_on_error)


func _on_hostear_partida_pressed() -> void:
	_iniciar_host(RUTA_SAVE1)

func _on_hostear_slot_2_pressed() -> void:
	_iniciar_host(RUTA_SAVE2)

func _on_hostear_slot_3_pressed() -> void:
	_iniciar_host(RUTA_SAVE3)

func _iniciar_host(ruta: String) -> void:
	print("Slot elegido: ", ruta)
	_disable_interface()
	SaveAndLoad.rutaUtilizada = ruta  # antes de crear la sesión
	
	if ResourceLoader.exists(ruta):
		cartel_error.text = "Cargando partida guardada..."
	else:
		cartel_error.text = "Creando nueva sesión..."
	cartel_error.show()
	tube_client.create_session()


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")


func _on_codigo_text_submitted(new_text: String) -> void:
	var codigo_limpio = new_text.strip_edges()
	
	if codigo_limpio == "":
		cartel_error.text = "INGRESE UN CÓDIGO VÁLIDO"
		cartel_error.show()
		return
		
	_disable_interface()
	cartel_error.text = "Conectando al Host..."
	cartel_error.show()
	
	tube_client.join_session(codigo_limpio)


func _on_session_created() -> void:
	var codigo = tube_client.session_id
	DisplayServer.clipboard_set(codigo)
	print("Sesión creada. Código copiado: ", codigo)
	_cargar_mapa_correspondiente()


func _on_session_joined() -> void:
	print("Unido exitosamente al Host")
	_cargar_mapa_correspondiente()


func _on_error(_code, message) -> void:
	cartel_error.text = "Error de conexión: " + str(message)
	cartel_error.show()
	_enable_interface()


func _set_interface(habilitada: bool) -> void:
	for boton in [host_button, host_button_2, host_button_3, back_button]:
		if boton:
			boton.disabled = not habilitada
	if input_code:
		input_code.editable = habilitada

func _disable_interface() -> void:
	_set_interface(false)

func _enable_interface() -> void:
	_set_interface(true)


func _cargar_mapa_correspondiente() -> void:
	var ruta = SaveAndLoad.rutaUtilizada
	if ruta != "" and ResourceLoader.exists(ruta):
		var data = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
		if data and data.escena_actual != "":
			get_tree().change_scene_to_file(data.escena_actual)
			return
	get_tree().change_scene_to_file("res://Terreno/terreno.tscn")
