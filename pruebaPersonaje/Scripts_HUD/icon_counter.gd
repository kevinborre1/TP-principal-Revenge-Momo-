extends Control
class_name IconCounter

@export var icons: Array[TextureRect] = []

var texture_empty: Texture2D
var texture_filled: Texture2D
var current_count: int = 0
var fill_direction: int = 1  # 1 = se va llenando, -1 = se va "rompiendo"




signal counter_completed  # último grano recolectado / última vida perdida

func setup(empty_tex: Texture2D, filled_tex: Texture2D, start_count: int = 0) -> void:
	texture_empty = empty_tex
	texture_filled = filled_tex
	current_count = start_count
	_refresh()

func increment() -> void:
	current_count = min(current_count + 1, icons.size())
	_refresh()
	if current_count >= icons.size():
		counter_completed.emit()

func _refresh() -> void:
	for i in icons.size():
		icons[i].texture = texture_filled if i < current_count else texture_empty
