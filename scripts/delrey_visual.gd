extends "res://scripts/visual_carro.gd"
## Preserve the Blender meshes/materials; correct pivots without editing the GLB.
const MODEL = preload("res://glbs/delreycompleto.glb")

func _ready() -> void:
	var source := MODEL.instantiate()
	var alignment := Basis(Vector3.UP, -PI / 2.0)
	var origin := Vector3(1.329, 0.414, -0.539)
	var body := source.get_node("Vert") as MeshInstance3D
	# Blender's origin was off-center laterally. Align the body to the axle midpoint.
	origin.z = body.get_aabb().get_center().z
	var skin := MeshInstance3D.new()
	skin.mesh = body.mesh
	for surface in range(skin.mesh.get_surface_count()):
		var material := skin.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
		if material != null:
			material.roughness = 0.42
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			skin.set_surface_override_material(surface, material)
	skin.transform = Transform3D(alignment, -(alignment * origin))
	add_child(skin)
	# FL, FR, RL, RR: original mesh centers are baked into the vertices.
	for mesh_name in ["pneu 1", "pneu 2", "pneu 3", "pneu 4"]:
		var original := source.get_node(mesh_name) as MeshInstance3D
		var tire := MeshInstance3D.new()
		tire.mesh = original.mesh
		tire.transform = Transform3D(alignment, -(alignment * original.get_aabb().get_center()))
		add_wheel(tire)
	source.free()
