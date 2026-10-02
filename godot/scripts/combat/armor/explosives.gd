extends Node3D

const Charge = preload("res://scripts/combat/armor/explosive_charge.gd")
var director: Node3D
static var boom: AudioStreamWAV


func launch(origin: Vector3, direction: Vector3) -> Node3D:
	var rocket := Charge.new()
	rocket.service = self
	rocket.direction = direction.normalized()
	add_child(rocket)
	rocket.global_position = origin
	rocket.look_at(origin + rocket.direction, Vector3.RIGHT if absf(rocket.direction.y) > 0.95 else Vector3.UP)
	return rocket


func place_mine() -> bool:
	var player: CharacterBody3D = director.player
	var combat: Node = director.combat
	if not player.active or player.busy() or not player.is_on_floor() or combat.mines <= 0:
		return false
	var active := get_tree().get_nodes_in_group("explosive_charge")
	if active.filter(func(item): return item.mine and not item.spent).size() >= 8:
		director.say("En fazla 8 mayın kurabilirsin.")
		return false
	var forward: Vector3 = -player.camera.global_basis.z
	forward.y = 0.0
	var from := player.global_position + Vector3.UP * 0.7
	var to: Vector3 = from + forward.normalized() * 1.3
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(query).is_empty():
		return false
	query.from = to
	query.to = to + Vector3.DOWN * 1.6
	var floor_hit := space.intersect_ray(query)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.85:
		return false
	for item in active:
		if item.global_position.distance_to(floor_hit.position) < 0.8:
			return false
	var mine := Charge.new()
	mine.mine = true
	mine.service = self
	add_child(mine)
	mine.global_position = floor_hit.position + Vector3.UP * 0.05
	combat.mines -= 1
	director.say("Mayın kuruldu: 2 saniye sonra etkin. Uzaklaş!")
	return true


func visible_from(origin: Vector3, target: Object, point: Vector3, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target


func explode(at: Vector3, damage: float, radius: float, exclude: Array[RID] = []) -> void:
	director.alert_noise(at, 75.0)
	for vehicle in get_tree().get_nodes_in_group("armored_vehicle"):
		var point: Vector3 = vehicle.blast_target()
		if not vehicle.destroyed and point.distance_to(at) < radius and visible_from(at, vehicle, point, exclude):
			if vehicle.take_explosion(damage):
				director.say(("Tank" if vehicle.kind == "tank" else "ZPT") + " imha edildi.")
	for target in director.enemies + [director.player]:
		var point: Vector3 = target.global_position + Vector3.UP
		var distance := point.distance_to(at)
		if not target.alive or distance >= radius or not visible_from(at, target, point, exclude):
			continue
		var amount := damage * (1.0 - distance / radius)
		if target == director.player:
			director.hurt_player(amount, "Patlama", at)
		else:
			target.take_hit(amount, false, point)
	for window in get_tree().get_nodes_in_group("breakable_glass"):
		if not window.broken and window.global_position.distance_to(at) < radius and visible_from(at, window, window.global_position, exclude):
			window.shatter(window.global_position - at)
	show_blast(at)


func show_blast(at: Vector3) -> void:
	var effect := Node3D.new()
	effect.position = at
	director.add_effect(effect, 2.1)
	var material: Material = director.glow(Color(1.0, 0.4, 0.06, 0.8))
	var flash: MeshInstance3D = director.sphere(0.5, material)
	effect.add_child(flash)
	var flare := flash.create_tween().set_parallel()
	flare.tween_property(flash, "scale", Vector3.ONE * 7.0, 0.4)
	flare.tween_property(material, "albedo_color:a", 0.0, 0.45)
	var smoke: MeshInstance3D = director.sphere(0.8, director.glow(Color(0.15, 0.14, 0.12, 0.65), false))
	effect.add_child(smoke)
	var tween := smoke.create_tween().set_parallel()
	tween.tween_property(smoke, "position:y", 3.0, 1.9)
	tween.tween_property(smoke, "scale", Vector3.ONE * 3.0, 1.9)
	tween.tween_property(smoke.material_override, "albedo_color:a", 0.0, 1.9)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = explosion_sound()
	sound.position = at
	sound.max_distance = 80.0
	sound.volume_db = -6.0
	director.add_effect(sound, 1.0)
	sound.play()


static func explosion_sound() -> AudioStreamWAV:
	if boom != null:
		return boom
	var bytes := PackedByteArray()
	bytes.resize(22050)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for index in range(11025):
		var t := float(index) / 22050.0
		var wave := (rng.randf_range(-0.45, 0.45) + sin(t * 360.0) * 0.5) * exp(-t * 8.0)
		bytes.encode_s16(index * 2, int(wave * 30000.0))
	boom = AudioStreamWAV.new()
	boom.format = AudioStreamWAV.FORMAT_16_BITS
	boom.mix_rate = 22050
	boom.data = bytes
	return boom
