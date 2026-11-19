extends BotState

enum RolBalsa { ARTILLERO, PILOTO }

var balsa: Node3D = null
var rol_balsa: RolBalsa = RolBalsa.ARTILLERO
var ruta_rio: Array[Marker3D] = [] # Puntos por los que debe navegar si Nico conduce
var _indice_ruta: int = 0

func enter(datos: Dictionary = {}) -> void:
	balsa = datos.get("balsa", null)
	rol_balsa = datos.get("rol_balsa", RolBalsa.ARTILLERO)
	ruta_rio = datos.get("waypoints", [])
	_indice_ruta = 0
	
	if is_instance_valid(balsa):
		bot.set_physics_process(false) # La balsa controla la posición del bot
		bot.prepare_for_raft()

func exit() -> void:
	bot.salir_de_balsa()
	bot.set_physics_process(true)

func physics_update(delta: float) -> void:
	if not is_instance_valid(balsa):
		state_machine.cambiar_estado("Seguir")
		return
	
	match rol_balsa:
		RolBalsa.ARTILLERO:
			_comportamiento_artillero(delta)
		RolBalsa.PILOTO:
			_comportamiento_piloto(delta)

func _comportamiento_artillero(delta: float) -> void:
	# Busca el barril más cercano delante de la balsa y le dispara
	var barril := _buscar_barril_cercano(22.0)
	if is_instance_valid(barril):
		bot.disparar_a(barril, delta)

func _comportamiento_piloto(delta: float) -> void:
	if _indice_ruta >= ruta_rio.size():
		return
	
	var destino := ruta_rio[_indice_ruta].global_position
	var dir := destino - balsa.global_position
	dir.y = 0.0
	
	if dir.length() < 3.0:
		_indice_ruta += 1
		return
	
	# TODO: Llamá a un método en tu balsa.gd (ej. balsa.aplicar_input_ia(dir.normalized()))
	# para reutilizar las físicas y arrastre de pasajeros que ya programaste en balsa.gd
	if balsa.has_method("aplicar_input_ia"):
		balsa.aplicar_input_ia(dir.normalized(), delta)

func _buscar_barril_cercano(rango: float) -> Node3D:
	var mas_cercano: Node3D = null
	var min_dist := rango
	for b in get_tree().get_nodes_in_group("Barriles"):
		if not is_instance_valid(b) or b.get("_destruido") == true:
			continue
		var d := bot.global_position.distance_to(b.global_position)
		if d < min_dist:
			min_dist = d
			mas_cercano = b
	return mas_cercano
