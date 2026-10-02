extends AnimatableBody3D
# A tank or ZPT that patrols the city roads: it drives from crossing to crossing,
# turns on the spot, waits at junctions, stops for anything in its way, and sweeps
# the turret, turning it towards the survivor when it sees them. Rockets and mines
# destroy it (explosives.gd); the burnt-out wreck stays as cover.

const VehicleModel = preload("res://scripts/combat/armor/vehicle_model.gd")
const SIGHT := 45.0

var kind := "tank"
var hp := 280.0
var destroyed := false
var visuals: Array[MeshInstance3D] = []
var parts := {}
var city: Node3D
var game: Node
var rng := RandomNumberGenerator.new()
var max_speed := 3.0
var turn_rate := 0.5
var speed := 0.0
var spin := 0.0
# Kept here and written as a whole transform each tick: with sync_to_physics the
# node's own rotation is overwritten by the physics body's.
var heading := 0.0
# Road graph node the vehicle is heading for or standing at, and where it came from.
var node := -1
var previous := -1
var goal := Vector3.ZERO
var driving := false
var wait := 0.0
var blocked := 0.0
var travel := [0.0, 0.0]
var turret_goal := 0.0
var scan_time := 0.0
var engine: AudioStreamPlayer3D
var clatter: AudioStreamPlayer3D
var smoke: CPUParticles3D


func _ready() -> void:
	add_to_group("armored_vehicle")
	# Placed with a plain move first; setup() switches on pushing motion.
	sync_to_physics = false
	hp = 280.0 if kind == "tank" else 170.0
	max_speed = 3.0 if kind == "tank" else 4.5
	turn_rate = 0.5 if kind == "tank" else 0.65
	rng.randomize()
	parts = VehicleModel.build(kind, self)
	for mesh in parts.meshes:
		visuals.append(mesh)
	var hull := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 1.55, 7.0) if kind == "tank" else Vector3(2.9, 1.55, 7.7)
	hull.shape = box
	hull.position.y = 0.85 if kind == "tank" else 1.1
	add_child(hull)
	var top := CollisionShape3D.new()
	var dome := CylinderShape3D.new()
	dome.radius = 1.25 if kind == "tank" else 0.95
	dome.height = 0.75 if kind == "tank" else 0.5
	top.shape = dome
	top.position = Vector3(0, 1.95, -0.2) if kind == "tank" else Vector3(0, 2.1, -0.4)
	add_child(top)
	create_sound()
	wait = rng.randf_range(2.0, 6.0)


# The city road graph; without it (a test vehicle) the vehicle stays parked.
func setup(city_builder: Node3D) -> void:
	city = city_builder
	game = city_builder.get_parent()
	heading = rotation.y
	# From here on it drives, and its moves push whatever they meet.
	sync_to_physics = true


func create_sound() -> void:
	engine = AudioStreamPlayer3D.new()
	engine.stream = looped("res://assets/audio/tank_engine.wav")
	engine.volume_db = -9.0 if kind == "tank" else -12.0
	engine.unit_size = 6.0
	engine.max_distance = 70.0
	engine.pitch_scale = 0.9 if kind == "tank" else 1.15
	add_child(engine)
	clatter = AudioStreamPlayer3D.new()
	clatter.stream = looped("res://assets/audio/tank_tracks.wav")
	clatter.volume_db = -60.0
	clatter.unit_size = 5.0
	clatter.max_distance = 55.0
	add_child(clatter)


# Engine and track sounds are seamless loops (tools/make_sounds.py).
static func looped(path: String) -> AudioStreamWAV:
	var sound: AudioStreamWAV = load(path)
	if sound.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = int(sound.get_length() * sound.mix_rate)
	return sound


func blast_target() -> Vector3:
	return global_position + Vector3.UP * 1.1


func take_explosion(damage: float) -> bool:
	if destroyed:
		return false
	hp = maxf(0.0, hp - damage)
	if hp > 0.0:
		# A hit makes the crew stop and look for the shooter.
		wait = maxf(wait, 1.5)
		return false
	destroyed = true
	speed = 0.0
	driving = false
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color("24221f")
	burnt.roughness = 1.0
	for mesh in visuals:
		mesh.material_override = burnt
	if parts.has("gun"):
		parts.gun.rotation.x = -0.12
	engine.stop()
	clatter.stop()
	create_smoke()
	# A wreck remains solid cover, but cannot take damage again.
	return true


func create_smoke() -> void:
	smoke = CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 6.0
	smoke.position = Vector3(0, 2.0, 0.6)
	smoke.direction = Vector3(0.15, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3(0.25, 0.15, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = curve
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.09, 0.09, 0.085, 0.45)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	puff.material = look
	smoke.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = fade
	add_child(smoke)


func paused() -> bool:
	return game != null and game.get("paused") == true


func _physics_process(delta: float) -> void:
	if destroyed or city == null:
		return
	var halted := paused()
	engine.stream_paused = halted
	clatter.stream_paused = halted
	if halted:
		return
	if not engine.playing:
		engine.play()
		clatter.play()
	update_turret(delta)
	var turning := 0.0
	var target_speed := 0.0
	if wait > 0.0:
		wait -= delta
	elif not driving:
		plan()
	else:
		var to_goal := goal - global_position
		to_goal.y = 0.0
		var distance := to_goal.length()
		if distance < 0.8:
			arrive()
		else:
			var bearing := atan2(-to_goal.x, -to_goal.z)
			var diff := wrapf(bearing - heading, -PI, PI)
			turning = clampf(diff, -turn_rate * delta, turn_rate * delta)
			heading = wrapf(heading + turning, -PI, PI)
			# Turn on the spot first, then drive, easing off near the crossing.
			if absf(diff) < 0.25:
				target_speed = max_speed * clampf(distance / 5.0, 0.35, 1.0)
			if target_speed > 0.0 and distance > 1.5 and path_blocked():
				target_speed = 0.0
				blocked += delta
				if blocked > 4.0:
					# Something will not move: find another way from here.
					blocked = 0.0
					driving = false
					previous = node
					node = -1
					wait = 1.0
			else:
				blocked = 0.0
	speed = move_toward(speed, target_speed, delta * (1.2 if target_speed > speed else 2.5))
	var facing := Basis(Vector3.UP, heading)
	global_transform = Transform3D(facing, global_position + facing * Vector3.FORWARD * speed * delta)
	spin = turning / maxf(delta, 0.0001)
	animate_running_gear(delta)


# Next stop: the nearest crossing to start with, then a neighbouring one along the road.
func plan() -> void:
	var graph: Dictionary = road_graph()
	if graph.points.is_empty():
		wait = 5.0
		return
	if node < 0 or node >= graph.points.size():
		var best := -1
		var best_distance := INF
		var best_goal := Vector3.ZERO
		for index in range(graph.points.size()):
			var point: Vector3 = graph.points[index]
			var distance := point.distance_to(global_position)
			if distance >= best_distance or index == previous or not city.on_same_road(point, global_position):
				continue
			var lane: Variant = clear_lane(point)
			if lane != null:
				best_distance = distance
				best = index
				best_goal = lane
		if best < 0:
			previous = -1
			wait = 4.0
			return
		node = best
		goal = best_goal
		driving = true
		return
	var options: Array = graph.links[node].duplicate()
	options.shuffle()
	# Carry on rather than double back, unless that is the only way.
	options.sort_custom(func(a, b): return int(a == previous) < int(b == previous))
	for option: int in options:
		var lane: Variant = clear_lane(graph.points[option])
		if lane != null:
			previous = node
			node = option
			goal = lane
			driving = true
			return
	wait = rng.randf_range(3.0, 6.0)


# The road to a crossing down the middle, or else down either side of it past
# whatever lies in the way. Returns where to aim, or null when all three are blocked.
func clear_lane(point: Vector3) -> Variant:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() < 0.5:
		return point
	var across := Vector3(-flat.z, 0, flat.x).normalized()
	for offset in [0.0, 2.6, -2.6]:
		var target: Vector3 = point + across * offset
		if sweep_clear(global_position, target):
			return target
	return null


func arrive() -> void:
	driving = false
	# Pause now and then at a junction, as if the crew were looking around.
	wait = rng.randf_range(2.0, 7.0) if rng.randf() < 0.45 else 0.3


# Crossings and road midpoints, linked to their neighbours along each road. The
# first street (where the survivor starts) is left out.
func road_graph() -> Dictionary:
	if city.has_meta("vehicle_graph"):
		return city.get_meta("vehicle_graph")
	var keep_out: Rect2 = city.STREET_AREA.grow(6.0)
	var points: Array[Vector3] = []
	for point: Vector3 in city.nodes:
		if not keep_out.has_point(Vector2(point.x, point.z)):
			points.append(Vector3(point.x, 0.0, point.z))
	var links: Array = []
	for index in range(points.size()):
		var nearest := {}
		for other in range(points.size()):
			if other == index:
				continue
			var a := points[index]
			var b := points[other]
			var along_x := absf(a.z - b.z) < 0.5
			var along_z := absf(a.x - b.x) < 0.5
			if not (along_x or along_z) or not city.on_same_road(a, b):
				continue
			var middle := (a + b) / 2.0
			if keep_out.has_point(Vector2(middle.x, middle.z)):
				continue
			var key := ("x+" if b.x > a.x else "x-") if along_x else ("z+" if b.z > a.z else "z-")
			if not nearest.has(key) or a.distance_to(b) < a.distance_to(points[nearest[key]]):
				nearest[key] = other
		links.append(nearest.values())
	var graph := {"points": points, "links": links}
	city.set_meta("vehicle_graph", graph)
	return graph


func footprint() -> BoxShape3D:
	var box := BoxShape3D.new()
	box.size = Vector3(3.5, 1.2, 1.2) if kind == "tank" else Vector3(2.8, 1.2, 1.2)
	return box


# The road from here to there is free of wrecks, rubble and sandbags.
func sweep_clear(from: Vector3, to: Vector3) -> bool:
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	if flat.length() < 0.5:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = footprint()
	query.transform = Transform3D(Basis(Vector3.UP, atan2(-flat.x, -flat.z)), from + Vector3(0, 0.95, 0))
	query.motion = flat
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result.size() > 0 and result[0] >= 0.999


# Something just ahead of the bow: a person, a soldier, another vehicle, a wreck.
func path_blocked() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = footprint()
	# Just off the bow: hull half-length plus a little.
	var reach := 4.2 if kind == "tank" else 4.55
	query.transform = Transform3D(global_basis, global_position + global_basis * Vector3(0, 0.95, -reach))
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# The turret sweeps slowly; a survivor in plain sight draws the gun round.
func update_turret(delta: float) -> void:
	if not parts.has("turret"):
		return
	var turret: Node3D = parts.turret
	var target := turret_goal
	var player: Node3D = game.get("player") if game else null
	var watching := false
	if player and player.get("alive"):
		var offset := player.global_position - global_position
		if offset.length() < SIGHT and sees(player):
			var local := global_basis.inverse() * offset
			target = atan2(-local.x, -local.z)
			watching = true
	if not watching:
		scan_time -= delta
		if scan_time <= 0.0:
			scan_time = rng.randf_range(3.0, 7.0)
			turret_goal = rng.randf_range(-1.3, 1.3)
	var diff := wrapf(target - turret.rotation.y, -PI, PI)
	turret.rotation.y += clampf(diff, -0.35 * delta, 0.35 * delta)
	var gun: Node3D = parts.gun
	gun.rotation.x = lerpf(gun.rotation.x, 0.03 if watching else 0.0, delta)


func sees(player: Node3D) -> bool:
	var eye := global_position + Vector3(0, 2.6, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3(0, 1.4, 0))
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# Wheels and tracks turn with the ground speed; turning on the spot runs the two
# sides in opposite directions.
func animate_running_gear(delta: float) -> void:
	var half_width := 1.5 if kind == "tank" else 1.25
	var sides := [speed - spin * half_width, speed + spin * half_width]
	for index in 2:
		travel[index] += sides[index] * delta
	for wheel: Dictionary in parts.wheels:
		var side_index := 0 if wheel.side < 0.0 else 1
		wheel.node.rotation.x = -travel[side_index] / wheel.radius
	for index in range(parts.tracks.size()):
		var track: StandardMaterial3D = parts.tracks[index]
		track.uv1_offset.x = travel[index] / VehicleModel.TRACK_LINK
	var effort := clampf(absf(speed) / max_speed + absf(spin) * 0.6, 0.0, 1.0)
	engine.pitch_scale = (0.9 if kind == "tank" else 1.15) + effort * 0.35
	engine.volume_db = (-9.0 if kind == "tank" else -12.0) + effort * 4.0
	clatter.volume_db = linear_to_db(effort * (0.7 if kind == "tank" else 0.25) + 0.0001)
	clatter.pitch_scale = 0.8 + effort * 0.4
