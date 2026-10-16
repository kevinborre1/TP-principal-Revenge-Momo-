class_name SaveData
extends Resource

@export var tiene_checkpoint: bool = false
@export var pos_host: Vector3 = Vector3.ZERO
@export var pos_cliente: Vector3 = Vector3.ZERO
@export var escena_actual: String = ""
@export var cantidad_pepitas: int = 0
@export var logro_victor: bool = false

# Nuevo: Guardamos si el combate ya se activó y qué enemigos siguen vivos
@export var papas_atacan: bool = false
@export var ataque_iniciado: bool = false
@export var fase_oleada: int = 0 # 0 = sin iniciar, 1 = oleada 1, 2 = oleada 2, 3 = jefe, 4 = todos muertos
