class_name EstadoCooperarBoton
extends BotState

enum TipoCooperacion {
	MANTENER_HASTA_CRUCE,
	CRUZAR_Y_MANTENER,
	SIMULTANEO,
	DESACTIVAR_ESCUDO_JEFE
}

var tipo: TipoCooperacion = TipoCooperacion.MANTENER_HASTA_CRUCE
var boton_objetivo: Node3D = null
var boton_liberacion: Node = null
var nodo_puerta_o_jefe: Node = null
var condicion_salida: Callable
var estado_siguiente: String = "Seguir"
var datos_siguiente: Dictionary = {}

func enter(datos: Dictionary = {}) -> void:
	tipo = datos.get("tipo", TipoCooperacion.MANTENER_HASTA_CRUCE)
	boton_objetivo = datos.get("boton", null)
	boton_liberacion = datos.get("boton_liberacion", null)
	nodo_puerta_o_jefe = datos.get("objetivo_estado", null)
	condicion_salida = datos.get("condicion_salida", Callable())
	estado_siguiente = datos.get("estado_siguiente", "Seguir")
	datos_siguiente = datos.get("datos_siguiente", {})
	
	# Nos suscribimos al botón del otro lado solo mientras estamos en este estado
	if is_instance_valid(boton_liberacion) and boton_liberacion.has_signal("activado"):
		if not boton_liberacion.activado.is_connected(_on_boton_liberacion_activado):
			boton_liberacion.activado.connect(_on_boton_liberacion_activado)

func exit() -> void:
	# Limpiamos la conexión para evitar llamadas fantasma después de salir del estado
	if is_instance_valid(boton_liberacion) and boton_liberacion.has_signal("activado"):
		if boton_liberacion.activado.is_connected(_on_boton_liberacion_activado):
			boton_liberacion.activado.disconnect(_on_boton_liberacion_activado)
	boton_liberacion = null

func _on_boton_liberacion_activado() -> void:
	if tipo == TipoCooperacion.MANTENER_HASTA_CRUCE:
		state_machine.cambiar_estado(estado_siguiente, datos_siguiente)
