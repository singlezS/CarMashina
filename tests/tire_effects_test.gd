extends SceneTree
var failed := 0
var world: Node3D
var car: RigidBody3D
var fx: Node3D
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func run() -> void:
	world = load("res://cenas/world.tscn").instantiate()
	root.add_child(world)
	car = world.car
	car.input_enabled = false
	car.spawn_transform.origin = Vector3(65, 1.2, 70)
	car.reset_car()
	fx = car.get_node("EfeitosPneus")
	await frames(360)
	check(fx.active_segments == 0 and not fx.smoke[0].emitting, "Sem efeitos parado")
	car.throttle = 1
	await frames(360)
	check(fx.total_segments_created == 0, "Sem marcas acelerando em linha reta")
	car.steering = 0.55
	await frames(48)
	car.handbrake = true
	await frames(24)
	car.handbrake = false
	await frames(240)
	check(fx.active_segments > 10 and fx.smoke[0].emitting and fx.smoke[1].emitting, "Drift gera marcas e fumaça nas rodas traseiras")
	check(fx.smoke[0].amount + fx.smoke[1].amount == 20, "Limite de 20 partículas")
	if "--capture" in OS.get_cmdline_user_args():
		world.set_process(false)
		world.camera.position = car.global_position + car.global_basis.z * 9 + Vector3.UP * 5
		world.camera.look_at(car.global_position + Vector3.UP * 0.2)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://tests/drift-effects-compat.png" if "--compat" in OS.get_cmdline_user_args() else "res://tests/drift-effects.png"
		root.get_texture().get_image().save_png(output)
		world.set_process(true)
		if "--capture-only" in OS.get_cmdline_user_args():
			quit(0 if failed == 0 else 1)
			return
	fx.smoke_enabled = false
	await frames(12)
	check(not fx.smoke[0].emitting and fx.active_segments > 0, "Pode desligar só a fumaça e manter as marcas")
	fx.smoke_enabled = true
	var node_count := fx.get_child_count()
	await frames(720)
	print("POOL active=", fx.active_segments, " total=", fx.total_segments_created)
	check(fx.total_segments_created > fx.max_segments and fx.active_segments <= fx.max_segments, "Marcas reciclam o limite fixo")
	check(fx.get_child_count() == node_count and node_count == 3, "Sem criar nós por marca/partícula")
	car.steering = 0
	car.throttle = 0
	for settle in range(300):
		await frames(12)
		if car.speed_kmh < 0.5:
			break
	check(car.speed_kmh < 0.5, "Carro encerrou o deslizamento")
	var last_creation: int = fx.total_segments_created
	await frames(roundi(fx.mark_lifetime * 120) + 12)
	check(fx.total_segments_created == last_creation, "Nenhuma marca nova após recuperar aderência")
	print("EXPIRY active=", fx.active_segments, " smoke=", fx.smoke[0].emitting, " speed=", car.speed_kmh, " slip=", car.slip_angle)
	check(fx.active_segments == 0 and not fx.smoke[0].emitting, "Marcas expiram e fumaça para após recuperar aderência")
	car.reset_car()
	await frames(360)
	car.throttle = 1
	await frames(360)
	car.handbrake = true
	await frames(36)
	check(fx.active_segments > 0, "Freio de mão também marca o chão")
	car.spawn_transform.origin = Vector3(65, 20, 70)
	car.reset_car()
	await frames(12)
	check(fx.active_segments == 0 and not fx.smoke[0].emitting, "Reset limpa marcas e interrompe fumaça")
	var created: int = fx.total_segments_created
	await frames(60)
	check(fx.total_segments_created == created, "Sem marcas no ar nem faixas entre teletransportes")
	car.spawn_transform.origin = Vector3(65, 1.2, 70)
	car.handbrake = false
	car.throttle = 0
	car.reset_car()
	await frames(360)
	world.set_process(false)
	world.camera.position = car.position + Vector3(200, 50, 0)
	car.throttle = 1
	await frames(360)
	car.handbrake = true
	await frames(60)
	check(fx.active_segments == 0 and not fx.smoke[0].emitting, "Não emite longe da câmera")
	car.handbrake = false
	car.throttle = 0
	car.reset_car()
	world.set_process(true)
	await frames(360)
	fx.effects_enabled = false
	car.throttle = 1
	await frames(360)
	car.handbrake = true
	await frames(60)
	check(fx.active_segments == 0 and not fx.smoke[0].emitting, "Opção desligada não emite efeitos")
	var weak: WeakRef = weakref(fx)
	world.set_process(false)
	car.queue_free()
	await process_frame
	await process_frame
	check(weak.get_ref() == null, "Remover carro libera todos os efeitos")
	print("RESULT effects failures=", failed)
	quit(0 if failed == 0 else 1)




