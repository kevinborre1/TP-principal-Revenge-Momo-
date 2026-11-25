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

func _process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var todos_bailando := _estan_todos_los_jugadores_bailando()
	if todos_bailando and not _estaba_en_fiesta:
		empezar_a_bailar()
	elif not todos_bailando and _estaba_en_fiesta:
		detener_baile()

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

func _obtener_jugadores_activos() -> Array:
	var jugadores := []
	for grupo in ["Jugador", "jugadores"]:
		for j in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(j) and not jugadores.has(j):
				jugadores.append(j)
	return jugadores

func _contar_jugadores_bailando() -> int:
	var total := 0
	for j in _obtener_jugadores_activos():
		if j.get("esta_bailando") == true:
			total += 1
	return total

func _estan_todos_los_jugadores_bailando() -> bool:
	var jugadores := _obtener_jugadores_activos()
	if jugadores.is_empty():
		return false
	for j in jugadores:
		if j.get("esta_bailando") != true:
			return false
	return true

func _obtener_animacion_baile() -> String:
	if not animation_player:
		return ""
	for nombre in ["baile/Boom_Dance_2", "Boom_Dance", "baile/Boom_Dance"]:
		if animation_player.has_animation(nombre):
			return nombre
	return ""

# Esta es la función que llamas desde tu diálogo o lógica de fiesta
func empezar_a_bailar() -> void:
	# Desbloquea el logro solo en el cliente local que activó la acción (o en todos si lo prefieres)
	SaveAndLoad.actualizar_logro("BaileConjunto")

	# Si estás en una partida multijugador activa, avisa a todos (incluido vos mismo)
	if multiplayer.has_multiplayer_peer():
		_rpc_empezar_a_bailar.rpc()
	else:
		_rpc_empezar_a_bailar()

@rpc("any_peer", "call_local", "reliable")
func _rpc_empezar_a_bailar() -> void:
	_estaba_en_fiesta = true
	var anim_baile := _obtener_animacion_baile()
	if animation_player and anim_baile != "" and animation_player.current_animation != anim_baile:
		animation_player.play(anim_baile)

func detener_baile() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_detener_baile.rpc()
	else:
		_rpc_detener_baile()

@rpc("any_peer", "call_local", "reliable")
func _rpc_detener_baile() -> void:
	_estaba_en_fiesta = false
	if animation_player and animation_player.has_animation("Agree_Gesture"):
		animation_player.play("Agree_Gesture", 0.3)
