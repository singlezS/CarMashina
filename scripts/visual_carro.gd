extends Node3D

var pivots: Array[Node3D] = []
var spinners: Array[Node3D] = []
var wheel_offsets: Array[Vector3] = []
var spin_ratios: Array[float] = []

# A mesma suspensão anima qualquer modelo. O deslocamento é só visual.
func add_wheel(tire: MeshInstance3D, offset := Vector3.ZERO, spin_ratio := 1.0) -> void:
	var pivot := Node3D.new()
	var spinner := Node3D.new()
	add_child(pivot)
	pivot.add_child(spinner)
	spinner.add_child(tire)
	pivots.append(pivot)
	spinners.append(spinner)
	wheel_offsets.append(offset)
	spin_ratios.append(spin_ratio)

func update_wheel(index: int, center: Vector3, steer: float, spin: float) -> void:
	pivots[index].position = center + wheel_offsets[index]
	pivots[index].rotation.y = steer
	spinners[index].rotation.x = spin * spin_ratios[index]
