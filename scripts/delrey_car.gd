extends RigidBody3D
## SI units, -Z forward. Arcade street setup with assisted, contact-bound drift.
@export var modelo: PackedScene
@export_group("Chassi")
@export var vehicle_mass := 980.0
@export var wheelbase := 2.588
@export var track_width := 1.14
@export var radius := 0.311
@export_group("Suspensão")
@export var rest_length := 0.34
@export var spring_rate := 30000.0
@export var damping := 2600.0
@export var antiroll := 6500.0
@export_group("Motor e pneus")
@export var engine_force := 6400.0
@export var engine_power := 110000.0
@export var max_speed := 55.0
@export var reverse_speed := 9.0
@export var brake_force := 14500.0
@export var tire_grip := 1.15
@export var lateral_response := 12.0
@export_group("Corrida e drift")
## Tuned AWD conversion, 65% rear drive; not the stock Del Rey drivetrain.
@export_range(0.0, 1.0) var front_drive_share := 0.35
@export var steering_rate := 3.4
@export var drift_min_speed := 7.0
@export_range(0.0, 1.0) var drift_rear_grip := 0.72
@export_range(0.0, 1.0) var drift_assist := 0.75
@export var drift_hold_time := 1.1
@export var input_enabled := true
var drift_blend := 0.0
var drift_timer := 0.0
var slip_angle := 0.0
var throttle := 0.0
var steering := 0.0
var handbrake := false
var speed_kmh := 0.0
var grounded_count := 0
var steer_angle := 0.0
var reset_pending := false
var effects_epoch := 0
var spawn_transform := Transform3D.IDENTITY
var wheels: Array[Dictionary] = []
var visual: Node3D

func _ready() -> void:
	visual = modelo.instantiate()
	visual.name = "Visual"
	add_child(visual)
	mass = vehicle_mass
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.18, -0.08)
	continuous_cd = true
	can_sleep = false
	linear_damp_mode = DAMP_MODE_REPLACE
	angular_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.15
	spawn_transform = global_transform
	for i in range(4):
		wheels.append({"mount": Vector3((-1.0 if i % 2 == 0 else 1.0) * track_width / 2.0, 0, (-1.0 if i < 2 else 1.0) * wheelbase / 2.0), "grounded": false, "length": rest_length, "load": 0.0, "spin": 0.0, "speed": 0.0, "steer": 0.0, "surface_velocity": Vector3.ZERO})

func _physics_process(_delta: float) -> void:
	if input_enabled:
		throttle = Input.get_axis("decelerate", "accelerate")
		steering = Input.get_axis("turn_right", "turn_left")
		handbrake = Input.is_action_pressed("handbreak")
		if Input.is_action_just_pressed("reset_car") or global_position.y < -20.0:
			reset_pending = true
	for i in range(wheels.size()):
		var w := wheels[i]
		visual.update_wheel(i, w.mount - Vector3.UP * float(w.length), w.steer, w.spin)

func reset_car() -> void:
	reset_pending = true

func effective_mass(state: PhysicsDirectBodyState3D, arm: Vector3, direction: Vector3) -> float:
	return 1.0 / maxf(state.inverse_mass + direction.dot((state.inverse_inertia_tensor * arm.cross(direction)).cross(arm)), 0.00001)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if wheels.size() != 4:
		return
	if reset_pending:
		effects_epoch += 1
		state.transform = spawn_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		steer_angle = 0.0
		speed_kmh = 0.0
		grounded_count = 0
		drift_blend = 0.0
		drift_timer = 0.0
		slip_angle = 0.0
		for w in wheels:
			w.grounded = false
			w.length = rest_length
			w.speed = 0.0
			w.spin = 0.0
			w.load = 0.0
		reset_pending = false
		return
	var dt := state.step
	var basis := state.transform.basis.orthonormalized()
	var forward_speed := state.linear_velocity.dot(-basis.z)
	var side_speed := state.linear_velocity.dot(basis.x)
	slip_angle = atan2(side_speed, maxf(absf(forward_speed), 0.5))
	speed_kmh = state.linear_velocity.length() * 3.6
	var steer_limit := lerpf(0.60, 0.21, clampf(absf(forward_speed) / 42.0, 0, 1))
	var steering_target := steering * steer_limit
	# Follow the direction of travel with automatic countersteer during the slide.
	if forward_speed > drift_min_speed:
		steering_target = lerpf(steering_target, clampf(-slip_angle + steering * 0.22, -0.65, 0.65), drift_blend * drift_assist)
	steer_angle = move_toward(steer_angle, steering_target, (steering_rate if absf(steering) > 0.01 else steering_rate * 1.3) * dt)
	var space := state.get_space_state()
	grounded_count = 0
	for i in range(4):
		var w := wheels[i]
		var start: Vector3 = state.transform * w.mount
		var query := PhysicsRayQueryParameters3D.create(start, start - basis.y * (rest_length + radius), collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		w.grounded = not hit.is_empty() and hit.normal.dot(basis.y) > 0.35
		w.load = 0.0
		w.skid = 0.0
		w.length = rest_length
		w.steer = 0.0
		if i < 2 and absf(steer_angle) > 0.001:
			# Ackermann: inner wheel turns more sharply.
			var turn_radius := wheelbase / tan(absf(steer_angle))
			var inner := (i == 0 and steer_angle > 0) or (i == 1 and steer_angle < 0)
			w.steer = signf(steer_angle) * atan(wheelbase / (turn_radius + (-0.5 if inner else 0.5) * track_width))
		if not w.grounded:
			w.spin = fmod(float(w.spin) - float(w.speed) / radius * dt, TAU)
			continue
		grounded_count += 1
		w.contact = hit.position
		w.normal = hit.normal
		w.surface_id = hit.collider.get_instance_id()
		w.markable = hit.collider is StaticBody3D and not hit.collider is AnimatableBody3D and hit.collider.constant_linear_velocity.is_zero_approx() and hit.collider.constant_angular_velocity.is_zero_approx()
		w.length = clampf(start.distance_to(hit.position) - radius, 0.0, rest_length)
		w.surface_velocity = Vector3.ZERO
		if hit.collider is RigidBody3D:
			var other := hit.collider as RigidBody3D
			w.surface_velocity = other.linear_velocity + other.angular_velocity.cross(hit.position - other.to_global(other.center_of_mass))
		var arm: Vector3 = hit.position - state.transform.origin - state.center_of_mass
		var normal_speed := (state.linear_velocity + state.angular_velocity.cross(arm) - Vector3(w.surface_velocity)).dot(hit.normal)
		w.load = spring_rate * (rest_length - float(w.length)) - damping * normal_speed
	for axle in range(2):
		var left := wheels[axle * 2]
		var right := wheels[axle * 2 + 1]
		if left.grounded and right.grounded:
			var transfer := (float(right.length) - float(left.length)) * antiroll
			left.load += transfer
			right.load -= transfer
	# A tap initiates the slide; throttle and turning sustain it after release.
	var can_drift := grounded_count >= 3 and forward_speed > drift_min_speed
	if can_drift and handbrake and absf(steering) > 0.12:
		drift_timer = drift_hold_time
	else:
		drift_timer = maxf(0.0, drift_timer - dt)
	var sustain := drift_blend > 0.1 and throttle > 0.25 and absf(steering) > 0.12 and absf(slip_angle) > 0.12
	var want_drift := 1.0 if can_drift and (drift_timer > 0.0 or sustain) else 0.0
	# Restore rear grip progressively before a slide turns into a full spin.
	want_drift *= 1.0 - smoothstep(0.65, 1.05, absf(slip_angle))
	drift_blend = move_toward(drift_blend, want_drift, (3.5 if want_drift > drift_blend else 2.0) * dt)
	if can_drift and drift_blend > 0.01:
		var yaw_rate := state.angular_velocity.dot(basis.y)
		var target_slip := steering * 0.6
		var target_yaw := steering * 0.9 - (slip_angle - target_slip) * 2.5
		target_yaw = clampf(target_yaw, -0.85, 0.85)
		var correction := clampf((target_yaw - yaw_rate) * 5000.0, -4200.0, 4200.0)
		state.apply_torque(basis.y * correction * drift_blend * drift_assist)
	var drive := throttle
	var brake := 0.0
	if throttle * forward_speed < -0.4:
		brake = absf(throttle)
		drive = 0.0
	elif absf(throttle) < 0.01:
		brake = 0.025 if absf(forward_speed) > 0.5 else 0.5
	var speed_limit := max_speed if drive >= 0 else reverse_speed
	var engine := drive * minf(engine_force, engine_power / maxf(absf(forward_speed), 1.0)) * clampf((speed_limit - absf(forward_speed)) / 3.0, 0, 1)
	state.apply_central_force(-state.linear_velocity * state.linear_velocity.length() * 0.42)
	for i in range(4):
		var w := wheels[i]
		if not w.grounded:
			continue
		var n: Vector3 = w.normal
		var offset: Vector3 = w.contact - state.transform.origin
		var arm := offset - state.center_of_mass
		w.load = clampf(w.load, 0.0, vehicle_mass * state.total_gravity.length())
		state.apply_force(n * float(w.load), offset)
		var fw := (-basis.z).rotated(basis.y, w.steer).slide(n).normalized()
		var side := fw.cross(n).normalized()
		var velocity := state.linear_velocity + state.angular_velocity.cross(arm) - Vector3(w.surface_velocity)
		var longitudinal := velocity.dot(fw)
		var lateral := velocity.dot(side)
		var locked := handbrake and i >= 2
		w.skid = clampf((absf(lateral) - 1.5) / 4.0, 0.0, 1.0)
		if locked:
			w.skid = maxf(w.skid, clampf(absf(longitudinal) / 8.0, 0.0, 1.0))
		var rear_factor := lerpf(1.0, drift_rear_grip, drift_blend) if i >= 2 else 1.0
		var grip := tire_grip * float(w.load) * rear_factor * (0.55 if locked else 1.0)
		var brake_share := 0.32 if i < 2 else 0.18
		var resistance := brake_force * brake_share * brake + float(w.load) * 0.015
		if locked:
			resistance += brake_force * 0.5
		var drive_share := front_drive_share if i < 2 else 1.0 - front_drive_share
		var fx := 0.0 if locked else engine * drive_share * 0.5
		# Shared mass budget prevents four simultaneous contacts from over-braking.
		var longitudinal_mass := minf(effective_mass(state, arm, fw), vehicle_mass / 4.0)
		var lateral_mass := minf(effective_mass(state, arm, side), vehicle_mass / 4.0)
		fx += clampf(-longitudinal * longitudinal_mass / dt, -resistance, resistance)
		var response := lateral_response * (lerpf(1.0, 0.55, drift_blend) if i >= 2 else 1.0)
		var fy := -lateral * lateral_mass * (1.0 - exp(-response * dt)) / dt
		# A single friction circle bounds braking, cornering and traction together.
		var tire_force := Vector2(fx, fy).limit_length(grip)
		state.apply_force(fw * tire_force.x + side * tire_force.y, offset)
		w.speed = 0.0 if locked else longitudinal
		w.spin = fmod(float(w.spin) - float(w.speed) / radius * dt, TAU)
