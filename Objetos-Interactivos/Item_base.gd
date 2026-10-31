extends Area3D
class_name ItemBase

@export var nombre_item: String = "Pocion"
@export var icono: Texture2D
@export var ruta_escena: String

@export var activa_mira_combate: bool = false
@export var modifica_camara: bool = false
@export var distancia_camara: float = 2.0
@export var offset_camara: Vector3 = Vector3(0.0, 1.5, 0.0)

@export var posicion_en_mano: Vector3 = Vector3.ZERO
@export var rotacion_en_mano: Vector3 = Vector3.ZERO # en grados

# --- NUEVO ---
@export var texto_interaccion: String = "Presiona [E]"
var label_3d: Label3D = null # Guardamos la referencia para prenderlo/apagarlo rápido

func _ready() -> void:
	# 1. CREAR EL LABEL 3D POR CÓDIGO
	label_3d = Label3D.new()
	label_3d.text = texto_interaccion
	label_3d.visible = false
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Configuración visual para que se vea bien en el mundo
	label_3d.pixel_size = 0.005 # Tamaño del texto (ajustalo si lo ves muy grande o chico)
	label_3d.position.y = 0.8 # Lo levantamos 80cm para que quede flotando sobre el objeto
	label_3d.outline_modulate = Color.BLACK
	label_3d.outline_size = 4
	
	# Lo añadimos como hijo del objeto interactuable
	add_child(label_3d)

	# 2. Conectamos las señales
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
   #Agregamos al grupo ItemBaseMapa	
	add_to_group("ItemBaseMapa")
	
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

# --- EL RESTO DE TUS FUNCIONES QUEDAN IGUAL ---
func ser_recogido() -> void:
	if ruta_escena.is_empty():
		push_warning("El item que se quizo agarran no tiene ruta de escena")
	destruir_item_rpc.rpc()
	
func usar_item(jugador) -> bool:
	return false

@rpc("call_local", "any_peer", "reliable")
func destruir_item_rpc() -> void:
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()
	
func desactivar_para_mano() -> void:
	position = posicion_en_mano
	rotation_degrees = rotacion_en_mano
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	var colisiones = find_children("*", "CollisionShape3D")
	for c in colisiones:
		c.set_deferred("disabled", true)
	
	# Si lo agarramos en la mano, apagamos el cartelito definitivamente
	if label_3d:
		label_3d.queue_free()
		
	var sincronizador = get_node_or_null("MultiplayerSynchronizer")
	if sincronizador:
		sincronizador.queue_free()
