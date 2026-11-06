extends SceneTree
var car: RigidBody3D
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1
func frames(count: int) -> void:
	for i in range(maxi(1, roundi(count * Engine.physics_ticks_per_second / 120.0))):
		await physics_frame
func run() -> void:
	if "--ticks60" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second = 60
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1000, 1, 1000)
	collider.shape = shape
	ground.add_child(collider)
	ground.position.y = -0.5
	root.add_child(ground)
	car = load("res://cenas/carro.tscn").instantiate()
	car.input_enabled = false
	car.position.y = 1.2
	root.add_child(car)
	await frames(360)
	var body: MeshInstance3D = car.visual.get_child(0)
	var bounds: AABB = body.transform * body.get_aabb()
	check(absf(bounds.get_center().x) < 0.0001, "Carroceria centralizada no eixo das rodas")
	for axle in range(2):
		var outer: Array[float] = []
		for index in range(axle * 2, axle * 2 + 2):
			var tire: MeshInstance3D = car.visual.spinners[index].get_child(0)
			var tire_bounds: AABB = (car.global_transform.affine_inverse() * tire.global_transform) * tire.get_aabb()
			outer.append(tire_bounds.position.x if index % 2 == 0 else tire_bounds.end.x)
		check(absf(outer[0] + outer[1]) < 0.001, "Pneus simétricos no eixo %d" % axle)
		check(outer[0] >= bounds.position.x - 0.01 and outer[1] <= bounds.end.x + 0.01, "Pneus recolhidos dentro da carroceria no eixo %d" % axle)
	var peaks: Array[float] = []
	for turn in [1.0, -1.0]:
		car.throttle = 0
		car.steering = 0
		car.handbrake = false
		car.reset_car()
		await frames(360)
		car.throttle = 1
		await frames(360)
		check(car.speed_kmh > 60, "Aceleração ágil em três segundos")
		car.steering = 0.55 * turn
		await frames(48)
		car.handbrake = true
		await frames(24)
		car.handbrake = false
		var peak := 0.0
		var drift_samples := 0
		var upright := 1.0
		for i in range(30):
			await frames(12)
			var slip := absf(rad_to_deg(car.slip_angle))
			peak = maxf(peak, slip)
			upright = minf(upright, car.global_basis.y.y)
			if slip > 10 and car.drift_blend > 0.2:
				drift_samples += 1
		print("DRIFT direction=", turn, " peak=", peak, " samples=", drift_samples, " speed=", car.speed_kmh, " up=", upright)
		peaks.append(peak)
		check(peak > 12 and drift_samples >= 8, "Toque de 0,2 s inicia drift sustentado")
		check(peak < 65 and upright > 0.8 and car.speed_kmh > 25, "Drift controlado sem rodar ou tombar")
		car.steering = 0
		await frames(480)
		print("RECOVERY slip=", rad_to_deg(car.slip_angle), " blend=", car.drift_blend)
		check(absf(rad_to_deg(car.slip_angle)) < 8 and car.drift_blend < 0.01, "Recupera aderência ao endireitar")
	check(absf(peaks[0] - peaks[1]) < 2.0, "Drift equivalente nos dois lados")
	car.spawn_transform.origin = Vector3(0, 20, 0)
	car.reset_car()
	await frames(3)
	car.steering = 1
	car.handbrake = true
	await frames(60)
	check(car.drift_blend == 0 and car.angular_velocity.length() < 0.01, "Assistência desligada no ar e após reset")
	print("RESULT arcade failures=", failed)
	quit(0 if failed == 0 else 1)
