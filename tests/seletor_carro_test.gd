extends SceneTree

var falhas := 0

func _initialize() -> void:
	call_deferred("testar")

func conferir(ok: bool, texto: String) -> void:
	print(("OK " if ok else "FALHA ") + texto)
	if not ok:
		falhas += 1

func testar() -> void:
	var menu_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var nomes := ["Del Rey", "Saveiro", "Celta"]
	for i in nomes.size():
		change_scene_to_file(menu_path)
		await scene_changed
		var menu := current_scene
		var lista := menu.get_node("%Modelo") as OptionButton
		conferir(lista.get_item_text(i) == nomes[i], "Modelo na lista")
		lista.select(i)
		lista.item_selected.emit(i)
		var nome := lista.get_item_text(i)
		conferir(menu.previa.name == nome and menu.previa.pivots.size() == 4, "Prévia de " + nome)
		if "--foto" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/seletor-previa-%d.png" % i)
		menu.get_node("%Jogar").pressed.emit()
		await scene_changed
		var car: RigidBody3D = current_scene.get_node("Carro")
		car.input_enabled = false
		var hud := current_scene.get_node("HUD")
		conferir(hud.get_node("Painel/Leituras/Titulo").text.begins_with(nome.to_upper()), "HUD de " + nome)
		for frame in range(240):
			await physics_frame
		conferir(car.grounded_count == 4, "Quatro pneus no chão")
		var bounds := AABB()
		var primeiro := true
		var body := car.visual.get_child(0) as Node3D
		var meshes := body.find_children("*", "MeshInstance3D", true, false)
		if body is MeshInstance3D:
			meshes.append(body)
		for mesh: MeshInstance3D in meshes:
			var caixa: AABB = (car.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = caixa if primeiro else bounds.merge(caixa)
			primeiro = false
		print(nome, " comprimento = ", bounds.size.z)
		var comprimento := 3.878 if nome == "Celta" else 4.554902
		conferir(absf(bounds.size.z - comprimento) < 0.003, "Comprimento da carroceria")
		for roda in range(4):
			var tire: MeshInstance3D = car.visual.spinners[roda].get_child(0)
			var caixa := tire.global_transform * tire.get_aabb()
			var contato: Vector3 = car.wheels[roda].contact
			conferir(absf(caixa.position.y - contato.y) < 0.02, "Pneu %d toca a pista" % roda)
		var marcador: Area3D = current_scene.get_node("Marcadores").get_child(0)
		car.spawn_transform.origin = marcador.global_position + Vector3(0, 1.2, 16)
		car.reset_car()
		for frame in range(150):
			await physics_frame
		car.throttle = 1
		for frame in range(600):
			await physics_frame
			if hud.saldo > 0:
				break
		conferir(hud.saldo == 1 and car.speed_kmh > 10, nome + " passa pelo marcador")
	print("Falhas: ", falhas)
	quit(1 if falhas else 0)
