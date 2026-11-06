extends CanvasLayer

var saldo := 0
var aviso: Tween

func mostrar_velocidade(kmh: float) -> void:
	%Velocidade.text = "%03d km/h" % roundi(kmh)

func registrar_passagem() -> void:
	saldo += 1
	%Saldo.text = "R$ %d" % saldo
	if aviso:
		aviso.kill()
	%Ganho.show()
	%Ganho.modulate.a = 1.0
	aviso = create_tween()
	aviso.tween_interval(0.85)
	aviso.tween_property(%Ganho, "modulate:a", 0.0, 0.35)
	aviso.tween_callback(%Ganho.hide)
