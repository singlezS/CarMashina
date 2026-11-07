extends "res://scripts/visual_carro.gd"

const MODEL = preload("res://glbs/Saveirosummer.glb")
# Comprimento do Del Rey dividido pelo comprimento da carroceria Summer, em metros.
const MODEL_SCALE := 4.554902 / 4.952682
const BODY_ORIGIN := Vector3(0.123626, 0.699, -0.115)
# Dianteira esquerda/direita, traseira esquerda/direita, na ordem da suspensão.
const WHEELS := ["roda 2", "roda 1", "roda 3", "roda 4"]

func _ready() -> void:
	var body := MODEL.instantiate() as Node3D
	add_child(body)
	body.scale = Vector3.ONE * MODEL_SCALE
	body.position = -BODY_ORIGIN * MODEL_SCALE
	var tires: Array[MeshInstance3D] = []
	var bounds: Array[AABB] = []
	for wheel_name in WHEELS:
		var tire := body.get_node(wheel_name) as MeshInstance3D
		tires.append(tire)
		bounds.append(body.transform * tire.transform * tire.get_aabb())

	for i in range(4):
		var tire := tires[i]
		var center := bounds[i].get_center()
		var wheel_transform := body.transform * tire.transform
		body.remove_child(tire)
		wheel_transform.origin -= center
		tire.transform = wheel_transform
		# Centraliza cada par na mesma bitola e no mesmo eixo do próprio GLB.
		var opposite := bounds[i ^ 1].get_center()
		var half_track := absf(center.x - opposite.x) * 0.5
		var axle_z := (center.z + opposite.z) * 0.5
		var radius := bounds[i].size.y * 0.5
		var offset := Vector3(
			(-1.0 if i % 2 == 0 else 1.0) * (half_track - 0.57),
			radius - 0.311,
			axle_z - (-1.294 if i < 2 else 1.294))
		add_wheel(tire, offset, 0.311 / radius)
