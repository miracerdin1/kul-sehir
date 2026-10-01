extends Node3D
## Camera-local precipitation. Roof sampling prevents indoor precipitation.

var rain: GPUParticles3D
var snow: GPUParticles3D
var sheltered := false
var roof_check_remaining := 0.0


func _ready() -> void:
	rain = make_particles(420, Vector2(0.014, 0.65), Color(0.7, 0.8, 0.85, 0.35), 1.6, 12.0)
	snow = make_particles(320, Vector2(0.045, 0.045), Color(0.9, 0.93, 0.95, 0.8), 7.0, 1.5)


func make_particles(count: int, size: Vector2, color: Color, lifetime: float, speed: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime
	particles.preprocess = 0.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-14, -18, -14), Vector3(28, 35, 28))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(10, 3, 10)
	process.direction = Vector3.DOWN
	process.spread = 8.0
	process.initial_velocity_min = speed
	process.initial_velocity_max = speed * 1.2
	process.gravity = Vector3(0, -0.5, 0)
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	material.albedo_texture = texture
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = false
	return particles


func update_weather(delta: float, camera: Camera3D, values: Dictionary, active: bool, low_quality: bool) -> void:
	rain.speed_scale = 1.0 if active else 0.0
	snow.speed_scale = rain.speed_scale
	if not active or not is_instance_valid(camera):
		return
	global_position = camera.global_position + Vector3(0, 8, 0)
	roof_check_remaining -= delta
	if roof_check_remaining <= 0.0:
		roof_check_remaining = 0.2
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + Vector3.UP * 20.0)
		sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	apply_strength(rain, float(values.rain), low_quality)
	apply_strength(snow, float(values.snow), low_quality)
	var wind := float(values.wind)
	(rain.process_material as ParticleProcessMaterial).gravity = Vector3(wind * 3, -0.5, 0)
	(snow.process_material as ParticleProcessMaterial).gravity = Vector3(wind * 1.2, -0.5, 0)


func apply_strength(particles: GPUParticles3D, strength: float, low_quality: bool) -> void:
	particles.visible = not sheltered and strength > 0.01
	particles.emitting = particles.visible
	particles.amount_ratio = clampf(strength * (0.5 if low_quality else 1.0), 0.0, 1.0)
