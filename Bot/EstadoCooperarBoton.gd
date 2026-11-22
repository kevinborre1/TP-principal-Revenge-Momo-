class_name EstadoCooperarBoton
extends BotState

enum TipoCooperacion {
	MANTENER_HASTA_CRUCE,
	CRUZAR_Y_MANTENER,
	SIMULTANEO,
	DESACTIVAR_ESCUDO_JEFE
}

@export var tolerancia_llegada: float = 0.45
@export var distancia_abandono: float = 50.0#SI me alejo eso metros deja de estar enfocado en hacer la accion con los botones

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
	
	# Si no se pasó un Marker3D separado, el destino es el propio botón (botones de piso)
	if not is_instance_valid(punto_parada):
		punto_parada = boton_objetivo
	
	_ya_piso_boton = false
	_cooldown_interaccion = 0.0
	
	# Suscripción al botón del otro lado (modo MANTENER_HASTA_CRUCE)
	if is_instance_valid(boton_liberacion) and boton_liberacion.has_signal("activado"):
		if not boton_liberacion.activado.is_connected(_on_boton_liberacion_activado):
			boton_liberacion.activado.connect(_on_boton_liberacion_activado)
	
	# Suscripción a la zona de cruce del otro lado de la puerta (modo CRUZAR_Y_MANTENER)
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
	
	# Caso botón de piso (sin punto_parada separado): frena apenas entra en el Area3D
	if punto_parada == boton_objetivo and boton_objetivo is Area3D and boton_objetivo.overlaps_body(bot):
		_ya_piso_boton = true
		bot.detener_movimiento(delta)
		bot.rotar_hacia(boton_objetivo.global_position, delta)
		_intentar_interactuar_boton()
		return
	
	var pos_bot := Vector2(bot.global_position.x, bot.global_position.z)
	var pos_destino := Vector2(punto_parada.global_position.x, punto_parada.global_position.z)
	var dist_horizontal := pos_bot.distance_to(pos_destino)
	
	var correr := (tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE or tipo == TipoCooperacion.CRUZAR_Y_MANTENER)
	
	if dist_horizontal > tolerancia_llegada:
		bot.mover_hacia(punto_parada.global_position, delta, correr)
	else:
		_ya_piso_boton = true
		bot.detener_movimiento(delta)
		bot.rotar_hacia(boton_objetivo.global_position, delta)
		_intentar_interactuar_boton()

func _intentar_interactuar_boton() -> void:
	if _cooldown_interaccion > 0.0 or not is_instance_valid(boton_objetivo):
		return
	
	# Compatible con BotonPuerta (esta_activado) y otros botones (esta_activo)
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
	
	if is_instance_valid(nodo_puerta_o_jefe):
		if tipo == TipoCooperacion.DESACTIVAR_ESCUDO_JEFE and "escudo_activo" in nodo_puerta_o_jefe:
			return not nodo_puerta_o_jefe.escudo_activo
		if tipo == TipoCooperacion.SIMULTANEO and "esta_abierta" in nodo_puerta_o_jefe:
			return nodo_puerta_o_jefe.esta_abierta
	
	var jugador: Node3D = bot.obtener_jugador_principal()
	if not is_instance_valid(jugador):
		return false
	
	if tipo == TipoCooperacion.CRUZAR_Y_MANTENER:
		if is_instance_valid(zona_cruce):
			return zona_cruce.overlaps_body(jugador)
		return _ya_piso_boton and bot.global_position.distance_to(jugador.global_position) < 2.5
	
	# Si te arrepentís y te alejás del puzzle sin cruzar, Nico suelta el botón
	if distancia_abandono > 0.0 and is_instance_valid(boton_objetivo):
		if jugador.global_position.distance_to(boton_objetivo.global_position) > distancia_abandono:
			return true
	
	return false
