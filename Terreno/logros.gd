extends CanvasLayer

# nombre del papelito en la escena -> nombre exacto del logro en Logros.gd
const PAPELITOS := {
	"Rompiste15Barriles": "Rompiste15Barriles",
	"Mataste10Enemigos": "AsesinasteA10Enemigos",
	"Muere10Veces": "Moriste10Veces",
	"CompletasteCampus": "Completo_Campus",
	"CompletasteVictors": "Completo_Victor",
	"CompletasteModulo7": "Completo_Modulo7",
	"JugasteElMinijuego": "JugasteElMinijuego",
	"EsterEgg1": "EsterEgg1",
	"EsterEgg2": "EsterEgg2",
	"EsterEgg3": "EsterEgg3",
}

func _ready() -> void:
	hide()
	visibility_changed.connect(_actualizar)
func _actualizar() -> void:
	if not visible:
		return
	if SaveAndLoad.logros == null:
		SaveAndLoad.cargar_logros()
	
	for papelito in PAPELITOS:
		var nodo := get_node_or_null(papelito)
		if nodo == null:
			continue
		
		var logro: String = PAPELITOS[papelito]
		var valor = SaveAndLoad.logros.get(logro)
		if valor == null:
			push_warning("No existe el logro: " + logro)
			continue
		
		# Si está completado, se saca el papelito y se ve el logro
		nodo.visible = not valor


func _on_button_pressed() -> void:
	hide()
