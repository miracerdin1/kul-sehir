extends CharacterBody3D

const AssetFactory = preload("res://scripts/asset_factory.gd")
# Speeds follow the HTML reference (jog 3.5, sprint 6.4, crouch and prone slower),
# tuned so each clip plays near its natural pace and the feet do not slide.
const WALK_SPEED := 1.6
const RUN_SPEED := 3.3
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.3
const PRONE_SPEED := 0.55
const GRAVITY := 16.0
const JUMP_VELOCITY := 5.6
const JUMP_STAMINA := 6.0
# Ground speed (m/s) at which each locomotion clip plays at 1x, measured from the
# planted foot of the Mixamo source clip.
const CLIP_SPEED := {"Walk": 1.65, "Run": 3.0, "Sprint": 5.9, "CrouchWalk": 1.22, "Crawl": 0.45}
const LOOPING := ["Idle", "Walk", "Run", "Sprint", "CrouchIdle", "CrouchWalk", "Crawl"]
# JumpAir runs from take-off to touch-down; it is stretched over the real time in the air.
const JUMP_AIR_TIME := 2.0 * JUMP_VELOCITY / GRAVITY
const LAND_TIME := 0.35
# Capsule height and camera pivot height for each stance.
const STANCE_HEIGHT := {"stand": 1.75, "crouch": 1.2, "prone": 0.6}
const STANCE_CAMERA := {"stand": 1.5, "crouch": 1.05, "prone": 0.6}
const CAPSULE_RADIUS := 0.28

var active := false
var stamina := 100.0
var warmth := 72.0
var stance := "stand"
var visual: Node3D
var animation: AnimationPlayer
var collision: CollisionShape3D
var capsule: CapsuleShape3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var light: SpotLight3D
var yaw := 0.0
var pitch := -0.13
var camera_height := 1.5
var step_distance := 0.0
var footstep: AudioStreamPlayer3D
var exhausted := false
var sprinting := false
var air_time := 0.0
var jumped := false
var land_time := 0.0
var action_time := 0.0
var still_time := 0.0
var motion := ""


func _ready() -> void:
	name = "Survivor"
	collision = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	collision.shape = capsule
	add_child(collision)
	apply_stance_shape("stand")
	floor_snap_length = 0.3
	visual = Node3D.new()
	add_child(visual)
	var packed: PackedScene = load("res://assets/characters/survivor.glb")
	var model: Node3D = packed.instantiate()
	visual.add_child(model)
	var bounds := AssetFactory.mesh_bounds(model)
	var factor := 1.78 / bounds.size.y
	model.scale *= factor
	model.position.y = -bounds.position.y * factor
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation:
		for clip in animation.get_animation_list():
			var looped := clip_name(clip) in LOOPING
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		play_motion("Idle")
	create_camera()
	footstep = AudioStreamPlayer3D.new()
	footstep.stream = load("res://assets/audio/footstep.wav")
	footstep.volume_db = -13.0
	footstep.max_distance = 12.0
	add_child(footstep)


func create_camera() -> void:
	pivot = Node3D.new()
	pivot.position = Vector3(0.5, camera_height, 0.0)
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 3.8
	arm.margin = 0.18
	var shape := SphereShape3D.new()
	shape.radius = 0.16
	arm.shape = shape
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.08
	camera.far = 140.0
	camera.current = true
	arm.add_child(camera)
	light = SpotLight3D.new()
	light.light_color = Color("efdfbf")
	light.light_energy = 3.5
	light.spot_range = 22.0
	light.spot_angle = 24.0
	light.visible = false
	camera.add_child(light)
	pivot.rotation = Vector3(pitch, yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -0.75, 0.5)
	if event.is_action_pressed("flashlight"):
		light.visible = not light.visible
	if event.is_action_pressed("crouch"):
		set_stance("stand" if stance == "crouch" else "crouch")
	if event.is_action_pressed("prone"):
		set_stance("stand" if stance == "prone" else "prone")


func set_stance(next: String) -> bool:
	if next == stance:
		return true
	if next != "stand" and not is_on_floor():
		return false
	if STANCE_HEIGHT[next] > STANCE_HEIGHT[stance] and not has_headroom(next):
		return false
	stance = next
	apply_stance_shape(next)
	return true


func apply_stance_shape(which: String) -> void:
	capsule.height = STANCE_HEIGHT[which]
	collision.position.y = STANCE_HEIGHT[which] / 2.0 + 0.025


func has_headroom(which: String) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS - 0.02
	shape.height = STANCE_HEIGHT[which] - 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STANCE_HEIGHT[which] / 2.0 + 0.1, 0))
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# A one-off action such as picking something up roots the character in place.
	action_time = maxf(0.0, action_time - delta)
	if action_time > 0.0:
		input = Vector2.ZERO
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var moving := direction.length_squared() > 0.01
	if stamina <= 0.5:
		exhausted = true
	if exhausted and stamina >= 25.0:
		exhausted = false
	# Sprinting or jumping from a lowered stance stands the character up first.
	var wants_sprint := moving and Input.is_action_pressed("sprint") and not exhausted
	if wants_sprint and stance != "stand":
		set_stance("stand")
	sprinting = wants_sprint and stance == "stand"
	var speed := move_speed(Input.is_action_pressed("walk"))
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and action_time <= 0.0:
		if stance != "stand":
			set_stance("stand")
		elif stamina >= JUMP_STAMINA:
			velocity.y = JUMP_VELOCITY
			stamina -= JUMP_STAMINA
			jumped = true
			land_time = 0.0
			play_motion("JumpAir", 0.08)
	move_and_slide()
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var stamina_rate := -6.5 if sprinting and ground_speed > 0.5 else (10.0 if exhausted else (13.0 if ground_speed > 0.2 else 18.0))
	stamina = clampf(stamina + stamina_rate * delta, 0.0, 100.0)
	if moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 12.0)
	if is_on_floor():
		# Only a real fall or jump earns a landing; stepping off a kerb does not.
		if (jumped or air_time > 0.3) and ground_speed < 1.2 and velocity.y <= 0.0:
			land_time = LAND_TIME
		if velocity.y <= 0.0:
			jumped = false
		air_time = 0.0
	else:
		air_time += delta
	land_time = maxf(0.0, land_time - delta)
	if is_on_floor() and ground_speed > 0.2:
		step_distance += ground_speed * delta
		if step_distance > stride_length():
			step_distance = 0.0
			footstep.volume_db = -19.0 if stance != "stand" else -13.0
			footstep.pitch_scale = randf_range(0.85, 1.1)
			footstep.play()
	update_animation(ground_speed, delta)
	camera_height = lerpf(camera_height, STANCE_CAMERA[stance], minf(1.0, delta * 8.0))
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	update_camera_collision()
	camera.fov = lerpf(camera.fov, 72.0 if sprinting and ground_speed > 0.5 else 66.0, delta * 4.0)
	visual.visible = arm.get_hit_length() > 0.65
	if position.y < -8.0:
		position = Vector3(0.0, 0.5, 15.0)
		velocity = Vector3.ZERO


func move_speed(walking: bool) -> float:
	if stance == "prone":
		return PRONE_SPEED
	if stance == "crouch":
		return CROUCH_SPEED
	if sprinting:
		return SPRINT_SPEED
	return WALK_SPEED if walking or exhausted else RUN_SPEED


func stride_length() -> float:
	match motion:
		"Sprint":
			return 1.6
		"Run":
			return 1.25
		"Crawl":
			return 0.5
	return 0.8


# Animation follows how fast the body actually moves, not which keys are held,
# so pushing against a wall idles instead of running in place.
func update_animation(ground_speed: float, delta: float) -> void:
	if not animation:
		return
	if action_time > 0.0:
		return
	var next := "Idle"
	if jumped or air_time > 0.2:
		next = "JumpAir"
	elif land_time > 0.0 and ground_speed < 1.2:
		next = "JumpLand"
	elif stance == "prone":
		next = "Crawl"
	elif stance == "crouch":
		next = "CrouchWalk" if ground_speed > 0.2 else "CrouchIdle"
	elif ground_speed > 0.2:
		if ground_speed > (RUN_SPEED + SPRINT_SPEED) / 2.0:
			next = "Sprint"
		elif ground_speed > (WALK_SPEED + RUN_SPEED) / 2.0:
			next = "Run"
		else:
			next = "Walk"
	still_time = still_time + delta if ground_speed <= 0.2 else 0.0
	if next == "JumpAir" and motion != "JumpAir":
		# Walked off a ledge: join the jump clip on its way down.
		play_motion(next, 0.15)
		animation.seek(animation.current_animation_length * 0.55, true)
	play_motion(next, 0.1 if motion in ["JumpAir", "JumpLand"] else 0.25)
	if next == "JumpAir":
		animation.speed_scale = animation.current_animation_length / JUMP_AIR_TIME
		return
	if next == "JumpLand":
		animation.speed_scale = animation.current_animation_length / LAND_TIME
		return
	if CLIP_SPEED.has(next):
		var clip_rate := clampf(ground_speed / CLIP_SPEED[next], 0.6, 1.5)
		# Lying still holds the crawl pose once the cross-fade has finished.
		if next == "Crawl" and ground_speed <= 0.2:
			clip_rate = 0.0 if still_time > 0.3 else 0.6
		animation.speed_scale = clip_rate
	else:
		animation.speed_scale = 1.0


func update_camera_collision() -> void:
	var eye := global_position + Vector3(0, camera_height, 0)
	var shoulder := Basis(Vector3.UP, yaw) * Vector3(0.5, 0, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, eye + shoulder.normalized() * 0.72)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	pivot.global_position = eye + shoulder if hit.is_empty() else hit.position + hit.normal * 0.22
	# A ray also catches walls overlapping the spring arm's initial sphere.
	var desired := pivot.global_position + pivot.global_basis.z * 3.8
	query.from = pivot.global_position
	query.to = desired
	hit = get_world_3d().direct_space_state.intersect_ray(query)
	arm.spring_length = 3.8 if hit.is_empty() else maxf(0.12, pivot.global_position.distance_to(hit.position) - 0.22)


func clip_name(clip: String) -> String:
	return clip.get_slice("/", clip.get_slice_count("/") - 1)


# Plays a one-off clip over the given time while movement waits.
func play_action(next: String, duration: float) -> void:
	if not animation:
		return
	action_time = duration
	velocity.x = 0.0
	velocity.z = 0.0
	motion = ""
	play_motion(next, 0.15)
	if motion == next:
		animation.speed_scale = animation.current_animation_length / duration


func busy() -> bool:
	return action_time > 0.0


func play_motion(next: String, blend := 0.25) -> void:
	if not animation or next == motion:
		return
	for clip in animation.get_animation_list():
		if clip_name(clip).to_lower() == next.to_lower():
			animation.play(clip, blend)
			motion = next
			return
