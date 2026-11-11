extends Area3D
class_name ZonaRoles

@export var intervalo_roles: float = 5.0
# Para testear solo: con un único jugador, tiene los dos roles
@export var permitir_un_jugador: bool = true
# Si está activado, los roles arrancan recién cuando todos los jugadores pasaron por la zona
@export var requiere_todos_los_jugadores: bool = false

var roles_iniciados: bool = false
var _timer_roles: Timer
var _pasaron: Array = []


func _ready() -> void:
	add_to_group("ZonaRoles")
	body_entered.connect(_on_body_entered)

	_timer_roles = Timer.new()
	_timer_roles.wait_time = intervalo_roles
	_timer_roles.timeout.connect(_sortear_roles)
	add_child(_timer_roles)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or roles_iniciados:
		return
	if not body.is_in_group("Jugador"):
		return

	if requiere_todos_los_jugadores:
		if not _pasaron.has(body):
			_pasaron.append(body)
		var jugadores := _jugadores()
		for j in jugadores:
			if not _pasaron.has(j):
				return

	iniciar_roles()


# Pública: también se puede llamar por grupo (por ejemplo al cargar una partida)
func iniciar_roles() -> void:
	if not multiplayer.is_server() or roles_iniciados:
		return
	roles_iniciados = true
	_sortear_roles()
	_timer_roles.start()


# Pública: el activador de oleadas la llama cuando termina todo
func terminar_roles() -> void:
	if not multiplayer.is_server():
		return
	_timer_roles.stop()
	for jugador in _jugadores():
		jugador.asignar_rol.rpc("ambos")


func _sortear_roles() -> void:
	var jugadores := _jugadores()
	if jugadores.is_empty():
		return

	if jugadores.size() == 1:
		if permitir_un_jugador:
			jugadores[0].asignar_rol.rpc("ambos")
		else:
			# Solo no se puede ganar: le toca un rol solo
			jugadores[0].asignar_rol.rpc(["rompe_escudo", "letal"].pick_random())
		return

	var roles := ["rompe_escudo", "letal"]
	roles.shuffle()
	for i in jugadores.size():
		jugadores[i].asignar_rol.rpc(roles[i % 2])


func _jugadores() -> Array:
	var lista := []
	for nodo in get_tree().get_nodes_in_group("Jugador"):
		if nodo is Player and not lista.has(nodo):
			lista.append(nodo)
	return lista
