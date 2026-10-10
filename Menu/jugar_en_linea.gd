extends Control

# Referencia a los nodos del menú 
@onready var host_button = $"Hostear Partida"
@onready var input_code = $Codigo
@onready var back_button = $Volver

# Referencia al AutoLoad NetworkManager
@onready var tube_client = NetworkManager.get_node("TubeClient")

var codigo_Ingresado
@onready var cartel_error = $CartelError

const RUTA_SAVE = "user://partida.tres"


func _ready() -> void:
	tube_client.session_created.connect(_on_session_created)
	tube_client.session_joined.connect(_on_session_joined)
	tube_client.error_raised.connect(_on_error)


func _on_hostear_partida_pressed() -> void:
	_disable_interface()
	
	if ResourceLoader.exists(RUTA_SAVE):
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


func _disable_interface() -> void:
	host_button.disabled = true
	input_code.editable = false
	back_button.disabled = true


func _enable_interface() -> void:
	host_button.disabled = false
	input_code.editable = true
	back_button.disabled = false


func _cargar_mapa_correspondiente() -> void:
	# Si existe la partida guardada, va a la escena que guardó
	if ResourceLoader.exists(RUTA_SAVE):
		var data = ResourceLoader.load(RUTA_SAVE) as SaveData
		if data and data.escena_actual != "":
			get_tree().change_scene_to_file(data.escena_actual)
			return

	# Si no hay guardado previo, carga el terreno por defecto
	get_tree().change_scene_to_file("res://Terreno/terreno.tscn")
