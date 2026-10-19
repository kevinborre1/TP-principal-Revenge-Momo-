extends ItemBase 
class_name Arma

@export var escena_bala: PackedScene = preload("res://Objetos-Interactivos/Sistema-Combate/Bala.tscn")
@onready var punto_de_disparo: Marker3D = $PuntoDeDisparo

@export var cadencia: float = 0.2
var puede_disparar: bool = true

func ser_recogido() -> void:
	desactivar_para_mano()
	queue_free()

func _jugador_dueño() -> Player:
	var nodo: Node = self
	while nodo and not (nodo is Player):
		nodo = nodo.get_parent()
	return nodo as Player

func _unhandled_input(event: InputEvent) -> void:
	var jugador := _jugador_dueño()
	if jugador == null or jugador.input_bloqueado:
		return
	# evita que un jugador dispare el arma de otro
	if not jugador.is_multiplayer_authority():
		return
	if event.is_action_pressed("disparar") and puede_disparar:
		disparar()

func disparar() -> void:
	if not escena_bala:
		return
	puede_disparar = false 
		
	# Buscamos al jugador y a la cámara / raycast
	var player = _jugador_dueño() #get_tree().get_first_node_in_group("Jugador")
	if not player:
		puede_disparar = true
		return
		
	var raycast: RayCast3D = player.find_child("RayCastDisparo", true, false)
	
	# 1. Instanciamos la bala
	#var bala = escena_bala.instantiate() as Area3D
	#bala.global_position = punto_de_disparo.global_position
	
	var direccion_disparada = Vector3.FORWARD
	
	if raycast and raycast.is_colliding():
		# Si el rayo de la cámara choca con algo en pantalla, la bala va directo a ese punto 3D
		var punto_impacto = raycast.get_collision_point()
		direccion_disparada = (punto_impacto - punto_de_disparo.global_position).normalized()
	else:
		# Si no choca con nada, sale disparada exactamente hacia donde mira la cámara
		var camara: Camera3D = player.find_child("Camera3D", true, false)
		if camara:
			direccion_disparada = -camara.global_transform.basis.z.normalized()
		else:
			direccion_disparada = -global_transform.basis.z.normalized()
			
	generar_bala.rpc(punto_de_disparo.global_position, direccion_disparada)
	
	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true

@rpc("call_local", "any_peer", "reliable")
func generar_bala(posicion_inicial: Vector3, direccion: Vector3) -> void:
	var bala = escena_bala.instantiate() as Area3D
	
	get_tree().current_scene.add_child(bala)
	
	bala.global_position = posicion_inicial
	bala._direccion_salida(direccion)
	
func desactivar_para_mano() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	# Si tienes un CollisionShape3D hijo, también lo apagamos por seguridad
	var colision = get_node_or_null("CollisionShape3D")
	if colision:
		colision.set_deferred("disabled", true)	
