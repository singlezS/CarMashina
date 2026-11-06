extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var world: Node3D = load("res://cenas/world.tscn").instantiate()
	root.add_child(world)
	for i in range(180):
		await physics_frame
	world.set_process(false)
	world.camera.position = world.car.position + Vector3(0, 0.9, -5)
	world.camera.look_at(world.car.position + Vector3.UP * 0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rodas-frente.png")
	world.camera.position = world.car.position + Vector3(4, 1.7, -5)
	world.camera.look_at(world.car.position + Vector3.UP * 0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/delrey-arcade.png")
	quit()
