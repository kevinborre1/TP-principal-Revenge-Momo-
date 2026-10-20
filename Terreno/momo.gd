extends Node3D

signal vida_cambiada(vida: int, vida_max: int)
signal fase_cambiada(nueva_fase: int)
signal derrotado

enum Fase { UNO, DOS, TRES, MUERTO }

@export var vida_max: int = 100

@export_group("Ataques")
@export var zona_ataques: Area3D          # el Area3D con zona_jefe.gd (los ladrillazos)

@export_group("Papas")
@export var papa_escena: PackedScene
@export var contenedor_papas: Node3D      # el nodo que vigila el MultiplayerSpawner
@export var puntos_spawn: Array[Marker3D] = []
@export var max_papas: int = 8

@export_group("Campo de fuerza (fase 2)")
@export var campo_fuerza: Node3D          # lo visual: se ve mientras el campo está activo
@export var duracion_campo_caido: float = 8.0
# Valores de cada fase: editá los números a gusto
const CONFIG := {
	Fase.UNO:  {"ladrillazo": 2.0, "papas": false, "cada_papa": 0.0, "vel_papas": 0.0, "vel_onda": 3.0, "cada_onda": 8.0},
	Fase.DOS:  {"ladrillazo": 3.0, "papas": true,  "cada_papa": 5.0, "vel_papas": 4.0, "vel_onda": 3.0, "cada_onda": 10.0},
	Fase.TRES: {"ladrillazo": 1.5, "papas": true,  "cada_papa": 3.0, "vel_papas": 6.0, "vel_onda": 6.0, "cada_onda": 5.0},
}

var vida: int = 0
var fase: int = Fase.UNO
var campo_activo := false

var _timer_papas: Timer
var _timer_campo: Timer
var _botones := {1: false, 2: false}
var _pausa_papas_hasta_ms := 0

@export_group("Onda expansiva")
@export var punto_onda: Marker3D   # un Marker3D en el piso, debajo de Momo
@export var dano_onda: int = 15
@export var radio_max_onda: float = 100.0

var _timer_onda: Timer

func _ready() -> void:
	vida = vida_max
	_mostrar_campo(false)
	if not _soy_host():
		return  # solo el host maneja la lógica del jefe
	
	_timer_papas = Timer.new()
	_timer_papas.timeout.connect(_spawnear_papa)
	add_child(_timer_papas)
	
	_timer_campo = Timer.new()
	_timer_campo.one_shot = true
	_timer_campo.timeout.connect(_subir_campo)
	add_child(_timer_campo)
	
	_timer_onda = Timer.new()
	_timer_onda.timeout.connect(_lanzar_onda)
	add_child(_timer_onda)
	
	_aplicar_config(Fase.UNO)


func _soy_host() -> bool:
	return Global.modo_multijugador != "linea" or multiplayer.is_server()
# --- VIDA ---

# Lo llaman las balas o armas cuando le pegan a Momo
func _daniar(cantidad: int) -> void:
	print("Momo recibió daño: ", cantidad, " | vida: ", vida, " | campo: ", campo_activo)
	if not _soy_host() or fase == Fase.MUERTO or campo_activo:
		return
	
	vida = maxi(vida - cantidad, 0)
	var nueva_fase := _fase_segun_vida(vida)
	if nueva_fase != fase:
		_cambiar_fase(nueva_fase)
	else:
		_sincronizar.rpc(vida, fase, campo_activo)


func _fase_segun_vida(v: int) -> int:
	if v <= 0:
		return Fase.MUERTO
	var porcentaje := float(v) / float(vida_max)
	if porcentaje > 0.8:
		return Fase.UNO
	elif porcentaje > 0.3:
		return Fase.DOS
	return Fase.TRES


# --- FASES ---
func _cambiar_fase(nueva: int) -> void:
	_aplicar_config(nueva)
	_sincronizar.rpc(vida, nueva, false)
	if nueva == Fase.DOS:
		_subir_campo()
	
func _aplicar_config(f: int) -> void:
	_timer_campo.stop()
	_botones = {1: false, 2: false}
	
	if f == Fase.MUERTO:
		_timer_onda.stop()          # acá se frena, no se arranca
		_timer_papas.stop()
		for p in get_tree().get_nodes_in_group("PapaMomo"):
			p.queue_free()
		if zona_ataques:
			zona_ataques.detener()
			return
	var cfg: Dictionary = CONFIG[f]
	_timer_onda.start(cfg["cada_onda"])   # acá se arranca, ya con cfg declarada
	if zona_ataques:
		zona_ataques.set_intervalo(cfg["ladrillazo"])
	if cfg["papas"]:
		_timer_papas.start(cfg["cada_papa"])
	else:
		_timer_papas.stop()


# Se ejecuta en todas las PC: acá se actualiza el estado y lo visual
@rpc("authority", "call_local", "reliable")
func _sincronizar(vida_nueva: int, fase_nueva: int, campo: bool) -> void:
	var fase_anterior := fase
	vida = vida_nueva
	fase = fase_nueva
	campo_activo = campo
	_mostrar_campo(campo)
	
	vida_cambiada.emit(vida, vida_max)
	if fase != fase_anterior:
		fase_cambiada.emit(fase)
		if fase == Fase.MUERTO:
			derrotado.emit()


func _mostrar_campo(activo: bool) -> void:
	if campo_fuerza == null:
		return
	campo_fuerza.visible = activo
	
	if campo_fuerza is CollisionShape3D:
		campo_fuerza.set_deferred("disabled", not activo)
	for c in campo_fuerza.find_children("*", "CollisionShape3D", true, false):
		c.set_deferred("disabled", not activo)

# --- CAMPO DE FUERZA Y BOTONES ---

# Es la misma función que llaman tus botones de la puerta: apuntalos a Momo
func actualizar_estado_boton(id_boton: int, activado: bool) -> void:
	if not _soy_host() or fase != Fase.DOS or not campo_activo:
		return
	_botones[id_boton] = activado
	if _botones[1] and _botones[2]:
		_bajar_campo()
		_mostrar_campo(false)


func _bajar_campo() -> void:
	_botones = {1: false, 2: false}
	# Mientras el campo está caído, tampoco aparecen papas
	_pausa_papas_hasta_ms = Time.get_ticks_msec() + int(duracion_campo_caido * 1000.0)
	_timer_campo.start(duracion_campo_caido)
	_sincronizar.rpc(vida, fase, false)


func _subir_campo() -> void:
	if fase != Fase.DOS:
		return
	_sacar_jugadores_del_campo()
	await get_tree().create_timer(0.3).timeout  # tiempo para que se muevan
	if fase == Fase.DOS:
		_sincronizar.rpc(vida, fase, true)

func _forma_del_campo() -> CollisionShape3D:
	if campo_fuerza is CollisionShape3D:
		return campo_fuerza
	var formas := campo_fuerza.find_children("*", "CollisionShape3D", true, false)
	if formas.is_empty():
		return null
	return formas[0] as CollisionShape3D

func _sacar_jugadores_del_campo() -> void:
	print("Revisando jugadores dentro del campo...")
	if campo_fuerza == null:
		print("  -> Campo Fuerza no está asignado en el Inspector de Momo")
		return
	var forma := _forma_del_campo()
	if forma == null or forma.shape == null:
		print("  -> el campo no tiene una CollisionShape3D con forma")
		return
	
	# Caja que rodea al campo, en coordenadas globales
	var caja: AABB = forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	print("  -> caja del campo: ", caja)
	
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		var p: Vector3 = jugador.global_position
		var adentro := (
			p.x > caja.position.x and p.x < caja.end.x
			and p.z > caja.position.z and p.z < caja.end.z
			and p.y > caja.position.y - 1.0 and p.y < caja.end.y
		)
		print("  -> ", jugador.name, " en ", p, " | adentro: ", adentro)
		if not adentro:
			continue
		
		# Desplazar al jugador únicamente hacia Z positiva
		var destino: Vector3 = p
		destino.z = caja.end.z + 1.5
		print("Sacando a ", jugador.name, " hacia ", destino)
		if Global.modo_multijugador == "linea":
			jugador.mover_a.rpc_id(jugador.get_multiplayer_authority(), destino)
		else:
			jugador.global_position = destino
# --- PAPAS ---

func _spawnear_papa() -> void:
	if not _soy_host() or fase == Fase.MUERTO:
		return
	if papa_escena == null or puntos_spawn.is_empty():
		return
	if Time.get_ticks_msec() < _pausa_papas_hasta_ms:
		return
	if get_tree().get_nodes_in_group("PapaMomo").size() >= max_papas:
		return
	
	var punto: Marker3D = puntos_spawn.pick_random()
	if punto == null:
		return
	
	var raiz := get_tree().current_scene
	var papa = papa_escena.instantiate()
	papa.add_to_group("PapaMomo")
	papa.velocidad = CONFIG[fase]["vel_papas"]
	papa.perseguir_siempre = true
	papa.position = raiz.to_local(punto.global_position)
	raiz.add_child(papa, true)
	
	# Se espera un momento a que el cliente tenga su copia y recién ahí se la despierta
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(papa):
		papa.activar_enemigo.rpc()

# --- PARA LA ONDA EXPANSIVA (la armamos después) ---
func _lanzar_onda() -> void:
	if not _soy_host() or fase == Fase.MUERTO:
		return
	var centro := punto_onda.global_position if punto_onda else global_position
	_crear_onda.rpc(centro, CONFIG[fase]["vel_onda"])


@rpc("authority", "call_local", "reliable")
func _crear_onda(centro: Vector3, vel: float) -> void:
	var onda := OndaExpansiva.new()
	onda.velocidad = vel
	onda.dano = dano_onda
	onda.radio_max = radio_max_onda
	get_tree().current_scene.add_child(onda)
	onda.global_position = centro

func velocidad_onda() -> float:
	if fase == Fase.MUERTO:
		return 0.0
	return CONFIG[fase]["vel_onda"]
