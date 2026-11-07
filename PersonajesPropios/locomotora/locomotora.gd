extends StaticBody3D 

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

@onready var exclamacion: Sprite3D = $ExclamacionSprite

var player_in_range: bool = false
var dialogue_active: bool = false

func _ready() -> void:
	if exclamacion:
		exclamacion.visible = false
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

# Esta función se conecta automáticamente desde el panel de señales
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugadores"):
		print("¡Jugador cerca de la locomotora!")
		player_in_range = true
		if exclamacion:
			exclamacion.visible = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("jugadores"):    
		print("¡Jugador se alejó!")
		player_in_range = false
		if exclamacion:
			exclamacion.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not dialogue_active and event.is_action_pressed("ui_accept"):
		DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)

func _on_dialogue_started(_resource) -> void:
	dialogue_active = true

func _on_dialogue_ended(_resource) -> void:
	await get_tree().create_timer(0.2).timeout
	dialogue_active = false
