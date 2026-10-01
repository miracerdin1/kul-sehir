extends CharacterBody3D

const AssetFactory = preload("res://scripts/asset_factory.gd")
const WALK_SPEED := 2.6
const RUN_SPEED := 5.0
const GRAVITY := 18.0

var active := false
var stamina := 100.0
var warmth := 72.0
var visual: Node3D
var animation: AnimationPlayer
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var light: SpotLight3D
var yaw := 0.0
var pitch := -0.13
var step_distance := 0.0
var footstep: AudioStreamPlayer3D
var exhausted := false


func _ready() -> void:
	name = "Survivor"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
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
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		play_motion("Idle")
	create_camera()
	footstep = AudioStreamPlayer3D.new()
	footstep.stream = load("res://assets/audio/footstep.wav")
	footstep.volume_db = -13.0
	footstep.max_distance = 12.0
	add_child(footstep)


func create_camera() -> void:
	pivot = Node3D.new()
	pivot.position = Vector3(0.5, 1.5, 0.0)
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


func _physics_process(delta: float) -> void:
	if not active:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var moving := direction.length_squared() > 0.01
	if stamina <= 1.0:
		exhausted = true
	if stamina >= 25.0:
		exhausted = false
	var running := moving and Input.is_action_pressed("sprint") and not exhausted
	var speed := RUN_SPEED if running else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and stamina >= 10.0:
		velocity.y = 5.2
		stamina -= 10.0
	move_and_slide()
	stamina = clampf(stamina + (-16.0 if running else 11.0) * delta, 0.0, 100.0)
	if moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 12.0)
		step_distance += Vector2(velocity.x, velocity.z).length() * delta
		if is_on_floor() and step_distance > (1.5 if running else 1.1):
			step_distance = 0.0
			footstep.pitch_scale = randf_range(0.85, 1.1)
			footstep.play()
	play_motion("Run" if running else ("Walk" if moving else "Idle"))
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	update_camera_collision()
	camera.fov = lerpf(camera.fov, 71.0 if running else 66.0, delta * 4.0)
	visual.visible = arm.get_hit_length() > 0.65
	if position.y < -8.0:
		position = Vector3(0.0, 0.5, 15.0)
		velocity = Vector3.ZERO


func update_camera_collision() -> void:
	var eye := global_position + Vector3(0, 1.5, 0)
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


func play_motion(motion: String) -> void:
	if not animation:
		return
	for clip in animation.get_animation_list():
		if clip.to_lower() == motion.to_lower() or clip.to_lower().ends_with("/" + motion.to_lower()):
			if animation.current_animation != clip:
				animation.play(clip, 0.22)
			return
