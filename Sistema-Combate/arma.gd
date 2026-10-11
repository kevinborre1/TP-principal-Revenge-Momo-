extends Node3D

@export var escena_bala: PackedScene = preload("res://Sistema-Combate/Bala.tscn")
@onready var punto_de_disparo: Marker3D = $PuntoDeDisparo

@export var cadencia: float = 0.2
var puede_disparar: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("disparar") and puede_disparar:
		disparar()

func disparar() -> void:
	if not escena_bala:
		return
		
	# Buscamos al jugador y a la cámara / raycast
	var player = get_tree().get_first_node_in_group("Jugador")
	if not player:
		return
		
	var raycast: RayCast3D = player.find_child("RayCastDisparo", true, false)
	
	# 1. Instanciamos la bala
	var bala = escena_bala.instantiate() as Area3D
	bala.global_position = punto_de_disparo.global_position
	
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
			
	# Le asignamos la dirección a la bala
	bala._direccion_salida(direccion_disparada)
	
	# Añadimos la bala a la escena principal
	get_tree().current_scene.add_child(bala)
	
	# 4. Cadencia
	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true
