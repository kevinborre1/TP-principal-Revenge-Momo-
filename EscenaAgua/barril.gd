extends StaticBody3D

@export var indestructible: bool = false
@export var color_indestructible: Color = Color(0.95, 0.15, 0.15)
@export var sonido_rebote: AudioStream # Opcional: si queda vacío usa SFX_BARRIL_CRASH más agudo

var indestructible_revelado: bool = false
var _destruido: bool = false

# Sonidos
const SFX_BARRIL_CRASH = preload("res://sonidos/barril_crash.wav")

func _ready() -> void:
	# Añadimos todos los barriles al grupo para que la balsa y Nico los reconozcan
	add_to_group("BarrilesMapa")
	add_to_group("Barriles")

@rpc("any_peer", "call_local", "reliable")
func _daniar(_danio: int) -> void:
	if _destruido:
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	
	# Si es indestructible, no suma como barril roto ni se destruye: se tiñe de rojo
	if indestructible:
		if not indestructible_revelado:
			if Global.modo_multijugador == "linea" and sender_id == 0:
				_revelar_indestructible.rpc()
			else:
				_revelar_indestructible()
		return
	
	if sender_id == 0 or sender_id == multiplayer.get_unique_id():
		SaveAndLoad.sumar_estadistica("barrilesRotos")
	
	# Propagamos la destrucción a todos los jugadores por red
	if Global.modo_multijugador == "linea" and sender_id == 0:
		_destruir_barril.rpc()
	else:
		_destruir_barril()

# Esta es la función que llama la balsa al chocar
@rpc("any_peer", "call_local", "reliable")
func _colision_balsa() -> void:
	if Global.modo_multijugador == "linea":
		_sincronizar_colision_balsa.rpc()
	else:
		_sincronizar_colision_balsa()

@rpc("any_peer", "call_local", "reliable")
func _sincronizar_colision_balsa() -> void:
	# Si la balsa choca contra un barril indestructible, el barril no desaparece: se revela rojo
	if indestructible:
		_reproducir_sonido_rebote()
		if not indestructible_revelado:
			_aplicar_color_rojo()
		return
	
	# 1. Apagamos la colisión. Usamos set_deferred por seguridad en las físicas de Godot.
	$CollisionShape3D.set_deferred("disabled", true)
	
	reproducir_sfx_3d(SFX_BARRIL_CRASH)
	# 2. Apagamos el modelo visual (el padre Sketchfab_Scene)
	var nodo_padre := get_parent()
	if nodo_padre and _es_contenedor_barril(nodo_padre):
		nodo_padre.visible = false
		
	# 3. Pausamos la ejecución de esta función por 6 segundos sin congelar el juego
	await get_tree().create_timer(6.0).timeout
	
	# 4. Reactivamos la colisión y la visibilidad
	if is_instance_valid(self) and not _destruido:
		$CollisionShape3D.set_deferred("disabled", false)
		if is_instance_valid(nodo_padre) and _es_contenedor_barril(nodo_padre):
			nodo_padre.visible = true

@rpc("any_peer", "call_local", "reliable")
func _revelar_indestructible() -> void:
	if indestructible_revelado:
		return
	_reproducir_sonido_rebote()
	_aplicar_color_rojo()

@rpc("any_peer", "call_local", "reliable")
func _destruir_barril() -> void:
	if _destruido:
		return
	_destruido = true
	
	reproducir_sfx_3d(SFX_BARRIL_CRASH)
	$CollisionShape3D.set_deferred("disabled", true)
	
	var mallas: Array[MeshInstance3D] = _obtener_mallas_visuales()
	if not mallas.is_empty():
		var tween := create_tween()
		tween.set_parallel(true)
		for malla in mallas:
			tween.tween_property(malla, "scale", Vector3(0.001, 0.001, 0.001), 0.15)
		await tween.finished
	
	var nodo_padre := get_parent()
	if nodo_padre and _es_contenedor_barril(nodo_padre):
		nodo_padre.queue_free()
	else:
		queue_free()

func _obtener_mallas_visuales() -> Array[MeshInstance3D]:
	var resultado: Array[MeshInstance3D] = []
	var nodo_padre := get_parent()
	
	# Si el padre es el contenedor visual del barril (y no la raíz del nivel), buscamos sus mallas
	if nodo_padre and _es_contenedor_barril(nodo_padre):
		for n in nodo_padre.find_children("*", "MeshInstance3D", true, false):
			if n is MeshInstance3D:
				resultado.append(n as MeshInstance3D)
	
	if resultado.is_empty():
		for n in find_children("*", "MeshInstance3D", true, false):
			if n is MeshInstance3D:
				resultado.append(n as MeshInstance3D)
	
	return resultado

func _aplicar_color_rojo() -> void:
	indestructible_revelado = true
	
	# Buscamos las mallas tanto dentro del StaticBody3D como en su padre Sketchfab_Scene
	var mallas: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	if mallas.is_empty():
		var nodo_padre := get_parent()
		if nodo_padre and _es_contenedor_barril(nodo_padre):
			mallas = nodo_padre.find_children("*", "MeshInstance3D", true, false)
	
	# Creamos un material nuevo en material_override para no teñir los demás barriles del nivel
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_indestructible
	for m in mallas:
		if m is MeshInstance3D:
			m.material_override = mat

func _es_contenedor_barril(nodo: Node) -> bool:
	if nodo == null or nodo == get_tree().current_scene:
		return false
	return nodo.name != "Terreno" and nodo.name != "terreno" and nodo.name != "SceneRoot"

func _reproducir_sonido_rebote() -> void:
	if sonido_rebote != null:
		reproducir_sfx_3d(sonido_rebote, 0.0, true)
	else:
		# Usa el mismo audio de impacto pero con tono más agudo para diferenciar el rebote metálico
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.stream = SFX_BARRIL_CRASH
		player_3d.max_distance = 35.0
		player_3d.pitch_scale = randf_range(1.3, 1.45)
		var escena_actual := get_tree().current_scene
		if escena_actual:
			escena_actual.add_child(player_3d)
		else:
			add_child(player_3d)
		player_3d.global_position = global_position
		player_3d.play()
		player_3d.finished.connect(player_3d.queue_free)

# Sonidos en 3D independientes del nodo del barril para que no se corten al destruirse
func reproducir_sfx_3d(stream: AudioStream, volumen_db: float = 0.0, variar_tono: bool = true) -> void:
	if stream == null:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volumen_db
	player_3d.max_distance = 35.0
	if variar_tono:
		player_3d.pitch_scale = randf_range(0.92, 1.08)
		
	var escena_actual := get_tree().current_scene
	if escena_actual:
		escena_actual.add_child(player_3d)
	else:
		add_child(player_3d)
		
	player_3d.global_position = global_position
	player_3d.play()
	player_3d.finished.connect(player_3d.queue_free)
	
# Sincronización silenciosa para clientes que se conectan cuando el barril ya fue revelado
@rpc("authority", "call_remote", "reliable")
func sincronizar_revelado_tardio() -> void:
	if not indestructible_revelado:
		_aplicar_color_rojo()
