extends Control

@onready var icon_counter: IconCounter = $icon_counter

var cafe_textures = {
	"empty": preload("res://assets/granocafe0.png"),
	"filled": preload("res://assets/granocafe1.png")
}
var balsa_textures = {
	"empty": preload("res://assets/balsa0.png"),
	"filled": preload("res://assets/balsa1.png")
}

func _ready():
	print("HUD ready")
	GameManager.mode_changed.connect(_on_mode_changed)
	GameManager.count_changed.connect(_on_count_changed)
	_on_mode_changed(GameManager.current_mode, GameManager.max_count)

func _on_mode_changed(mode: GameManager.GameMode, max_count: int) -> void:
	var textures = cafe_textures if mode == GameManager.GameMode.RECOLECCION else balsa_textures
	icon_counter.setup(textures.empty, textures.filled)

func _on_count_changed(count: int) -> void:
	icon_counter.current_count = count
	icon_counter._refresh()
