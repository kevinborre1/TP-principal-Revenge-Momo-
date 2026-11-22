class_name EstadoCooperarBoton
extends BotState

enum TipoCooperacion {
	MANTENER_HASTA_CRUCE,
	CRUZAR_Y_MANTENER,
	SIMULTANEO,
	DESACTIVAR_ESCUDO_JEFE
}

@export var tolerancia_llegada: float = 0.45
@export var tolerancia_boton_jefe: float = 0.9
@export var distancia_abandono: float = 50.0
@export var rango_defensa_boton: float = 8.5
@export var grupo_enemigos: String = "Enemigos"

var tipo: TipoCooperacion = TipoCooperacion.MANTENER_HASTA_CRUCE
var boton_objetivo: Node3D = null
var punto_parada: Node3D = null
var boton_liberacion: Node = null
var zona_cruce: Area3D = null
var nodo_puerta_o_jefe: Node = null
var condicion_salida: Callable
var estado_siguiente: String = "Seguir"
var datos_siguiente: Dictionary = {}

var _ya_piso_boton: bool = false
var _cooldown_interaccion: float = 0.0

func enter(datos: Dictionary = {}) -> void:
	tipo = datos.get("tipo", TipoCooperacion.MANTENER_HASTA_CRUCE)
	boton_objetivo = datos.get("boton", null)
	punto_parada = datos.get("punto_parada", null)
	boton_liberacion = datos.get("boton_liberacion", null)
	zona_cruce = datos.get("zona_cruce", null)
	nodo_puerta_o_jefe = datos.get("objetivo_estado", null)
	condicion_salida = datos.get("condicion_salida", Callable())
	estado_siguiente = datos.get("estado_siguiente", "Seguir")
	datos_siguiente = datos.get("datos_siguiente", {})
	
	if not is_instance_valid(punto_parada):
		punto_parada = boton_objetivo
	
	_ya_piso_boton = false
	_cooldown_interaccion = 0.0
	
	# En pelea de jefe mantiene el arma lista desde que empieza a correr hacia el botón
	bot.equipar_arma(tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE)
	if is_instance_valid(boton_liberacion) and boton_liberacion.has_signal("activado"):
		if not boton_liberacion.activado.is_connected(_on_boton_liberacion_activado):
			boton_liberacion.activado.connect(_on_boton_liberacion_activado)
	
	if tipo == TipoCooperacion.CRUZAR_Y_MANTENER and is_instance_valid(zona_cruce):
		if not zona_cruce.body_entered.is_connected(_on_zona_cruce_body_entered):
			zona_cruce.body_entered.connect(_on_zona_cruce_body_entered)

func exit() -> void:
	if is_instance_valid(boton_liberacion) and boton_liberacion.has_signal("activado"):
		if boton_liberacion.activado.is_connected(_on_boton_liberacion_activado):
			boton_liberacion.activado.disconnect(_on_boton_liberacion_activado)
	
	if is_instance_valid(zona_cruce):
		if zona_cruce.body_entered.is_connected(_on_zona_cruce_body_entered):
			zona_cruce.body_entered.disconnect(_on_zona_cruce_body_entered)
	
	bot.equipar_arma(false)
	boton_liberacion = null
	punto_parada = null
	boton_objetivo = null
	zona_cruce = null
	_ya_piso_boton = false
	_cooldown_interaccion = 0.0

func physics_update(delta: float) -> void:
	if _cooldown_interaccion > 0.0:
		_cooldown_interaccion -= delta
	
	if _tarea_completada():
		state_machine.cambiar_estado(estado_siguiente, datos_siguiente)
		return
	
	if not is_instance_valid(boton_objetivo) or not is_instance_valid(punto_parada):
		state_machine.cambiar_estado("Seguir")
		return
	
	if _esta_sobre_boton():
		_sostener_posicion_en_boton(delta)
	else:
		_desplazar_hacia_boton(delta)

# --- FASES DE MOVIMIENTO Y ANCLAJE ---

func _desplazar_hacia_boton(delta: float) -> void:
	_ya_piso_boton = false
	var es_boton_jefe: bool = (tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE)
	bot.equipar_arma(es_boton_jefe)
	
	if es_boton_jefe:
		_reasignar_si_jugador_ocupo_boton()
	
	var correr: bool = (es_boton_jefe or tipo == TipoCooperacion.CRUZAR_Y_MANTENER)
	bot.mover_hacia(punto_parada.global_position, delta, correr)
	
	# Dispara en movimiento a papitas cercanas sin frenar ni desviarse del botón
	if es_boton_jefe:
		_disparar_amenaza_cercana(delta)

func _sostener_posicion_en_boton(delta: float) -> void:
	_ya_piso_boton = true
	var es_boton_jefe: bool = (tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE)
	bot.detener_movimiento(delta, es_boton_jefe)
	_intentar_interactuar_boton()
	
	if es_boton_jefe:
		bot.equipar_arma(true)
		if _disparar_amenaza_cercana(delta):
			return
		if is_instance_valid(nodo_puerta_o_jefe) and nodo_puerta_o_jefe is Node3D:
			bot.rotar_hacia(obtener_posicion_jefe(nodo_puerta_o_jefe as Node3D), delta)
			return
	
	bot.rotar_hacia(boton_objetivo.global_position, delta)

func _esta_sobre_boton() -> bool:
	if punto_parada == boton_objetivo:
		if boton_objetivo is Area3D and (boton_objetivo as Area3D).overlaps_body(bot):
			return true
		for area in boton_objetivo.find_children("*", "Area3D", true, false):
			if (area as Area3D).overlaps_body(bot):
				return true
				
	
	var pos_bot := Vector2(bot.global_position.x, bot.global_position.z)
	var pos_destino := Vector2(punto_parada.global_position.x, punto_parada.global_position.z)
	var radio_valido: float = tolerancia_boton_jefe if tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE else tolerancia_llegada
	return pos_bot.distance_to(pos_destino) <= radio_valido

# --- DEFENSA EN RUTA Y SOBRE EL BOTÓN ---

func _disparar_amenaza_cercana(delta: float) -> bool:
	var amenaza: Node3D = _buscar_enemigo_cercano_al_boton(rango_defensa_boton)
	if is_instance_valid(amenaza):
		bot.disparar_a(amenaza, delta)
		return true
	return false

func _buscar_enemigo_cercano_al_boton(rango_max: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_dist: float = rango_max
	
	for enemigo in get_tree().get_nodes_in_group(grupo_enemigos):
		if not (enemigo is Node3D) or not _es_amenaza_valida(enemigo as Node3D):
			continue
		var d: float = bot.global_position.distance_to((enemigo as Node3D).global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = enemigo as Node3D
	
	return mejor

func _es_amenaza_valida(enemigo: Node3D) -> bool:
	if not is_instance_valid(enemigo):
		return false
	if enemigo.get("activo") != true or enemigo.get("muriendo") == true:
		return false
	if enemigo.get("solo_danio_por_pantallas") == true:
		return false
			
	var tiene_escudo: bool = bool(enemigo.get("escudo_activo"))
	match bot.rol:
		"rompe_escudo":
			return tiene_escudo
		"letal":
			return not tiene_escudo
		_:
			return true

# --- COOPERACIÓN Y FINALIZACIÓN ---

func _reasignar_si_jugador_ocupo_boton() -> void:
	var jugador_principal: Node3D = bot.obtener_jugador_principal()
	if not bot.boton_ocupado_por_jugador(boton_objetivo, jugador_principal):
		return

	var alternativo: Node3D = bot.obtener_boton_escudo_libre("BotonEscudoJefe", boton_objetivo)
	if is_instance_valid(alternativo) and alternativo != boton_objetivo:
		boton_objetivo = alternativo
		punto_parada = alternativo
		if datos_siguiente.has("boton_escudo"):
			datos_siguiente["boton_escudo"] = alternativo

func _intentar_interactuar_boton() -> void:
	if _cooldown_interaccion > 0.0 or not is_instance_valid(boton_objetivo):
		return

	if boton_objetivo.get("esta_activado") == true or boton_objetivo.get("esta_activo") == true:
		return

	if boton_objetivo.has_method("interactuar"):
		boton_objetivo.interactuar()
		_cooldown_interaccion = 0.6

func _on_boton_liberacion_activado() -> void:
	if tipo == TipoCooperacion.MANTENER_HASTA_CRUCE:
		state_machine.cambiar_estado(estado_siguiente, datos_siguiente)

func _on_zona_cruce_body_entered(body: Node3D) -> void:
	if tipo != TipoCooperacion.CRUZAR_Y_MANTENER:
		return
	if body.is_in_group("Jugador") and not body.is_in_group("BotCompanero"):
		state_machine.cambiar_estado(estado_siguiente, datos_siguiente)

func _tarea_completada() -> bool:
	if condicion_salida.is_valid():
		return condicion_salida.call()

	if tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE:
		return _escudo_jefe_desactivado()
	
	if is_instance_valid(nodo_puerta_o_jefe):
		if tipo == TipoCooperacion.SIMULTANEO and "esta_abierta" in nodo_puerta_o_jefe:
			return nodo_puerta_o_jefe.esta_abierta

	var jugador: Node3D = bot.obtener_jugador_principal()
	if not is_instance_valid(jugador):
		return false

	if tipo == TipoCooperacion.CRUZAR_Y_MANTENER:
		if is_instance_valid(zona_cruce):
			return zona_cruce.overlaps_body(jugador)
		return _ya_piso_boton and bot.global_position.distance_to(jugador.global_position) < 2.5

	if distancia_abandono > 0.0 and is_instance_valid(boton_objetivo):
		if jugador.global_position.distance_to(boton_objetivo.global_position) > distancia_abandono:
			return true

	return false

func _escudo_jefe_desactivado() -> bool:
	if not is_instance_valid(nodo_puerta_o_jefe):
		return true
	if "fase" in nodo_puerta_o_jefe and int(nodo_puerta_o_jefe.get("fase")) == 3:
		return true
	if nodo_puerta_o_jefe.get("muriendo") == true:
		return true
	if "campo_activo" in nodo_puerta_o_jefe:
		return not bool(nodo_puerta_o_jefe.get("campo_activo"))
	if "escudo_activo" in nodo_puerta_o_jefe:
		return not bool(nodo_puerta_o_jefe.get("escudo_activo"))
	return false
