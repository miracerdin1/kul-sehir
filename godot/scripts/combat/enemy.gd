extends CharacterBody3D
# A soldier carried over from the HTML reference (spawnEnemy, enemySees, updateEnemy,
# enemyShoot): patrols between waypoints, notices the survivor by sight or noise,
# hunts the last known position and fires in bursts.

const AssetFactory = preload("res://scripts/asset_factory.gd")
const ArmedBody = preload("res://scripts/combat/armed_body.gd")
const CLIP_SPEED := {"Walk": 1.65, "Run": 3.0}
const PATROL_SPEED := 1.5
const INVESTIGATE_SPEED := 2.7
const CHASE_SPEED := 3.1
const EYE_HEIGHT := 1.62

var director: Node
var player: CharacterBody3D
var visual: Node3D
var animation: AnimationPlayer
var armed: ArmedBody
var collision: CollisionShape3D
var weapon := "rifle"
var hp := 100.0
var alive := true
var state := "patrol"
var aware := 0.0
var can_see := false
var perceive_in := 0.0
var cooldown := 1.0
var burst := 0
var waypoints: Array[Vector3] = []
var goal := Vector3.ZERO
var wait_time := 0.0
var last_known := Vector3.ZERO
var lost_time := 0.0
var stuck_time := 0.0
var side_time := 0.0
var side_direction := 1.0
var spotted := false
var searched := false
var loot: Array = []
var motion := ""
var last_position := Vector3.ZERO
var frame_moved := 0.0
var rng := RandomNumberGenerator.new()


func setup(combat_director: Node, survivor: CharacterBody3D, at: Vector3, route: Array[Vector3], gun: String) -> void:
	director = combat_director
	player = survivor
	waypoints = route
	weapon = gun
	position = at
	rng.randomize()
	perceive_in = rng.randf_range(0.0, 0.25)
	wait_time = rng.randf_range(0.0, 3.0)


func _ready() -> void:
	add_to_group("enemy")
	collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.92
	add_child(collision)
	floor_snap_length = 0.3
	visual = Node3D.new()
	add_child(visual)
	var model: Node3D = load("res://assets/characters/survivor.glb").instantiate()
	visual.add_child(model)
	var bounds := AssetFactory.mesh_bounds(model)
	var factor := 1.8 / bounds.size.y
	model.scale *= factor
	model.position.y = -bounds.position.y * factor
	tint(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in ["Idle", "Walk", "Run"]:
		if animation.has_animation(clip):
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if animation.has_animation("Death"):
		animation.get_animation("Death").loop_mode = Animation.LOOP_NONE
	armed = ArmedBody.new(animation, model, visual)
	armed.set_weapon(weapon)
	visual.rotation.y = rng.randf_range(-PI, PI)
	play("Idle")
	pick_waypoint()


# Soldiers share the survivor's model; a cold, darker overlay sets them apart.
func tint(model: Node) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = Color(0.16, 0.2, 0.17, 0.5)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = overlay


func play(clip: String, blend := 0.25) -> void:
	if clip == motion or not animation.has_animation(clip):
		return
	animation.play(clip, blend)
	motion = clip


func is_alert() -> bool:
	return state == "combat" or aware >= 0.6


func pick_waypoint() -> void:
	if waypoints.is_empty():
		goal = global_position
		return
	# Nearby points further along the same road, so patrols follow the streets
	# (pickWaypoint); off the road, walk back to the closest road point first.
	var options: Array[Vector3] = []
	var closest := waypoints[0]
	for point in waypoints:
		var distance := point.distance_to(global_position)
		if distance < closest.distance_to(global_position):
			closest = point
		if distance > 6.0 and distance < 60.0 and director.on_same_road(point, global_position):
			options.append(point)
	goal = options[rng.randi() % options.size()] if not options.is_empty() else closest
	goal += Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))


func hear(at: Vector3) -> void:
	if not alive or state == "combat":
		return
	state = "investigate"
	goal = at + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
	aware = maxf(aware, 0.55)
	wait_time = 0.0


# Returns true when this hit killed the soldier.
func take_hit(damage: float, head: bool, at: Vector3) -> bool:
	if not alive:
		return false
	hp -= damage
	director.blood(at)
	if hp <= 0.0:
		die(head)
		return true
	state = "combat"
	aware = 1.0
	last_known = player.global_position
	lost_time = 0.0
	cooldown = maxf(cooldown, rng.randf_range(0.3, 0.7))
	return false


func die(head: bool) -> void:
	alive = false
	velocity = Vector3.ZERO
	collision.disabled = true
	play("Death", 0.15)
	animation.speed_scale = 1.0
	director.enemy_killed(self, head)
	var round_kind := "ammo762" if weapon == "rifle" else "ammo9"
	loot = [[round_kind, rng.randi_range(8, 22) if weapon == "rifle" else rng.randi_range(5, 12)]]
	loot.append([weapon, rng.randi_range(10, 30) if weapon == "rifle" else rng.randi_range(4, 12)])
	if rng.randf() < 0.25:
		loot.append(["shell", rng.randi_range(3, 7)])
	if rng.randf() < 0.3:
		loot.append(["bandage", 1])
	if rng.randf() < 0.25:
		loot.append(["knife", 1])


func sees_player(distance: float) -> bool:
	if not player.alive:
		return false
	var conditions: Dictionary = director.conditions
	var reach: float = 11.0 + 27.0 * conditions.get("daylight", 1.0)
	if player.light.visible:
		reach = maxf(reach, 50.0)
	reach *= clampf(conditions.get("visibility", 120.0) / 120.0, 0.4, 1.1)
	if player.sprinting:
		reach *= 1.15
	if player.stance == "crouch":
		reach *= 0.7
	elif player.stance == "prone":
		reach *= 0.45
	if distance > reach:
		return false
	var to_player := (player.global_position - global_position) / distance
	var facing := visual.global_basis.z
	if distance > 3.5 and Vector2(facing.x, facing.z).normalized().dot(Vector2(to_player.x, to_player.z).normalized()) < 0.3:
		return false
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var target: Vector3 = player.global_position + Vector3(0, player.camera_height * 0.85, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if not director or director.paused():
		return
	if not alive:
		animation.advance(delta)
		armed.update(delta, false, global_position)
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := maxf(offset.length(), 0.01)
	# How far last frame's step actually carried the soldier.
	frame_moved = Vector2(global_position.x - last_position.x, global_position.z - last_position.z).length()
	last_position = global_position
	perceive_in -= delta
	if perceive_in <= 0.0:
		perceive_in = 0.25
		can_see = sees_player(distance)
		if can_see:
			aware += 0.25 * (3.0 if distance < 8.0 else (1.4 if distance < 18.0 else 0.8)) * (1.4 if player.light.visible else 1.0) * (1.3 if player.sprinting else 1.0)
		else:
			aware = maxf(0.0, aware - 0.02)
	if aware >= 1.0 and state != "combat":
		state = "combat"
		last_known = player.global_position
		lost_time = 0.0
		cooldown = rng.randf_range(0.5, 1.1)
		if not spotted:
			spotted = true
			director.say("Bir asker seni fark etti!")
	var moving_speed := 0.0
	var face_target := Vector3.ZERO
	var aiming := false
	match state:
		"patrol":
			if can_see and aware > 0.25:
				face_target = player.global_position
			elif wait_time > 0.0:
				wait_time -= delta
			elif steer(goal, PATROL_SPEED, delta):
				wait_time = rng.randf_range(2.0, 5.0)
				pick_waypoint()
			else:
				moving_speed = PATROL_SPEED
		"investigate":
			if wait_time > 0.0:
				wait_time -= delta
				visual.rotation.y += delta * 1.1
				if wait_time <= 0.0:
					state = "patrol"
					pick_waypoint()
			elif steer(goal, INVESTIGATE_SPEED, delta):
				wait_time = rng.randf_range(4.0, 7.0)
			else:
				moving_speed = INVESTIGATE_SPEED
		"combat":
			aiming = true
			if can_see:
				last_known = player.global_position
				lost_time = 0.0
				face_target = player.global_position
				if distance > 20.0:
					steer(player.global_position, CHASE_SPEED, delta)
					moving_speed = CHASE_SPEED
				elif distance < 5.0:
					steer(global_position - offset, 2.4, delta)
					moving_speed = 2.4
				cooldown -= delta
				if cooldown <= 0.0 and distance < 48.0:
					shoot(distance)
			else:
				lost_time += delta
				cooldown = maxf(cooldown, 0.4)
				var arrived := steer(last_known, 3.2, delta)
				moving_speed = 0.0 if arrived else 3.2
				if lost_time > 10.0 or (arrived and lost_time > 3.0):
					state = "investigate"
					goal = global_position
					wait_time = rng.randf_range(5.0, 8.0)
					aware = 0.5
					spotted = false
	if moving_speed <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	move_and_slide()
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if face_target != Vector3.ZERO:
		var look := face_target - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(look.x, look.z), minf(1.0, delta * 7.0))
	elif ground_speed > 0.2:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(velocity.x, velocity.z), minf(1.0, delta * 6.0))
	var clip := "Idle" if ground_speed < 0.2 else ("Run" if ground_speed > 2.3 else "Walk")
	play(clip)
	animation.speed_scale = clampf(ground_speed / CLIP_SPEED[clip], 0.6, 1.5) if CLIP_SPEED.has(clip) else 1.0
	animation.advance(delta)
	armed.update(delta, aiming, player.global_position + Vector3(0, player.camera_height * 0.85, 0))


# Moves toward a point and side-steps when blocked (moveEnemy). Returns true on arrival.
func steer(target: Vector3, speed: float, delta: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return true
	var direction := to.normalized()
	if side_time > 0.0:
		side_time -= delta
		direction = (direction * 0.25 + Vector3(-direction.z, 0, direction.x) * side_direction).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	check_progress(speed, delta)
	return false


# Blocked for a moment: slide sideways for a second or two (stuckT / sideT).
func check_progress(speed: float, delta: float) -> void:
	if frame_moved < speed * delta * 0.35:
		stuck_time += delta
		if stuck_time > 0.35:
			side_time = rng.randf_range(0.8, 1.8)
			side_direction = -1.0 if rng.randf() < 0.5 else 1.0
			stuck_time = 0.0
	else:
		stuck_time = 0.0


func shoot(distance: float) -> void:
	if weapon == "rifle":
		if burst <= 0:
			burst = rng.randi_range(2, 4)
		burst -= 1
		cooldown = 0.13 if burst > 0 else rng.randf_range(0.9, 1.7)
	else:
		cooldown = rng.randf_range(0.6, 1.2)
	var muzzle := armed.muzzle_position()
	director.muzzle_flash(muzzle)
	var accuracy := 0.72 - distance * 0.017
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
		accuracy -= 0.14
	if player.sprinting:
		accuracy -= 0.1
	if director.conditions.get("daylight", 1.0) < 0.3 and not player.light.visible:
		accuracy -= 0.15
	if player.stance == "crouch":
		accuracy -= 0.12
	elif player.stance == "prone":
		accuracy -= 0.22
	if not player.is_on_floor():
		accuracy -= 0.1
	accuracy = clampf(accuracy, 0.05, 0.75)
	var target: Vector3 = player.global_position + Vector3(0, player.camera_height * 0.85, 0)
	if rng.randf() < accuracy:
		director.tracer(muzzle, target)
		var damage := rng.randf_range(7.0, 12.0) if weapon == "rifle" else rng.randf_range(6.0, 10.0)
		director.hurt_player(damage, "Düşman ateşi", global_position)
		if rng.randf() < 0.28 and not player.bleeding:
			player.bleeding = true
			director.say("Kanaman var. Sargı sar (H).")
	else:
		target += Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-0.8, 1.2), rng.randf_range(-1.8, 1.8))
		director.tracer(muzzle, target)
	director.alert_noise(global_position, 35.0)
