extends Area3D

@onready var collision_shape = $CollisionShape3D # Asegúrate de que tu nodo de colisión se llame así
var activada: bool = false

func _ready() -> void:
	# Al iniciar el juego, la ocultamos y desactivamos para que no se pueda agarrar
	visible = false
	if collision_shape:
		# set_deferred es la forma más segura en Godot de desactivar colisiones al cargar
		collision_shape.set_deferred("disabled", true) 

func _process(delta: float) -> void:
	# Si la pepita aún no está activada, revisamos constantemente
	if not activada:
		var papitas_vivas = get_tree().get_nodes_in_group("papitas").size()
		
		# Si ya no quedan papitas en el mapa...
		if papitas_vivas <= 0:
			aparecer()

func aparecer() -> void:
	activada = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	print("¡Todas las papitas han sido eliminadas! La pepita de café apareció.")

# --- AQUÍ EMPIEZA LA LÓGICA DE RED QUE HICIMOS ANTES ---

func ser_recogido() -> void:
	if Global.modo_multijugador == "linea":
		# Le pide al Host (ID 1) que procese el punto
		rpc_id(1, "_procesar_pepita_host")
	else:
		_procesar_pepita_host()

# Esta función la recibe cualquiera, pero el "if" asegura que solo el Host trabaje
@rpc("any_peer", "call_local", "reliable")
func _procesar_pepita_host() -> void:
	if multiplayer.is_server() or Global.modo_multijugador == "local":
		# 1. El Host suma el punto oficial
		GameManager.register_event()
		
		# 2. El Host le ordena a TODAS las computadoras que borren esta pepita visualmente
		if Global.modo_multijugador == "linea":
			rpc("_borrar_pepita_visual")
		else:
			_borrar_pepita_visual()

# Esta orden viaja por internet para borrarla de todas las pantallas
@rpc("call_local", "reliable")
func _borrar_pepita_visual() -> void:
	queue_free()
