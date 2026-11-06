extends SceneTree
var car: RigidBody3D
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)

func frames(count: int) -> void:
	for i in range(maxi(1, roundi(count * Engine.physics_ticks_per_second / 120.0))):
		await physics_frame
		if not car.linear_velocity.is_finite() or not car.angular_velocity.is_finite():
			check(false, "Velocidade finita")
			quit(1)
			return

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if "--ticks60" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second = 60
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1000, 1, 1000)
	collision.shape = shape
	ground.add_child(collision)
	ground.position.y = -0.5
	root.add_child(ground)
	car = load("res://cenas/carro.tscn").instantiate()
	car.position.y = 1.2
	car.input_enabled = false
	root.add_child(car)
	await frames(600)
	print("REST ", car.position, " velocity ", car.linear_velocity, " wheels ", car.grounded_count)
	check(car.grounded_count == 4 and car.linear_velocity.length() < 0.15, "Repouso estável / quatro contatos")
	check(car.position.y > 0.4 and car.position.y < 0.8, "Altura da suspensão")
	check(car.visual.pivots.size() == 4 and car.visual.spinners.size() == 4, "Quatro rodas originais independentes")
	car.throttle = 1.0
	await frames(720)
	print("ACCEL ", car.speed_kmh, " position ", car.position)
	check(car.speed_kmh > 35 and car.position.z < -20, "Aceleração para frente")
	check(absf(car.position.x) < 1.0, "Trajetória reta simétrica")
	var braking_speed := car.linear_velocity.length()
	var braking_start := car.position
	car.throttle = -1.0
	var stopped := false
	for step in range(40):
		await frames(12)
		if car.linear_velocity.dot(-car.global_basis.z) < 0.8:
			stopped = true
			break
	print("BRAKE ", car.speed_kmh)
	check(stopped and car.position.distance_to(braking_start) < braking_speed * braking_speed / 14.0 + 5.0, "Freio antes de engatar ré / distância proporcional à velocidade")
	await frames(480)
	check(car.linear_velocity.dot(car.global_basis.z) > 2 and car.speed_kmh < 34, "Ré limitada")
	car.throttle = 0.0
	car.reset_car()
	await frames(360)
	car.throttle = 1.0
	await frames(360)
	car.steering = 0.6
	await frames(240)
	print("TURN ", car.global_basis.z, " up ", car.global_basis.y)
	check(car.global_basis.z.x > 0.15, "Direção esquerda")
	check(car.global_basis.y.y > 0.75, "Estabilidade em curva")
	check(absf(car.wheels[0].steer) > absf(car.wheels[1].steer), "Ackermann interno / externo")
	car.handbrake = true
	await frames(60)
	check(car.wheels[2].speed == 0 and car.wheels[3].speed == 0, "Freio de mão trava somente rodas traseiras")
	car.steering = 0
	car.handbrake = false
	car.throttle = 0
	car.reset_car()
	await frames(360)
	check(car.global_position.distance_to(Vector3(0, 0.56, 0)) < 0.15, "Reposicionamento limpo")
	ground.rotation.z = 0.12
	car.reset_car()
	await frames(720)
	check(car.grounded_count == 4 and car.global_basis.y.y > 0.95 and car.linear_velocity.length() < 0.5, "Suspensão em piso inclinado")
	ground.rotation.z = 0
	car.reset_car()
	await frames(360)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(20, 5, 1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 2.5, -12)
	root.add_child(wall)
	car.throttle = 1
	await frames(600)
	check(car.position.z > -12 and car.global_basis.y.y > 0.7, "Colisão do chassi contra parede")
	car.spawn_transform.origin = Vector3(0, 15, 0)
	car.reset_car()
	await frames(2)
	car.throttle = 1
	await frames(60)
	check(car.grounded_count == 0 and absf(car.linear_velocity.z) < 0.05, "Sem tração no ar")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
