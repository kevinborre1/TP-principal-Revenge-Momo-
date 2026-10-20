extends Area3D

enum Modo { UNO_AL_AZAR, AMBOS }

@export var modo: Modo = Modo.UNO_AL_AZAR
@export var intervalo: float = 4.0       # segundos entre ataques
@export var retraso_caida: float = 2.0   # segundos que tarda en caer
@export var radio: float = 4.0
@export var dano: int = 30

@export var ataque_ladrillo_escena: PackedScene

var _detenida := false
var jugadores_en_zona: Array = []
var _timer: Timer


func _ready() -> void:
	# Solo el host decide cuándo y dónde cae cada ataque
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_timer = Timer.new()
	_timer.wait_time = intervalo
	_timer.timeout.connect(_atacar)
	add_child(_timer)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Jugador") or body in jugadores_en_zona:
		return
	jugadores_en_zona.append(body)
	if _timer.is_stopped() and not _detenida:
		_timer.start()


func _on_body_exited(body: Node3D) -> void:
	jugadores_en_zona.erase(body)
	if jugadores_en_zona.is_empty():
		_timer.stop()


func _atacar() -> void:
	jugadores_en_zona = jugadores_en_zona.filter(func(j): return is_instance_valid(j))
	if jugadores_en_zona.is_empty():
		return
	
	var objetivos: Array = []
	if modo == Modo.AMBOS:
		objetivos = jugadores_en_zona.duplicate()
	else:
		objetivos = [jugadores_en_zona.pick_random()]
	
	for jugador in objetivos:
		lanzar_ataque.rpc(_punto_en_suelo(jugador))


# Baja desde el jugador hasta el piso, así la marca no queda flotando si está saltando
func _punto_en_suelo(jugador: Node3D) -> Vector3:
	var origen: Vector3 = jugador.global_position
	var consulta := PhysicsRayQueryParameters3D.create(origen + Vector3.UP, origen + Vector3.DOWN * 50.0)
	consulta.exclude = [jugador.get_rid()]
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado:
		return resultado.position
	return origen

func set_intervalo(nuevo: float) -> void:
	intervalo = nuevo
	if _timer:
		_timer.wait_time = nuevo

func detener() -> void:
	_detenida = true
	if _timer:
		_timer.stop()




@rpc("authority", "call_local", "reliable")
func lanzar_ataque(pos: Vector3) -> void:
	if ataque_ladrillo_escena == null:
		return
	var ataque = ataque_ladrillo_escena.instantiate()
	ataque.radio = radio
	ataque.dano = dano
	ataque.retraso = retraso_caida
	get_tree().current_scene.add_child(ataque)
	ataque.global_position = pos
