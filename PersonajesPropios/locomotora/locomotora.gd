extends StaticBody3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

@onready var exclamacion: Sprite3D = $ExclamacionSprite
@onready var animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

var player_in_range: bool = false
var dialogue_active: bool = false
var _estaba_en_fiesta: bool = false

func _ready() -> void:
	add_to_group("bots")
	if exclamacion:
		exclamacion.visible = false
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	

	call_deferred("_compartir_animacion_baile")

func _compartir_animacion_baile() -> void:
	if not animation_player or animation_player.has_animation("baile/Boom_Dance_2"):
		return
	for bot in get_tree().get_nodes_in_group("bots"):
		var otro_ap := bot.get("animation_player") as AnimationPlayer
		if otro_ap and otro_ap.has_animation_library("baile"):
			animation_player.add_animation_library("baile", otro_ap.get_animation_library("baile"))
			break

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

func _contar_jugadores_bailando() -> int:
	var total := 0
	var vistos := []
	for grupo in ["Jugador", "jugadores"]:
		for j in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(j) and not vistos.has(j):
				vistos.append(j)
				if j.get("esta_bailando") == true:
					total += 1
	return total

func empezar_a_bailar() -> void:

	SaveAndLoad.actualizar_logro("BaileConjunto")
	_estaba_en_fiesta = true
	if animation_player and animation_player.has_animation("baile/Boom_Dance_2"):
		if animation_player.current_animation != "baile/Boom_Dance_2":
			animation_player.play("baile/Boom_Dance_2")

func detener_baile() -> void:
		_estaba_en_fiesta = false
		if animation_player and animation_player.has_animation("Agree_Gesture"):
			animation_player.play("Agree_Gesture", 0.3)
