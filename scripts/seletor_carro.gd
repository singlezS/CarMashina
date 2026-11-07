extends Node3D

@export var modelos: Array[PackedScene] = []
const WORLD := preload("res://cenas/world.tscn")
var previa: Node3D

func _ready() -> void:
	for modelo in modelos:
		%Modelo.add_item(modelo.get_state().get_node_name(0))
	%Modelo.item_selected.connect(_mostrar)
	%Jogar.pressed.connect(_iniciar)
	%Modelo.grab_focus()
	if modelos.is_empty():
		%Jogar.disabled = true
		return
	_mostrar(0)

func _mostrar(index: int) -> void:
	if previa:
		%Expositor.remove_child(previa)
		previa.queue_free()
	previa = modelos[index].instantiate()
	%Expositor.add_child(previa)
	for i in range(4):
		var centro := Vector3(-0.57 if i % 2 == 0 else 0.57, -0.26, -1.294 if i < 2 else 1.294)
		previa.update_wheel(i, centro, 0, 0)

func _iniciar() -> void:
	if %Jogar.disabled:
		return
	%Jogar.disabled = true
	var mundo := WORLD.instantiate()
	mundo.get_node("Carro").modelo = modelos[%Modelo.selected]
	var erro := get_tree().change_scene_to_node(mundo)
	if erro != OK:
		mundo.free()
		%Jogar.disabled = false
		push_error(error_string(erro))
