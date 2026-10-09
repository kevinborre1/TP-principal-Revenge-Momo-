extends Node

const SAVE_PATH := "user://puntajes.json"
const MAX_ENTRADAS := 5

signal puntajes_actualizados

# entrada: { "nombre": String, "puntaje": int, "fecha": String }
var top: Array = []


func _ready() -> void:
	cargar()


# -1 si no entró al top
func registrar(nombre: String, puntaje: int) -> int:
	# Los empates quedan por debajo de los puntajes ya registrados
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
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar el top de puntajes: %s" % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(top))


func cargar() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if datos is Array:
		top = datos
