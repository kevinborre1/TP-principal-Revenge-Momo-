extends Area3D
class_name BotonPuerta # (OOP) Buena práctica: dar nombre a la clase para identificarla en el proyecto

@export var id_boton: int = 1
@export var puerta_destino: Node # Asigná la puerta desde el Inspector

var jugador_cerca: bool = false
var esta_activado: bool = false

# Guardamos la referencia a la malla para no tener que buscarla repetidas veces
@onready var malla_boton: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("BotonesPuerta")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	

func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and event.is_action_pressed("interactuar"):
		presionar_boton()

func presionar_boton() -> void:
	esta_activado = !esta_activado
	
	if puerta_destino and puerta_destino.has_method("actualizar_estado_boton"):
		puerta_destino.actualizar_estado_boton(id_boton, esta_activado)
		
	# Delegamos el cambio visual a otra función
	_actualizar_visual_boton()

## (SOLID - Responsabilidad Única): El botón es el único responsable de saber 
## cómo desactivarse a sí mismo y actualizar sus propios gráficos.
func desactivar_externamente() -> void:
	if esta_activado: # Solo actuamos si realmente estaba activado
		esta_activado = false
		_actualizar_visual_boton()
		
## (SOLID - Responsabilidad Única): Esta función se encarga EXCLUSIVAMENTE 
## de manejar cómo se ve el botón, separándola de la lógica de las puertas.
func _actualizar_visual_boton() -> void:
	if malla_boton != null:
		malla_boton.visible = esta_activado
	else:
		push_warning("BotonPuerta: No se encontró el MeshInstance3D para hacer visible.")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		jugador_cerca = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Jugador"):
		jugador_cerca = false
