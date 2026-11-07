extends Node3D
@onready var car: RigidBody3D = $Carro
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD
var camera_heading := Vector3.BACK

func _ready() -> void:
	hud.mostrar_modelo(car.modelo.get_state().get_node_name(0))
	for marcador in get_tree().get_nodes_in_group("marcadores_missao"):
		if is_ancestor_of(marcador):
			marcador.body_entered.connect(_ao_entrar_no_marcador)
	camera.position = car.position + Vector3(6, 3, 7)
	camera.look_at(car.position + Vector3.UP * 0.3)

func _process(delta: float) -> void:
	var back := car.global_basis.z
	back.y = 0
	if back.length_squared() > 0.01:
		camera_heading = camera_heading.lerp(back.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	var focus := car.global_position + Vector3.UP * 0.6
	var desired := focus + camera_heading * 7 + Vector3.UP * 2.6
	# Pull the camera in before geometry can obscure the car.
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1, [car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.25
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	camera.look_at(focus)
	hud.mostrar_velocidade(car.speed_kmh)

func _ao_entrar_no_marcador(corpo: Node3D) -> void:
	if corpo == car:
		hud.registrar_passagem()
