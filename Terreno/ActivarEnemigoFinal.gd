extends Area3D

## Enemigos que se activan. Si lo dejás vacío, usa todos los nodos del grupo "EnemigoDelFinal"
@export var enemigos: Array[Node3D] = []
## Segundos que pasan desde que pasa el ÚLTIMO jugador hasta que se activan los enemigos
@export var retraso_activacion: float = 1.0
@export var multiplicador_velocidad: float = 2.0
@export var multiplicador_carrera: float = 2.0
@export var propiedad_Carrera: StringName = &"multiplicadorDeCarrera"
## Nombre de la variable de velocidad en el script del Player
@export var propiedad_velocidad: StringName = &"velocidadActual"
## Cuántos jugadores tienen que haber pasado como mínimo (2 = host y cliente). Poné 1 para probar solo
@export var jugadores_necesarios: int = 1

@export_group("Reinicio al ser golpeados")
## Marker3D donde vuelven los jugadores (tiene que estar FUERA de esta zona)
@export var punto_inicio: Marker3D
## Separación aplicada entre personajes al reaparecer
@export var separacion_jugadores: Vector3 = Vector3(2.0, 0.0, 0.0)

var _usada: bool = false
var _reiniciando: bool = false
var _velocidad_subida: bool = false
var _epoca: int = 0
var _pasaron: Dictionary = {}


func _ready() -> void:
	add_to_group("ZonaFinal")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or _usada or _reiniciando:
		return
	if not body.is_in_group("Jugador"):
		return

	_pasaron[_clave(body)] = true
	print("Zona: pasaron %d de %d jugadores" % [_pasaron.size(), _jugadores_actuales().size()])

	if not _pasaron_todos():
		return

	_usada = true
	var mi_epoca := _epoca
	await get_tree().create_timer(retraso_activacion).timeout
	if mi_epoca != _epoca:
		return
	_activar_todo.rpc()


func _clave(jugador: Node) -> String:
	return "%s_%d" % [jugador.name, jugador.get_multiplayer_authority()]


func _jugadores_actuales() -> Array:
	return get_tree().get_nodes_in_group("Jugador").filter(func(j): return is_instance_valid(j))


func _pasaron_todos() -> bool:
	var jugadores := _jugadores_actuales()
	if jugadores.size() < jugadores_necesarios:
		return false
	for j in jugadores:
		if not _pasaron.has(_clave(j)):
			return false
	return true


func _lista_enemigos() -> Array:
	return enemigos if not enemigos.is_empty() else get_tree().get_nodes_in_group("EnemigoDelFinal")


# ---------------------------------------------------------------
# ACTIVAR
# ---------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _activar_todo() -> void:
	_subir_velocidad_jugadores()
	_activar_enemigos()
	get_tree().call_group("BotCompanero", "cambiar_estado", "Escape")


func _activar_enemigos() -> void:
	for e in _lista_enemigos():
		if is_instance_valid(e) and e.has_method("activar_enemigo"):
			e.activar_enemigo()


func _subir_velocidad_jugadores() -> void:
	_velocidad_subida = true
	for j in _obtener_personajes_locales():
		if j.is_in_group("BotCompanero"):
			_aplicar_boost_bot(j, true)
			continue
		
		if not (propiedad_velocidad in j):
			push_error("El Player no tiene la propiedad '%s'" % propiedad_velocidad)
			continue
		
		if not j.has_meta("final_vel_base"):
			j.set_meta("final_vel_base", j.get(propiedad_velocidad))
			if propiedad_Carrera in j:
				j.set_meta("final_car_base", j.get(propiedad_Carrera))
		j.set(propiedad_velocidad, j.get_meta("final_vel_base") * multiplicador_velocidad)
		if propiedad_Carrera in j and j.has_meta("final_car_base"):
			j.set(propiedad_Carrera, j.get_meta("final_car_base") * multiplicador_carrera)

		if "estamina_infinita" in j:
			j.estamina_infinita = true
			j.StaminaActual = j.StaminaMax
			j.agotado = false
			j.actualizar_barraStamina()


# ---------------------------------------------------------------
# REINICIAR (cuando un enemigo hiere a un jugador o a Nico)
# ---------------------------------------------------------------

func reiniciar_recorrido() -> void:
	if not multiplayer.is_server() or _reiniciando:
		return
	_reiniciando = true
	_reiniciar_todo.rpc()
	await get_tree().create_timer(1.0).timeout
	_reiniciando = false


@rpc("authority", "call_local", "reliable")
func _reiniciar_todo() -> void:
	_epoca += 1
	_desactivar_enemigos()
	_restaurar_velocidad_jugadores()
	_usada = false
	_pasaron.clear()
	_mover_mis_jugadores_al_inicio()


func _desactivar_enemigos() -> void:
	for e in _lista_enemigos():
		if is_instance_valid(e) and e.has_method("desactivar_enemigo"):
			e.desactivar_enemigo()


func _restaurar_velocidad_jugadores() -> void:
	_velocidad_subida = false
	for j in _obtener_personajes_locales():
		if j.is_in_group("BotCompanero"):
			_aplicar_boost_bot(j, false)
			continue
		
		if j.has_meta("final_vel_base"):
			j.set(propiedad_velocidad, j.get_meta("final_vel_base"))
			if j.has_meta("final_car_base"):
				j.set(propiedad_Carrera, j.get_meta("final_car_base"))
			j.remove_meta("final_vel_base")
			j.remove_meta("final_car_base")
		if "estamina_infinita" in j:
			j.estamina_infinita = false


func _mover_mis_jugadores_al_inicio() -> void:
	if punto_inicio == null:
		push_warning("Falta asignar el Marker3D de inicio en la zona")
		return
	
	var indice_cliente: int = 1
	for j in _obtener_personajes_locales():
		var destino: Vector3 = _calcular_destino_respawn(j, indice_cliente)
		if not j.is_in_group("BotCompanero") and j.get_multiplayer_authority() != 1:
			indice_cliente += 1
		
		if "velocity" in j:
			j.velocity = Vector3.ZERO
		
		# Llamada directa (local): en BotNico además lo revive al instante si había muerto
		if j.has_method("mover_a"):
			j.mover_a(destino)
		else:
			j.global_position = destino


# ---------------------------------------------------------------
# HELPERS DE PERSONAJES Y POSICIONAMIENTO (DRY)
# ---------------------------------------------------------------

func _obtener_personajes_locales() -> Array[Node3D]:
	var resultado: Array[Node3D] = []
	for grupo in ["Jugador", "BotCompanero"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not (nodo is Node3D) or not is_instance_valid(nodo):
				continue
			var personaje := nodo as Node3D
			if personaje.is_multiplayer_authority() and not resultado.has(personaje):
				resultado.append(personaje)
	return resultado


func _calcular_destino_respawn(personaje: Node3D, indice_cliente: int) -> Vector3:
	var base: Vector3 = punto_inicio.global_position + Vector3(0.0, 0.35, 0.0)
	var destino: Vector3 = base
	
	if personaje.is_in_group("BotCompanero"):
		# Nico aparece desplazado hacia el lado opuesto al cliente para no encimarse con nadie
		destino = base - separacion_jugadores
	elif personaje.get_multiplayer_authority() != 1 and personaje.name != "1":
		destino = base + separacion_jugadores * float(indice_cliente)
	
	return _ajustar_a_navmesh(destino)


func _ajustar_a_navmesh(punto: Vector3) -> Vector3:
	var mapa: RID = get_world_3d().get_navigation_map()
	if mapa.is_valid() and NavigationServer3D.map_get_iteration_id(mapa) > 0:
		var punto_nav: Vector3 = NavigationServer3D.map_get_closest_point(mapa, punto)
		if punto_nav.distance_to(punto) <= 3.0:
			return punto_nav + Vector3(0.0, 0.25, 0.0)
	return punto


func _aplicar_boost_bot(bot: Node3D, activar: bool) -> void:
	if activar:
		if not bot.has_meta("final_bot_correr_base") and "velocidad_correr" in bot:
			bot.set_meta("final_bot_correr_base", bot.get("velocidad_correr"))
			bot.set_meta("final_bot_caminar_base", bot.get("velocidad_caminar"))
		if bot.has_meta("final_bot_correr_base"):
			bot.set("velocidad_correr", bot.get_meta("final_bot_correr_base") * multiplicador_velocidad)
			bot.set("velocidad_caminar", bot.get_meta("final_bot_caminar_base") * multiplicador_velocidad)
	else:
		if bot.has_meta("final_bot_correr_base"):
			bot.set("velocidad_correr", bot.get_meta("final_bot_correr_base"))
			bot.set("velocidad_caminar", bot.get_meta("final_bot_caminar_base"))
			bot.remove_meta("final_bot_correr_base")
			bot.remove_meta("final_bot_caminar_base")
