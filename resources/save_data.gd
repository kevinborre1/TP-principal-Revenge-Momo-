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
@export var estado_enemigos_guardado: bool = false
@export var enemigos_vivos: Array[String] = []
