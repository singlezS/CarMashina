extends "res://scripts/visual_carro.gd"

const MODELO := preload("res://glbs/celta.glb")
const RODAS := ["Roda_DE", "Roda_DD", "Roda_TE", "Roda_TD"]
var centros: Array[Vector3] = []
var raio: float

func _ready() -> void:
	var modelo := MODELO.instantiate() as Node3D
	add_child(modelo)
	for nome in RODAS:
		var roda := modelo.get_node(nome) as MeshInstance3D
		centros.append(roda.position)
		raio = roda.get_aabb().size.y * 0.5
		modelo.remove_child(roda)
		roda.position = Vector3.ZERO
		add_wheel(roda)
	var meio_z := (centros[0].z + centros[2].z) * 0.5
	modelo.position = Vector3(0.0, -centros[0].y - 0.26, -meio_z)

func centro_previa(indice: int) -> Vector3:
	var meio_z := (centros[0].z + centros[2].z) * 0.5
	return Vector3(centros[indice].x, -0.26, centros[indice].z - meio_z)

func configurar_chassi(carro) -> void:
	carro.wheelbase = centros[2].z - centros[0].z
	carro.track_width = centros[1].x - centros[0].x
	carro.radius = raio
	var chassi := carro.get_node("Chassi") as CollisionShape3D
	var cabine := carro.get_node("Cabine") as CollisionShape3D
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.48, 0.61, 3.77)
	chassi.shape = caixa
	chassi.position = Vector3(0, -0.035, -0.04)
	var teto := BoxShape3D.new()
	teto.size = Vector3(1.28, 0.43, 1.85)
	cabine.shape = teto
	cabine.position = Vector3(0, 0.59, 0.34)
