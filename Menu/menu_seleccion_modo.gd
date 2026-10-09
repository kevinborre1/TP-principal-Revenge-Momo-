extends Control

# Referencia al AutoLoad 
@onready var tube_client = NetworkManager.get_node("TubeClient")
@onready var cartel_error: Label = $CartelError
#Botones
@onready var normal: Button = $Normal
@onready var vida_compartida: Button = $VidaCompartida
@onready var contrarreloj: Button = $Contrarreloj

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tube_client.session_created.connect(_on_session_created)
	tube_client.session_joined.connect(_on_session_joined)
	tube_client.error_raised.connect(_on_error)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_normal_pressed() -> void:
	_disable_interface()
	cartel_error.text = "Creando Sesion"
	cartel_error.show()
	
	tube_client.create_session()
	print("press normal")


func _on_vida_compartida_pressed() -> void:
	_disable_interface()
	cartel_error.text = "Creando Sesion"
	cartel_error.show()
	
	tube_client.create_session()
	print("press vida comp")


func _on_contrarreloj_pressed() -> void:
	_disable_interface()
	cartel_error.text = "Creando Sesion"
	cartel_error.show()
	
	tube_client.create_session()
	print("press contrarreloj")
	
func _on_session_created() -> void:
	var codigo = tube_client.session_id
	DisplayServer.clipboard_set(codigo)
	print("Sesión creada. Código copiado: ", codigo)
	
	_cargar_mapa_correspondiente()
	
func _cargar_mapa_correspondiente() -> void:
	if Global.mapa_seleccionado == "tutorial":
		get_tree().call_deferred("change_scene_to_file", "res://Tutorial/Tutorial.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Terreno/terreno.tscn")

func _on_session_joined() -> void:
	print("Unido exitosamente al Host")
	_cargar_mapa_correspondiente()

func _on_error(_code, message) -> void:
	# Si falla mostramos el error y reactivamos todo para que puedan volver a intentar
	cartel_error.text = "Error de conexión: " + str(message)
	cartel_error.show()
	_enable_interface()
	
func _enable_interface() -> void:
	normal.disabled = false
	vida_compartida.disabled = false
	contrarreloj.disabled = false
	
func _disable_interface() -> void:
	normal.disabled = true
	vida_compartida.disabled = true
	contrarreloj.disabled = true
	
