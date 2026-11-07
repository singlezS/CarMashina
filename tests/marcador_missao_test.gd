extends SceneTree

var erros := 0

func _initialize() -> void:
	call_deferred("testar")

func conferir(ok: bool, nome: String) -> void:
	print(("OK " if ok else "FALHA ") + nome)
	if not ok:
		erros += 1

func passos(quantidade: int) -> void:
	for i in range(quantidade):
		await physics_frame

func testar() -> void:
	var mundo: Node3D = load("res://cenas/world.tscn").instantiate()
	root.add_child(mundo)
	var carro: RigidBody3D = mundo.get_node("Carro")
	var hud: CanvasLayer = mundo.get_node("HUD")
	var primeiro: Area3D = mundo.get_node("Marcadores").get_child(0)
	carro.input_enabled = false
	carro.spawn_transform.origin = primeiro.global_position + Vector3(0, 1.2, 16)
	carro.reset_car()
	await passos(120)
	conferir(hud.saldo == 0, "Inicia com saldo zero")

	var outro := StaticBody3D.new()
	outro.collision_layer = 2
	var colisao := CollisionShape3D.new()
	colisao.shape = BoxShape3D.new()
	outro.add_child(colisao)
	outro.position = primeiro.position + Vector3.UP
	mundo.add_child(outro)
	await passos(12)
	conferir(primeiro.overlaps_body(outro) and hud.saldo == 0, "Outro corpo na área não recebe crédito")
	outro.queue_free()
	await passos(12)

	carro.throttle = 1
	for i in range(600):
		await physics_frame
		if hud.saldo > 0:
			break
	conferir(hud.saldo == 1 and hud.get_node("%Saldo").text == "R$ 1" and hud.get_node("%Ganho").visible, "Passagem dirigindo mostra +1 REAL e R$ 1")
	if "--foto" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/marcador-previa.png")
	await passos(150)
	conferir(not primeiro.overlaps_body(carro) and hud.saldo == 1, "Sair da área não duplica o crédito")
	carro.throttle = 0
	var esperado := 1
	for ponto in mundo.get_node("Marcadores").get_children():
		carro.spawn_transform.origin = ponto.global_position + Vector3.UP * 1.2
		carro.reset_car()
		await passos(240)
		esperado += 1
		conferir(ponto.overlaps_body(carro) and hud.saldo == esperado and not hud.get_node("%Ganho").visible, "Conta uma vez e esconde aviso enquanto permanece em " + str(ponto.name))
	mundo.queue_free()
	await process_frame
	var nova_rodada: Node3D = load("res://cenas/world.tscn").instantiate()
	root.add_child(nova_rodada)
	conferir(nova_rodada.get_node("HUD").saldo == 0, "Reiniciar o mundo zera o teste")
	print("Erros: ", erros)
	quit(1 if erros else 0)
