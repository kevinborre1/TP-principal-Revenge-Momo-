extends Area3D

@onready var collision_shape = $CollisionShape3D 
var activada: bool = false
var texto_interaccion: String = "Presiona [E]"
var label_3d: Label3D = null

func _ready() -> void:
	add_to_group("PepitasMapa") 
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true) 
		
	# --- NUEVO: Crear Label3D por código ---
	label_3d = Label3D.new()
	label_3d.text = texto_interaccion
	label_3d.visible = false
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.pixel_size = 0.015
	label_3d.position.y = 1.8# Flota arriba de la pepita
	label_3d.outline_modulate = Color.BLACK
	label_3d.outline_size = 4
	
	add_child(label_3d)
		
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

# --- NUEVO: Detección ---
func _on_area_entered(area: Area3D) -> void:
	if area.name == "DetectorItems":
		var jugador = area.get_parent()
		if jugador is Player and jugador.is_multiplayer_authority():
			if label_3d:
				label_3d.visible = true

func _on_area_exited(area: Area3D) -> void:
	if area.name == "DetectorItems":
		var jugador = area.get_parent()
		if jugador is Player and jugador.is_multiplayer_authority():
			if label_3d:
				label_3d.visible = false

# --- EL RESTO DE TU CÓDIGO QUEDA IGUAL ---
func _process(delta: float) -> void:
	if not activada:
		var papitas_vivas = get_tree().get_nodes_in_group("papitas").size()
		var lider_vivo = get_tree().get_nodes_in_group("lider").size()
		
		if papitas_vivas <= 0 and lider_vivo <= 0:
			aparecer()

func aparecer() -> void:
	activada = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	print("¡Todos los enemigos han muerto! La pepita de café apareció.")

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
