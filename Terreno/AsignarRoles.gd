extends Area3D
class_name ZonaRoles

@export var requiere_todos_los_jugadores: bool = false

var roles_iniciados: bool = false
var _pasaron: Array = []


func _ready() -> void:
	add_to_group("ZonaRoles")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or roles_iniciados:
		return
	if not body.is_in_group("Jugador"):
		return

	if requiere_todos_los_jugadores:
		if not _pasaron.has(body):
			_pasaron.append(body)
		for j in _jugadores():
			if not _pasaron.has(j):
				return

	iniciar_roles()


# Pública: también se puede llamar por grupo (por ejemplo al cargar una partida)
func iniciar_roles() -> void:
	if not multiplayer.is_server() or roles_iniciados:
		return
	roles_iniciados = true
	_asignar_ambos()


# Pública: la llama el activador de oleadas cuando termina todo
func terminar_roles() -> void:
	if not multiplayer.is_server():
		return
	_asignar_ambos()


func _asignar_ambos() -> void:
	for jugador in _jugadores():
		jugador.asignar_rol.rpc("ambos")


func _jugadores() -> Array:
	var lista := []
	for nodo in get_tree().get_nodes_in_group("Jugador"):
		if nodo is Player and not lista.has(nodo):
			lista.append(nodo)
	return lista
