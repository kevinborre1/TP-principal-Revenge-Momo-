extends Node

const RUTA_GENERAL := "user://puntajes.json"  # Sin slot elegido
const MAX_ENTRADAS := 5

signal puntajes_actualizados

# Entrada: { "nombre": String, "puntaje": int, "fecha": String }
var top: Array = []



func _ruta_actual() -> String:
	var slot: String = SaveAndLoad.rutaUtilizada
	if slot == "":
		return RUTA_GENERAL
	return "user://puntajes_%s.json" % slot.get_file().get_basename()


# Devuelve la posición lograda (1 a 5), o -1 si no entró al top
func registrar(nombre: String, puntaje: int) -> int:
	if Global.modo_multijugador == "linea":
		if multiplayer.is_server():
			# Si somos el Host, lo registramos y sincronizamos a todos
			var pos = _registrar_local(nombre, puntaje)
			rpc("_sincronizar_top_cliente", top)
			return pos
		else:
			# Si somos el Cliente, se lo mandamos al Host para que él lo registre (evita duplicados)
			rpc_id(1, "_registrar_en_servidor", nombre, puntaje)
			return 0 # Valor temporal mientras el host responde
	else:
		return _registrar_local(nombre, puntaje)

@rpc("any_peer", "call_local", "reliable")
func _registrar_en_servidor(nombre: String, puntaje: int) -> void:
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
		
	# El Host procesa el puntaje en su archivo oficial
	_registrar_local(nombre, puntaje)
	
	# Propagamos el ranking actualizado a todos los clientes
	if Global.modo_multijugador == "linea":
		rpc("_sincronizar_top_cliente", top)


@rpc("authority", "call_local", "reliable")
func _sincronizar_top_cliente(nuevo_top: Array) -> void:
	top = nuevo_top
	guardar() # Guarda también en el archivo local del cliente para mantener consistencia
	puntajes_actualizados.emit()

func _registrar_local(nombre: String, puntaje: int) -> int:
	cargar()  # asegura que `top` corresponde al slot actual

	var posicion := 0
	for entrada in top:
		if int(entrada["puntaje"]) >= puntaje:
			posicion += 1
		else:
			break

	if posicion >= MAX_ENTRADAS:
		return -1

	top.insert(posicion, {
		"nombre": nombre,
		"puntaje": puntaje,
		"fecha": Time.get_date_string_from_system()
	})
	while top.size() > MAX_ENTRADAS:
		top.pop_back()

	guardar()
	puntajes_actualizados.emit()
	return posicion + 1

func guardar() -> void:
	var archivo := FileAccess.open(_ruta_actual(), FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar el top de puntajes: %s" % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(top, "\t"))


func cargar() -> void:
	top = []  # importante: vaciar antes, si no queda el top del slot anterior
	var ruta := _ruta_actual()
	if not FileAccess.file_exists(ruta):
		return
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if datos is Array:
		top = datos


func reiniciar() -> void:
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	top.clear()
	guardar()  # sobrescribe el archivo del slot actual
	puntajes_actualizados.emit()
	if Global.modo_multijugador == "linea":
		rpc("_sincronizar_top_cliente", top)
