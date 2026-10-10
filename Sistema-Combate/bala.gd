extends Area3D

@export var velocidad: float = 40.0
var direccion: Vector3 = Vector3.FORWARD

func _physics_process(delta: float) -> void:
	# Mueve la bala en su dirección local o global
	position += direccion * velocidad * delta

func _on_body_entered(body: Node3D) -> void:
	# Si choca con un enemigo, le hacemos daño (si tiene el método)
	if body.has_method("recibir_daño"):
		body.recibir_daño(10)
	
	# Destruye la bala al impactar
	queue_free()
