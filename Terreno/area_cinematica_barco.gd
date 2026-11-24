extends Area3D

@export var id_cinematica: String = "" # Si queda vacío, usa el nombre del nodo
@export var pepitas_necesarias: int = 1
@export var video_player: VideoStreamPlayer
@export var video_cinematica: VideoStream
@export var punto_aparicion: Marker3D
@export var desactivar_al_activar: bool = true

signal cinematica_terminada

var area_habilitada: bool = false
var cinematica_reproducida: bool = false
var cinematica_activa: bool = false
var boton_saltear: Button = null

func _ready() -> void:
	if id_cinematica.is_empty():
		id_cinematica = name

	# Empieza apagada hasta cumplir las pepitas (y no haber sido vista ya)
	set_deferred("monitoring", false)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Si ya se vio antes, queda bloqueada definitivamente
	if Global.cinematicas_vistas.has(id_cinematica):
		cinematica_reproducida = true
		return

	if GameManager.has_signal("count_changed"):
		GameManager.count_changed.connect(_on_count_changed)

	# Revisa si ya cumple el requisito al entrar a la escena (ej. pepitas_necesarias = 0)
	var pepitas_actuales := _obtener_pepitas_actuales()
	_evaluar_habilitacion(pepitas_actuales)

func _obtener_pepitas_actuales() -> int:
	if "current_count" in GameManager:
		return int(GameManager.current_count)
	return 0

func _on_count_changed(count: int) -> void:
	_evaluar_habilitacion(count)

func _evaluar_habilitacion(pepitas: int) -> void:
	if cinematica_reproducida or area_habilitada:
		return

	if pepitas >= pepitas_necesarias:
		area_habilitada = true
		set_deferred("monitoring", true)

		# Si un jugador ya estaba dentro del área cuando consiguió la pepita
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			for body in get_overlapping_bodies():
				if _es_jugador(body):
					disparar_cinematica.rpc()
					break

func _es_jugador(body: Node3D) -> bool:
	return body.is_in_group("jugadores") or body.is_in_group("Jugador") or body.name.is_valid_int()

func _on_body_entered(body: Node3D) -> void:
	if not area_habilitada or cinematica_reproducida or cinematica_activa:
		return

	if not _es_jugador(body):
		return

	# En multijugador, el servidor coordina el disparo para sincronizar a todos
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	disparar_cinematica.rpc()

@rpc("call_local", "any_peer", "reliable")
func disparar_cinematica() -> void:
	if cinematica_reproducida or cinematica_activa:
		return

	cinematica_reproducida = true
	if not Global.cinematicas_vistas.has(id_cinematica):
		Global.cinematicas_vistas.append(id_cinematica)

	if desactivar_al_activar:
		set_deferred("monitoring", false)

	reproducir_cinematica()

func _conectar_senal_video_exclusiva() -> void:
	if not video_player:
		return
	for conn in video_player.finished.get_connections():
		video_player.finished.disconnect(conn.callable)
	video_player.finished.connect(_on_video_finished, CONNECT_ONE_SHOT)

func reproducir_cinematica() -> void:
	get_tree().call_group("Jugador", "bloquear_controles", true)

	if punto_aparicion:
		var jugadores := get_tree().get_nodes_in_group("Jugador")
		for i in range(jugadores.size()):
			var destino := punto_aparicion.global_position + Vector3(i * 1.5, 0, 0)
			jugadores[i].global_position = destino
			if "punto_respawn" in jugadores[i]:
				jugadores[i].punto_respawn = destino

	if video_player:
		if video_cinematica:
			video_player.stream = video_cinematica
		_conectar_senal_video_exclusiva()

		cinematica_activa = true
		video_player.visible = true
		video_player.play()

		if boton_saltear:
			boton_saltear.show()
			_reposicionar_boton()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		await cinematica_terminada

		cinematica_activa = false
		video_player.visible = false
		if boton_saltear:
			boton_saltear.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	get_tree().call_group("Jugador", "bloquear_controles", false)

func _crear_boton_saltear() -> void:
	if boton_saltear or not video_player:
		return
	boton_saltear = Button.new()
	boton_saltear.text = "Saltar"
	boton_saltear.custom_minimum_size = Vector2(110, 40)
	boton_saltear.focus_mode = Control.FOCUS_NONE
	boton_saltear.visible = false
	boton_saltear.pressed.connect(_on_saltear_pressed)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.65)
	normal.border_color = Color.WHITE
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.25, 0.25, 0.85)

	boton_saltear.add_theme_stylebox_override("normal", normal)
	boton_saltear.add_theme_stylebox_override("hover", hover)
	boton_saltear.add_theme_stylebox_override("pressed", hover)
	boton_saltear.add_theme_color_override("font_color", Color.WHITE)
	boton_saltear.add_theme_color_override("font_hover_color", Color.WHITE)
	boton_saltear.add_theme_font_size_override("font_size", 18)

	var padre := video_player.get_parent()
	padre.add_child(boton_saltear)
	padre.move_child(boton_saltear, padre.get_child_count() - 1)
	boton_saltear.z_index = 100

	if not get_viewport().size_changed.is_connected(_reposicionar_boton):
		get_viewport().size_changed.connect(_reposicionar_boton)
	_reposicionar_boton()

func _reposicionar_boton() -> void:
	if not boton_saltear:
		return
	var tam_ventana := get_viewport().get_visible_rect().size
	boton_saltear.size = boton_saltear.get_combined_minimum_size()
	var pos_pantalla := tam_ventana - boton_saltear.size - Vector2(40, 40)

	var padre_control := boton_saltear.get_parent() as Control
	if padre_control:
		boton_saltear.position = padre_control.get_global_transform_with_canvas().affine_inverse() * pos_pantalla
	else:
		boton_saltear.position = pos_pantalla

func _on_video_finished() -> void:
	if cinematica_activa:
		cinematica_terminada.emit()

func _on_saltear_pressed() -> void:
	if not cinematica_activa:
		return
	if video_player:
		video_player.stop()
	cinematica_terminada.emit()
