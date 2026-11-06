extends StaticBody3D
class_name PantallaColor

@export var tamanio: Vector2 = Vector2(2.4, 1.4)

var minijuego: Node = null # lo asigna MinijuegoColores
var indice: int = -1

var _forma: CollisionShape3D
var _material: StandardMaterial3D
var _texto: Label3D

func _ready() -> void:
	_forma = CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(tamanio.x, tamanio.y, 0.1)
	_forma.shape = caja
	add_child(_forma)

	var quad := QuadMesh.new()
	quad.size = tamanio
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fondo := MeshInstance3D.new()
	fondo.mesh = quad
	fondo.material_override = _material
	fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fondo)

	_texto = Label3D.new()
	_texto.position = Vector3(0, 0, 0.02)
	_texto.font_size = 96
	_texto.outline_size = 0
	add_child(_texto)

	apagar()

func mostrar(palabra: String, color_letra: Color, color_fondo: Color) -> void:
	_texto.text = palabra
	_texto.modulate = color_letra
	_material.albedo_color = color_fondo
	_forma.set_deferred("disabled", false)

func marcar(acierto: bool) -> void:
	_texto.text = "¡BIEN!" if acierto else "¡NO!"
	_texto.modulate = Color.WHITE
	_material.albedo_color = Color(0.1, 0.7, 0.2) if acierto else Color(0.8, 0.1, 0.1)

func apagar() -> void:
	_texto.text = ""
	_material.albedo_color = Color(0.05, 0.05, 0.05)
	_forma.set_deferred("disabled", true)

# La bala busca un nodo con _daniar y le llama recibir_bala: por eso existen las dos
func recibir_bala(_danio: int, _tipo: String) -> void:
	_daniar(0)

func _daniar(_danio: int) -> void:
	# Las balas existen en todos los peers: solo el host decide
	if Global.modo_multijugador == "linea" and not multiplayer.is_server():
		return
	if minijuego and indice >= 0:
		minijuego.pantalla_disparada(indice)
