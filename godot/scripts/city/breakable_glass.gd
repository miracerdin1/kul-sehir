extends StaticBody3D
# Panes share one MultiMesh per block; breaking one only hides its own instance.

signal shattered(at: Vector3)

static var break_sound: AudioStreamWAV
static var shard_material: StandardMaterial3D

var broken := false
var pane_size := Vector2.ONE
var batch: MultiMesh
var slot := 0
var shape: CollisionShape3D


func setup(size: Vector2, instances: MultiMesh, index: int) -> void:
	pane_size = size
	batch = instances
	slot = index
	add_to_group("breakable_glass")
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.035)
	shape.shape = box
	add_child(shape)


func shatter(direction: Vector3) -> bool:
	if broken:
		return false
	broken = true
	collision_layer = 0
	collision_mask = 0
	shape.set_deferred("disabled", true)
	batch.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	shattered.emit(global_position)
	create_fragments(direction)
	return true


func create_fragments(direction: Vector3) -> void:
	var effect := Node3D.new()
	get_tree().current_scene.add_child(effect)
	effect.global_transform = global_transform
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 0.85
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(pane_size.x * 0.45, pane_size.y * 0.45, 0.02)
	particles.direction = global_basis.inverse() * direction.normalized()
	particles.spread = 65.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	var shard := PrismMesh.new()
	shard.size = Vector3(0.075, 0.12, 0.012)
	if shard_material == null:
		shard_material = StandardMaterial3D.new()
		shard_material.albedo_color = Color("a1c1c5")
		shard_material.metallic = 0.45
		shard_material.roughness = 0.18
	shard.material = shard_material
	particles.mesh = shard
	effect.add_child(particles)
	particles.emitting = true
	var sound := AudioStreamPlayer3D.new()
	sound.stream = glass_sound()
	sound.volume_db = -12.0
	sound.max_distance = 24.0
	effect.add_child(sound)
	sound.play()
	get_tree().create_timer(1.2).timeout.connect(effect.queue_free)


static func glass_sound() -> AudioStreamWAV:
	if break_sound != null:
		return break_sound
	var sample_rate := 22050
	var count := int(sample_rate * 0.38)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 718
	for index in range(count):
		var time := float(index) / sample_rate
		var noise := random.randf_range(-1.0, 1.0) * exp(-time * 20.0)
		var ring := (sin(time * 17800.0) + sin(time * 24300.0)) * 0.18 * exp(-time * 12.0)
		bytes.encode_s16(index * 2, int(clampf(noise + ring, -1.0, 1.0) * 22000.0))
	break_sound = AudioStreamWAV.new()
	break_sound.format = AudioStreamWAV.FORMAT_16_BITS
	break_sound.mix_rate = sample_rate
	break_sound.data = bytes
	return break_sound
