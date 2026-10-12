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
	archivo.store_string(JSON.stringify(top))


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
	top.clear()
	guardar()  # sobrescribe el archivo del slot actual
	puntajes_actualizados.emit()
