extends Area3D

## Enemigos que se activan. Si lo dejás vacío, usa todos los nodos del grupo "EnemigoDelFinal"
@export var enemigos: Array[Node3D] = []
## Segundos que pasan desde que pasa el ÚLTIMO jugador hasta que se activan los enemigos
@export var retraso_activacion: float = 1.2
@export var multiplicador_velocidad: float = 2
@export var multiplicador_carrera: float = 2
@export var propiedad_Carrera: StringName = &"multiplicadorDeCarrera"
## Nombre de la variable de velocidad en el script del Player
@export var propiedad_velocidad: StringName = &"velocidadActual"
## Cuántos jugadores tienen que haber pasado como mínimo (2 = host y cliente). Poné 1 para probar solo
@export var jugadores_necesarios: int = 1

var _usada: bool = false
# Jugadores que ya pasaron por la zona (clave: nombre + peer dueño)
var _pasaron: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Solo el servidor decide; el resto lo recibe por RPC
	if not multiplayer.is_server() or _usada:
		return
	if not body.is_in_group("Jugador"):
		return

	_pasaron[_clave(body)] = true
	print("Zona: pasaron %d de %d jugadores" % [_pasaron.size(), _jugadores_actuales().size()])

	if not _pasaron_todos():
		return

	_usada = true
	await get_tree().create_timer(retraso_activacion).timeout
	_activar_todo.rpc()


func _clave(jugador: Node) -> String:
	return "%s_%d" % [jugador.name, jugador.get_multiplayer_authority()]


func _jugadores_actuales() -> Array:
	return get_tree().get_nodes_in_group("Jugador").filter(func(j): return is_instance_valid(j))


## true cuando todos los jugadores conectados ya pasaron (y hay al menos 'jugadores_necesarios')
func _pasaron_todos() -> bool:
	var jugadores := _jugadores_actuales()
	if jugadores.size() < jugadores_necesarios:
		return false
	for j in jugadores:
		if not _pasaron.has(_clave(j)):
			return false
	return true


## Se ejecuta en todos los peers (también en el servidor)
@rpc("authority", "call_local", "reliable")
func _activar_todo() -> void:
	_subir_velocidad_jugadores()
	_activar_enemigos()


func _activar_enemigos() -> void:
	var lista: Array = enemigos if not enemigos.is_empty() \
			else get_tree().get_nodes_in_group("EnemigoDelFinal")
	for e in lista:
		if is_instance_valid(e) and e.has_method("activar_enemigo"):
			# Sin .rpc(): cada peer ejecuta esto, así que no hace falta un RPC extra
			e.activar_enemigo()


func _subir_velocidad_jugadores() -> void:
	for j in get_tree().get_nodes_in_group("Jugador"):
		if not is_instance_valid(j):
			continue
		if propiedad_velocidad in j:
			j.set(propiedad_velocidad, j.get(propiedad_velocidad) * multiplicador_velocidad)
			j.set(propiedad_Carrera, j.get(propiedad_Carrera) * multiplicador_carrera)
		else:
			push_warning("El jugador %s no tiene la variable '%s'." % [j.name, propiedad_velocidad])
