extends Node3D

# Cargamos la escena de la bala que creaste antes
@export var escena_bala: PackedScene = preload("res://Sistema-Combate/Bala.tscn") # Ajusta la ruta si la guardaste en otro lado
@onready var punto_de_disparo: Marker3D = $PuntoDeDisparo

@export var cadencia: float = 0.2
var puede_disparar: bool = true

func _unhandled_input(event: InputEvent) -> void:
	# Detecta el clic izquierdo del ratón o la acción de disparar
	if event.is_action_pressed("disparar") and puede_disparar:
		print("disparo")
		disparar()

func disparar() -> void:
	if not escena_bala:
		print("¡Falta asignar la escena de la bala en el inspector!")
		return
		
	puede_disparar = false
	
	# 1. Instanciamos la bala
	var bala = escena_bala.instantiate() as Area3D
	
	# 2. La posicionamos en el Marker3D de la punta del arma
	bala.global_position = punto_de_disparo.global_position
	
	# 3. Le damos la dirección hacia donde apunta el arma localmente (-Z)
	var direccion_disparada = global_transform.basis.z.normalized()
	bala.direccion = direccion_disparada
	
	# 4. Añadimos la bala a la raíz principal del nivel (para que viaje libremente)
	get_tree().current_scene.add_child(bala)
	
	# 5. Esperamos el tiempo de la cadencia antes de poder disparar de nuevo
	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true
