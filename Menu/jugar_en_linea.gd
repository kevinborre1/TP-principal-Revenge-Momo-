extends Control

@onready var host_button = find_child("Hostear Partida", true, false)
@onready var host_button_2 = find_child("Hostear Slot 2", true, false)
@onready var host_button_3 = find_child("Hostear Slot 3", true, false)
@onready var input_code = find_child("Codigo", true, false)
@onready var back_button = find_child("Volver", true, false)
@onready var cartel_error = find_child("CartelError", true, false)

# Referencia al AutoLoad NetworkManager
@onready var tube_client = NetworkManager.get_node("TubeClient")
const LOGROS = "user://logros.tres"
const RUTA_SAVE1 = "user://partida1.tres"
const RUTA_SAVE2 = "user://partida2.tres"
const RUTA_SAVE3 = "user://partida3.tres"

var ultimo_codigo_ingresado: String = ""

func _ready() -> void:
	# Si entrás a este menú sin elegir slot, no hay ruta
	SaveAndLoad.rutaUtilizada = ""

func _on_hostear_partida_pressed() -> void:
	_iniciar_host(RUTA_SAVE1)

func _on_hostear_slot_2_pressed() -> void:
	_iniciar_host(RUTA_SAVE2)

func _on_hostear_slot_3_pressed() -> void:
	_iniciar_host(RUTA_SAVE3)

func _iniciar_host(ruta: String) -> void:
	print("Slot elegido: ", ruta)
	_disable_interface()
	ultimo_codigo_ingresado = ""
	SaveAndLoad.rutaUtilizada = ruta  
	
	NetworkManager.quiero_ser_host = true
	
	if FileAccess.file_exists(ruta) or ResourceLoader.exists(ruta):
		cartel_error.text = "Cargando partida guardada..."
		cartel_error.show()
		_cargar_mapa_correspondiente()
	else:
		cartel_error.text = "Cargando mapa para crear sesión..."
		cartel_error.show()
		get_tree().change_scene_to_file("res://Menu/MenuSeleccionModo.tscn")



func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu/MenuPrincipal.tscn")

func _on_codigo_text_submitted(new_text: String) -> void:
	var codigo_limpio = new_text.strip_edges()
	
	if codigo_limpio == "":
		cartel_error.text = "INGRESE UN CÓDIGO VÁLIDO"
		cartel_error.show()
		return
		
	_disable_interface()
	ultimo_codigo_ingresado = codigo_limpio
	
	cartel_error.text = "Cargando mapa para conectar..."
	cartel_error.show()
	
	# GUARDAMOS LA INTENCIÓN Y CAMBIAMOS DE ESCENA PRIMERO
	NetworkManager.quiero_ser_host = false
	NetworkManager.codigo_para_unirse = codigo_limpio
	_cargar_mapa_correspondiente()

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
	
func borrar_guardado(ruta: String) -> bool:
	if ruta == "" or not FileAccess.file_exists(ruta):
		print("No hay guardado para borrar en: ", ruta)
		return false
	
	var err := DirAccess.remove_absolute(ruta)
	if err != OK:
		push_warning("No se pudo borrar %s (error %d)" % [ruta, err])
		return false
	
	print("Guardado borrado: ", ruta)
	return true

func _on_borrar_guardado_slot_1_pressed() -> void:
	borrar_guardado(RUTA_SAVE1)
func _on_borrar_guardado_slot_2_pressed() -> void:
	borrar_guardado(RUTA_SAVE2)
func _on_borrar_guardado_slot_3_pressed() -> void:
	borrar_guardado(RUTA_SAVE3)
