class_name EstadoBalsa
extends BotState

enum RolBalsa { ARTILLERO, PILOTO }

@export var rango_disparo_barriles: float = 25.0
@export var tiempo_maximo_abordaje: float = 2.2

var balsa: Node3D = null
var rol_balsa: RolBalsa = RolBalsa.ARTILLERO

var _abordado: bool = false
var _tiempo_intentando_subir: float = 0.0

func enter(datos: Dictionary = {}) -> void:
	balsa = datos.get("balsa", null)
	rol_balsa = datos.get("rol_balsa", RolBalsa.ARTILLERO)
	_abordado = false
	_tiempo_intentando_subir = 0.0
	
	if not is_instance_valid(balsa):
		state_machine.cambiar_estado("Seguir")

func exit() -> void:
	bot.equipar_arma(false)
	bot.salir_de_balsa()
	
	if is_instance_valid(balsa) and "pasajeros" in balsa:
		balsa.pasajeros.erase(bot)
	
	# Lo ubicamos junto al jugador en la orilla para que no caiga al agua al bajar
	var jugador: Node3D = bot.obtener_jugador_principal()
	if is_instance_valid(jugador):
		bot.global_position = jugador.global_position + Vector3(1.2, 0.2, 1.2)
	elif is_instance_valid(balsa):
		bot.global_position = balsa.global_position + balsa.transform.basis.x * 2.5
	
	balsa = null
	_abordado = false

func esta_abordado() -> bool:
	return _abordado

func physics_update(delta: float) -> void:
	if bot.muerto:
		return
	
	if not is_instance_valid(balsa) or balsa.get("is_controlled") != true:
		state_machine.cambiar_estado("Seguir")
		return
	
	# Fase 1: Acercarse desde el muelle y subirse a la cubierta
	if not _abordado:
		_tiempo_intentando_subir += delta
		var destino_asiento := _obtener_destino_asiento()
		var dist_horiz := Vector2(bot.global_position.x - destino_asiento.x, bot.global_position.z - destino_asiento.z).length()
		
		if dist_horiz <= 1.6 or _tiempo_intentando_subir >= tiempo_maximo_abordaje:
			_completar_abordaje(destino_asiento)
		else:
			bot.mover_hacia(destino_asiento, delta, true)
		return
	
	# Fase 2: Ya embarcado, la balsa lo arrastra vía _arrastrar_pasajeros() y Nico dispara parado
	bot.velocity = Vector3.ZERO
	_comportamiento_artillero(delta)

func _obtener_destino_asiento() -> Vector3:
	if balsa.has_method("obtener_asiento_companero"):
		return balsa.obtener_asiento_companero()
	return balsa.global_position + Vector3(0.75, 0.35, 0.35)

func _completar_abordaje(pos_asiento: Vector3) -> void:
	_abordado = true
	bot.velocity = Vector3.ZERO
	
	# Si ya subió caminando a la cubierta, conservamos su altura exacta sobre el piso de la balsa
	var zona := balsa.get_node_or_null("ZonaCubierta") as Area3D
	if is_instance_valid(zona) and zona.overlaps_body(bot):
		bot.global_position.x = pos_asiento.x
		bot.global_position.z = pos_asiento.z
	else:
		bot.global_position = pos_asiento
	
	if "pasajeros" in balsa and bot not in balsa.pasajeros:
		balsa.pasajeros.append(bot)
	
	if rol_balsa == RolBalsa.PILOTO:
		bot.prepare_for_raft()
	else:
		# Artillero va de pie sobre la cubierta apuntando con su arma, igual que un 2do jugador
		bot.salir_de_balsa()
		bot.equipar_arma(true)
		if bot.animation and bot.animation.has_animation("Pistol Idle/mixamo_com"):
			bot.animation.play("Pistol Idle/mixamo_com", 0.2)

func _comportamiento_artillero(delta: float) -> void:
	var barril := _buscar_barril_cercano(rango_disparo_barriles)
	if is_instance_valid(barril):
		bot.disparar_a(barril, delta, 0.5)
	else:
		bot.rotar_hacia(bot.global_position - balsa.transform.basis.z * 5.0, delta)

func _buscar_barril_cercano(rango: float) -> Node3D:
	var mas_cercano: Node3D = null
	var min_dist := rango
	
	var candidatos := get_tree().get_nodes_in_group("Barriles")
	if candidatos.is_empty():
		for nodo in get_tree().current_scene.find_children("*", "CollisionObject3D", true, false):
			if nodo.has_method("_colision_balsa"):
				candidatos.append(nodo)
	
	for b in candidatos:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if b.get("_destruido") == true or b.get("muriendo") == true:
			continue
		var d := bot.global_position.distance_to(b.global_position)
		if d < min_dist:
			min_dist = d
			mas_cercano = b
	
	return mas_cercano
