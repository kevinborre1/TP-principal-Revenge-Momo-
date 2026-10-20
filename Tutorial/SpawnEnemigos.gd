extends Area3D

@export var enemigo_escena: PackedScene
@onready var contenedor_enemigos: Node3D = $".."
@onready var punto_1: Marker3D = $"../Spawn1"
@onready var punto_2: Marker3D = $"../Spawn2"

var enemigos_generados: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Solamente detectar jugadores
	if not body.is_in_group("Jugador"):
		return

	# Evitar generar enemigos varias veces
	if enemigos_generados:
		return

	# En multijugador solamente el host genera enemigos
	if Global.modo_multijugador == "linea":
		if not multiplayer.is_server():
			return
	enemigos_generados = true
	print("Jugador entró a la zona de combate")
	generar_enemigos()
	
func generar_enemigos() -> void:
	print("1. Entró a generar_enemigos()")
	print("2. enemigo_escena: ", enemigo_escena)
	print("3. contenedor_enemigos: ", contenedor_enemigos)
	print("4. punto_1: ", punto_1)
	print("5. punto_2: ", punto_2)

	crear_enemigo(punto_1)
	crear_enemigo(punto_2)

	print("6. Terminó de intentar generar enemigos")


func crear_enemigo(punto: Marker3D) -> void:
	print("7. Entró a crear_enemigo()")

	if enemigo_escena == null:
		print("ERROR: enemigo_escena es null")
		return

	if not is_instance_valid(punto):
		print("ERROR: el punto de aparición no es válido")
		return

	var papa = enemigo_escena.instantiate()
	print("8. Escena instanciada: ", papa)

	contenedor_enemigos.add_child(papa, true)
	papa.global_position = punto.global_position

	print("9. Enemigo agregado al árbol: ", papa.is_inside_tree())
	print("10. Posición del enemigo: ", papa.global_position)

	papa.perseguir_siempre = true
	papa.activar_enemigo.rpc()
