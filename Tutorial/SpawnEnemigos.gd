extends Area3D

@export var enemigo_escena: PackedScene
@export var intervalo_roles: float = 5.0
@export var permitir_un_jugador: bool = true

@onready var contenedor_enemigos: Node3D = $".."
@onready var punto_1: Marker3D = $"../Spawn1"
@onready var punto_2: Marker3D = $"../Spawn2"

var enemigos_generados: bool = false
var enemigos_restantes: int = 0
var _timer_roles: Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	_timer_roles = Timer.new()
	_timer_roles.wait_time = intervalo_roles
	_timer_roles.timeout.connect(_sortear_roles)
	add_child(_timer_roles)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador"):
		return
	if enemigos_generados:
		return
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return

	enemigos_generados = true
	GameManager.papas_atacan = true
	print("Jugador entró a la zona de combate del tutorial")
	
	_iniciar_roles()
	generar_enemigos()

func generar_enemigos() -> void:
	if enemigo_escena == null:
		push_error("SpawnEnemigos: falta asignar enemigo_escena en el Inspector.")
		return

	# Generamos 1 sola oleada de 4 enemigos simples (2 en Spawn1 y 2 en Spawn2)
	# Con un pequeño desplazamiento lateral para que no nazcan superpuestos
	var puntos := [
		punto_1.global_position + Vector3(-0.8, 0.0, 0.0),
		punto_1.global_position + Vector3(0.8, 0.0, 0.0),
		punto_2.global_position + Vector3(-0.8, 0.0, 0.0),
		punto_2.global_position + Vector3(0.8, 0.0, 0.0)
	]

	enemigos_restantes = puntos.size()

	for i in range(puntos.size()):
		crear_enemigo(puntos[i], i)

func crear_enemigo(pos_global: Vector3, indice: int) -> void:
	var papa = enemigo_escena.instantiate()
	papa.name = "PapitaTutorial_" + str(indice)
	papa.perseguir_siempre = true
	papa.position = contenedor_enemigos.to_local(pos_global)

	contenedor_enemigos.add_child(papa, true)
	papa.global_position = pos_global

	# Habilitamos las capas de navegación 1 y 2 (valor 3) para que caminen en el tutorial
	if papa.get("nav_agent"):
		papa.nav_agent.navigation_layers = 3

	if not papa.murio.is_connected(_on_enemigo_muerto):
		papa.murio.connect(_on_enemigo_muerto)

	# Esperamos un frame para que el MultiplayerSpawner del cliente instancie el nodo antes del RPC
	await get_tree().process_frame
	if is_instance_valid(papa):
		papa.activar_enemigo.rpc()

func _on_enemigo_muerto() -> void:
	enemigos_restantes -= 1
	if enemigos_restantes <= 0:
		print("¡Oleada del tutorial derrotada!")
		_terminar_roles()

# ---- Roles cooperativos ----
func _iniciar_roles() -> void:
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	_sortear_roles()
	_timer_roles.start()

func _terminar_roles() -> void:
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
