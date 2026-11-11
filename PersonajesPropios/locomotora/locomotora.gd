extends StaticBody3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start" # Asegúrate de que tu archivo .dialogue tenga una línea que diga "=> start" o simplemente comience con el título start

@onready var exclamacion: Sprite3D = $ExclamacionSprite

@onready var animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer


var player_in_range: bool = false
var dialogue_active: bool = false

func _ready() -> void:
	add_to_group("bots")
	if exclamacion:
		exclamacion.visible = false
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador"): 
		player_in_range = true
		if exclamacion:
			exclamacion.visible = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		player_in_range = false
		if exclamacion:
			exclamacion.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Cambiamos "ui_accept" por la acción "interactuar" que creamos para la letra E
	if player_in_range and not dialogue_active and event.is_action_pressed("interactuar"):
		if dialogue_resource:
			DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
		else:
			print("Error: Falta asignar el Dialogue Resource en el Inspector de la Locomotora.")

func _on_dialogue_started(_resource) -> void:
	dialogue_active = true

func _on_dialogue_ended(_resource) -> void:
	await get_tree().create_timer(0.2).timeout
	dialogue_active = false



func empezar_a_bailar():
	if animation_player and not animation_player.is_playing():
		animation_player.play("baile/Boom_Dance_2")

func detener_baile():
	if animation_player:
		animation_player.play("Agree_Gesture", 0.3)
		
