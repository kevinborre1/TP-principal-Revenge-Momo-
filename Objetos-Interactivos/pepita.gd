extends Area3D

@onready var collision_shape = $CollisionShape3D 
var activada: bool = false

func _ready() -> void:
	add_to_group("PepitasMapa") # Permite que SaveAndLoad sepa si ya fue recogida
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true) 

func _process(delta: float) -> void:
	if not activada:
		# Contamos cuántas papitas comunes quedan
		var papitas_vivas = get_tree().get_nodes_in_group("papitas").size()
		# Contamos si el líder sigue vivo
		var lider_vivo = get_tree().get_nodes_in_group("lider").size()
		
		# Si ya no quedan ni papitas ni líder en el mapa...
		if papitas_vivas <= 0 and lider_vivo <= 0:
			aparecer()

func aparecer() -> void:
	activada = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	print("¡Todos los enemigos han muerto! La pepita de café apareció.")

# --- LÓGICA DE RED ---
func ser_recogido() -> void:
	if Global.modo_multijugador == "linea":
		rpc_id(1, "_procesar_pepita_host")
	else:
		_procesar_pepita_host()

@rpc("any_peer", "call_local", "reliable")
func _procesar_pepita_host() -> void:
	if multiplayer.is_server() or Global.modo_multijugador == "local":
		GameManager.register_event()
		if Global.modo_multijugador == "linea":
			rpc("_borrar_pepita_visual")
		else:
			_borrar_pepita_visual()

@rpc("call_local", "reliable")
func _borrar_pepita_visual() -> void:
	queue_free()
