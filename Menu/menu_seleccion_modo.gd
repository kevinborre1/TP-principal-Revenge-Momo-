extends Control

@onready var cartel_error: Label = $CartelError
# Botones
@onready var normal: Button = $Normal
@onready var vida_compartida: Button = $VidaCompartida
@onready var contrarreloj: Button = $Contrarreloj

func _ready() -> void:
	pass

func _on_normal_pressed() -> void:
	_iniciar_modo("normal")

func _on_vida_compartida_pressed() -> void:
	_iniciar_modo("vida_compartida")

func _on_contrarreloj_pressed() -> void:
	_iniciar_modo("contrarreloj")

func _iniciar_modo(modo: String) -> void:
	print("Modo elegido: ", modo)
	_disable_interface()
	
	cartel_error.text = "Cargando mapa para crear sesión..."
	cartel_error.show()
	
	Global.modo_de_juego = modo
	
	_cargar_mapa_correspondiente()

func _cargar_mapa_correspondiente() -> void:
	get_tree().change_scene_to_file("res://Terreno/terreno.tscn")

func _enable_interface() -> void:
	normal.disabled = false
	vida_compartida.disabled = false
	contrarreloj.disabled = false
	
func _disable_interface() -> void:
	normal.disabled = true
	vida_compartida.disabled = true
	contrarreloj.disabled = true
