extends Node3D
## Bounded world-space marks + two tiny CPU emitters for older GPU compatibility. No extra raycasts.
@export var effects_enabled := true
@export var smoke_enabled := true
@export_range(64, 512, 32) var max_segments := 256
@export_range(2.0, 16.0) var mark_lifetime := 8.0
@export_range(15.0, 100.0) var emission_distance := 70.0
const STEP := 0.05
var active_segments := 0
var total_segments_created := 0
var smoke: Array[CPUParticles3D] = []
var marks: MultiMeshInstance3D
var pool: MultiMesh
var material: ShaderMaterial
var _ages := PackedFloat32Array()
var _centers := PackedVector3Array()
var _previous := PackedVector3Array()
var _linked := [false, false, false, false]
var _surfaces := [0, 0, 0, 0]
var _slot := 0
var _capacity := 0
var _time := 0.0
var _accumulator := 0.0
var _epoch := 0
@onready var car: RigidBody3D = get_parent()

func _ready() -> void:
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	process_physics_priority = 10
	_capacity = clampi(max_segments, 64, 512)
	_ages.resize(_capacity)
	_ages.fill(-1.0)
	_centers.resize(_capacity)
	_previous.resize(4)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
uniform float lifetime = 8.0;
varying float strength;
void vertex() {
    float age = max(0.0, clock - INSTANCE_CUSTOM.r);
    strength = INSTANCE_CUSTOM.g * (1.0 - smoothstep(lifetime * 0.65, lifetime, age));
}
void fragment() {
    float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
    float groove = 0.82 + 0.18 * sin(UV.x * 44.0);
    ALBEDO = vec3(0.025);
    ALPHA = strength * edge * groove * 0.62;
}"""
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("lifetime", mark_lifetime)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	pool = MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_custom_data = true
	pool.mesh = quad
	pool.instance_count = _capacity
	marks = MultiMeshInstance3D.new()
	marks.name = "MarcasAgrupadas"
	marks.multimesh = pool
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)
	for i in range(_capacity):
		_hide_slot(i)
	var smoke_mesh := _smoke_mesh()
	for i in range(2):
		var p := CPUParticles3D.new()
		p.name = "FumacaTraseira%d" % i
		p.emitting = false
		p.amount = 10
		p.lifetime = 1.05
		p.fixed_fps = 20
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.mesh = smoke_mesh
		var process := p
		process.direction = Vector3.UP
		process.spread = 35.0
		process.initial_velocity_min = 0.4
		process.initial_velocity_max = 0.9
		process.gravity = Vector3(0, 0.25, 0)
		process.scale_amount_min = 0.65
		process.scale_amount_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.35))
		curve.add_point(Vector2(1, 1))
		process.scale_amount_curve = curve
		var fade := Gradient.new()
		fade.set_color(0, Color(0.72, 0.74, 0.76, 0.0))
		fade.add_point(0.15, Color(0.72, 0.74, 0.76, 0.24))
		fade.set_color(fade.get_point_count() - 1, Color(0.8, 0.81, 0.82, 0.0))
		process.color_ramp = fade
		add_child(p)
		smoke.append(p)
	marks.visible = false

func _smoke_mesh() -> QuadMesh:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = texture
	mat.albedo_color = Color(0.8, 0.82, 0.84, 0.4)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	quad.material = mat
	return quad

func _hide_slot(index: int) -> void:
	pool.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	pool.set_instance_custom_data(index, Color(0, 0, 0, 0))

func clear_effects() -> void:
	_linked.fill(false)
	for i in range(_capacity):
		_ages[i] = -1
		_hide_slot(i)
	active_segments = 0
	marks.visible = false
	for p in smoke:
		p.restart()
		p.emitting = false

func _physics_process(delta: float) -> void:
	_time += delta
	_accumulator += delta
	if _epoch != car.effects_epoch:
		_epoch = car.effects_epoch
		clear_effects()
	if _accumulator < STEP:
		return
	_accumulator = fmod(_accumulator, STEP)
	material.set_shader_parameter("clock", _time)
	var camera := get_viewport().get_camera_3d()
	var nearby := camera == null or camera.global_position.distance_squared_to(car.global_position) <= emission_distance * emission_distance
	for i in range(4):
		var w: Dictionary = car.wheels[i]
		var strength: float = w.get("skid", 0.0)
		var emitting: bool = effects_enabled and nearby and w.grounded and w.load > 100.0 and strength > 0.08 and car.speed_kmh > 10.8
		if i >= 2:
			var p := smoke[i - 2]
			p.emitting = emitting and smoke_enabled
			if p.emitting:
				p.global_position = w.contact + w.normal * 0.14
				p.color = Color(1, 1, 1, clampf(strength, 0.4, 1.0))
		if not emitting or not w.get("markable", false):
			_linked[i] = false
			continue
		var point: Vector3 = w.contact + w.normal * 0.012
		if _linked[i] and _surfaces[i] == w.surface_id:
			var distance := point.distance_to(_previous[i])
			if distance < 0.18:
				continue
			if distance < 3.5:
				_add_mark(_previous[i], point, w.normal, strength)
		_previous[i] = point
		_surfaces[i] = w.surface_id
		_linked[i] = true
	if active_segments == 0:
		marks.visible = false
		return
	var bounds := AABB()
	var first := true
	for i in range(_capacity):
		if _ages[i] < 0:
			continue
		if _time - _ages[i] >= mark_lifetime or not effects_enabled:
			_ages[i] = -1
			active_segments -= 1
			_hide_slot(i)
			continue
		if first:
			bounds = AABB(_centers[i], Vector3.ZERO)
			first = false
		else:
			bounds = bounds.expand(_centers[i])
	marks.visible = active_segments > 0
	if active_segments > 0:
		pool.custom_aabb = bounds.grow(2.0)

func _add_mark(from: Vector3, to: Vector3, normal: Vector3, strength: float) -> void:
	var direction := (to - from).slide(normal)
	var length := direction.length()
	if length < 0.05:
		return
	direction /= length
	var side := direction.cross(normal).normalized()
	var center := (from + to) * 0.5
	var basis := Basis(side * 0.185, direction * (length + 0.025), normal)
	if _ages[_slot] < 0:
		active_segments += 1
	_ages[_slot] = _time
	_centers[_slot] = center
	pool.set_instance_transform(_slot, Transform3D(basis, center))
	pool.set_instance_custom_data(_slot, Color(_time, strength, 0, 0))
	_slot = (_slot + 1) % _capacity
	total_segments_created += 1

