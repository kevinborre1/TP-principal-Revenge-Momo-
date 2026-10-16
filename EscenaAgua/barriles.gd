extends Node3D
func recibir_disparo():
	# Podés spawnear una explosión o partículas acá si querés antes de borrarlo.
	# Por ahora, simplemente desaparece:
	queue_free()
