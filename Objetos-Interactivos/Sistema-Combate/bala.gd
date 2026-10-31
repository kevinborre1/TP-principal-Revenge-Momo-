extends Area3D

const TIEMPO_VIDA: float = 0.4
const VELOCIDAD_BALA: float = 70.0
const DANIO_BALA: int = 10

var tiempo: float = 0.0
var golpeo_algo: bool = false
var direccion: Vector3 = Vector3.FORWARD

var tipo: String = "ambos"

func _ready() -> void:
	body_entered.connect(_al_colisionar)
	area_entered.connect(_al_tocar_area)

func _physics_process(delta: float) -> void:
	global_position += direccion * VELOCIDAD_BALA * delta
	
	tiempo += delta
	if tiempo >= TIEMPO_VIDA:
		queue_free()

func _al_colisionar(body: Node3D) -> void:
	if golpeo_algo or _es_jugador(body):
		return  # atraviesa a los jugadores
	var objetivo := _buscar_objetivo(body)
	if objetivo:
		_aplicar_dano(objetivo)
	golpeo_algo = true
	queue_free()  # se destruye al chocar con cualquier cosa sólida

# Para enemigos que usan un Area3D en vez de un cuerpo
func _al_tocar_area(area: Area3D) -> void:
	if golpeo_algo or _es_jugador(area):
		return
	
	var objetivo := _buscar_objetivo(area)
	if objetivo == null:
		return  # una zona o un ítem cualquiera: la bala sigue de largo
	
	_aplicar_dano(objetivo)
	golpeo_algo = true
	queue_free()

func _aplicar_dano(objetivo: Node) -> void:
	if objetivo.has_method("recibir_bala"):
		objetivo.recibir_bala(DANIO_BALA, tipo)
	elif objetivo.has_method("_daniar"):
		objetivo._daniar(DANIO_BALA)
	else:
		objetivo.recibir_dano(DANIO_BALA)

# Sube por los padres hasta encontrar quien sabe recibir daño
func _buscar_objetivo(nodo: Node) -> Node:
	var actual := nodo
	while actual != null:
		if actual.has_method("_daniar"):
			return actual
		actual = actual.get_parent()
	return null

# Los jugadores (y sus detectores, que son hijos) no frenan la bala
func _es_jugador(nodo: Node) -> bool:
	var actual := nodo
	while actual != null:
		if actual.is_in_group("Jugador"):
			return true
		actual = actual.get_parent()
	return false

func _direccion_salida(dir: Vector3) -> void:
	direccion = dir
	
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)

# Pinta la bala según el rol de quien disparó
func set_tipo(nuevo_tipo: String) -> void:
	tipo = nuevo_tipo
	var color: Color
	if tipo == "rompe_escudo":
		color = Color(0.3, 0.7, 1.0) # azul
	elif tipo == "letal":
		color = Color(1.0, 0.25, 0.2) # rojo
	else:
		return # "ambos": queda con su color original
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in find_children("*", "MeshInstance3D", true, false):
		m.material_override = mat
