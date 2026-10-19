extends BoxContainer
class_name InventarioManager

var items = [null, null, null, null, null] # 5 espacios
var slot_seleccionado: int = 0

@onready var slots_ui = get_children()

func _ready() -> void:
	actualizar_ui_seleccion()

# 1. ACTUALIZADO: Ahora recibe al 'player' para poder decirle que equipe o desequipe el arma
func seleccionar_slot(indice: int, player: Node3D) -> void:
	if indice >= 0 and indice < items.size():
		slot_seleccionado = indice
		actualizar_ui_seleccion()
		print("Slot activo: ", slot_seleccionado + 1)
		
		# --- NUEVA LÓGICA DE EQUIPAMIENTO ---
		var item_data = items[slot_seleccionado]
		
		# Si el slot tiene un objeto Y además está marcado como equipable
		if item_data != null :
			player.solicitar_equipar(item_data["ruta_escena"])
		else:
			# Si el slot está vacío, o es un consumible (cerveza), quitamos lo que haya en la mano
			player.solicitar_desequipar()

# 2. ACTUALIZADO: Se agrega 'es_equipable' con un valor por defecto en falso
func agregar_item(nombre_item: String, textura_icono: Texture2D, ruta: String, es_equipable: bool = false) -> bool:
	for i in range(items.size()):
		if items[i] == null:
			items[i] = {
				"nombre": nombre_item,
				"ruta_escena": ruta,
				"es_equipable": es_equipable # Guardamos si es un arma o no
			}
			var icono_visual = slots_ui[i].get_node("icono")
			if icono_visual:
				icono_visual.texture = textura_icono
			return true
			
	print("El inventario está lleno")
	return false

# Devuelve la información del ítem que está actualmente seleccionado
func obtener_item_actual():
	return items[slot_seleccionado]

# Borra el ítem del slot seleccionado (al usarlo o soltarlo)
func borrar_item_actual() -> void:
	items[slot_seleccionado] = null
	var icono_visual = slots_ui[slot_seleccionado].get_node("icono")
	if icono_visual:
		icono_visual.texture = null

# Resalta visualmente el slot que el jugador tiene seleccionado
func actualizar_ui_seleccion() -> void:
	for i in range(slots_ui.size()):
		if i == slot_seleccionado:
			slots_ui[i].modulate = Color(1, 1, 1, 1) # Color normal (seleccionado)
		else:
			slots_ui[i].modulate = Color(0.5, 0.5, 0.5, 1) # Oscurecido (inactivo)
