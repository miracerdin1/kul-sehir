extends Node
# The survivor's weapons: inventory, firing, reloading, melee and wounds.
# Numbers follow the HTML reference (attack, reload, setWeapon, bandage).

const Weapons = preload("res://scripts/combat/weapons.gd")

signal fired(weapon: String)
signal hit_enemy(head: bool, killed: bool)
signal message(text: String)

var player: CharacterBody3D
var director: Node
var owned := {"knife": false, "pistol": false, "shotgun": false, "rifle": false}
var ammo := {"ammo9": 0, "ammo762": 0, "shell": 0}
var magazine := {"pistol": 0, "shotgun": 0, "rifle": 0}
var bandages := 1
var weapon := "fists"
var cooldown := 0.0
var reload_left := 0.0
var trigger_held := false
var aim_held := false
var rng := RandomNumberGenerator.new()


func setup(survivor: CharacterBody3D, combat_director: Node) -> void:
	player = survivor
	director = combat_director
	rng.randomize()


func _unhandled_input(event: InputEvent) -> void:
	if not player or not player.active:
		trigger_held = false
		aim_held = false
		return
	if event.is_action_pressed("fire"):
		trigger_held = true
		attack()
	elif event.is_action_released("fire"):
		trigger_held = false
	if event.is_action_pressed("aim"):
		aim_held = true
	elif event.is_action_released("aim"):
		aim_held = false
	if event.is_action_pressed("reload"):
		reload()
	if event.is_action_pressed("bandage"):
		bandage()
	for slot in 4:
		if event.is_action_pressed("weapon_%d" % (slot + 1)):
			select(["melee", "pistol", "shotgun", "rifle"][slot])
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			cycle(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)


func data() -> Dictionary:
	return Weapons.DATA[weapon]


func select(kind: String) -> bool:
	if kind == "melee":
		kind = "knife" if owned.knife else "fists"
	if kind != "fists" and not owned.get(kind, false):
		message.emit(Weapons.NAMES[kind] + " henüz yok.")
		return false
	if kind == weapon:
		return true
	weapon = kind
	reload_left = 0.0
	cooldown = 0.25
	return true


func cycle(step: int) -> void:
	var order := ["melee"]
	for kind in Weapons.GUNS:
		if owned[kind]:
			order.append(kind)
	var current := "melee" if data().get("melee", false) else weapon
	select(order[(order.find(current) + step + order.size()) % order.size()])


func give(kind: String, amount: int) -> bool:
	match kind:
		"knife":
			if owned.knife:
				return false
			owned.knife = true
			if weapon == "fists":
				weapon = "knife"
		"pistol", "shotgun", "rifle":
			var gun: Dictionary = Weapons.DATA[kind]
			if owned[kind]:
				ammo[gun.ammo] += amount
			else:
				owned[kind] = true
				magazine[kind] = mini(amount, gun.mag)
				ammo[gun.ammo] += maxi(0, amount - gun.mag)
				if data().get("melee", false) or kind == "rifle":
					select(kind)
		"bandage":
			bandages += amount
		_:
			if not ammo.has(kind):
				return false
			ammo[kind] += amount
	return true


# Lines for the bag screen.
func summary() -> Array[String]:
	var lines: Array[String] = []
	for kind in ["knife", "pistol", "shotgun", "rifle"]:
		if owned[kind]:
			var gun: Dictionary = Weapons.DATA[kind]
			lines.append(Weapons.NAMES[kind] + ("   %d / %d" % [magazine[kind], ammo[gun.ammo]] if gun.has("ammo") else ""))
	for kind in ammo:
		if ammo[kind] > 0 and not owned[{"ammo9": "pistol", "ammo762": "rifle", "shell": "shotgun"}[kind]]:
			lines.append(Weapons.label(kind, ammo[kind]))
	if bandages > 0:
		lines.append(Weapons.label("bandage", bandages))
	return lines


func reload() -> void:
	var gun := data()
	if gun.get("melee", false) or reload_left > 0.0 or magazine[weapon] >= gun.mag:
		return
	if ammo[gun.ammo] <= 0:
		message.emit("Yedek mermi yok.")
		return
	reload_left = gun.reload


func bandage() -> void:
	if bandages <= 0:
		message.emit("Sargı bezin yok.")
		return
	if player.hp >= 99.0 and not player.bleeding:
		message.emit("Yaran yok.")
		return
	bandages -= 1
	player.bleeding = false
	player.hp = minf(100.0, player.hp + 32.0)
	message.emit("Yarayı sardın. Kanama durdu.")


func aim_direction() -> Vector3:
	return -player.camera.global_basis.z


func attack() -> void:
	if not player.active or player.busy() or cooldown > 0.0 or reload_left > 0.0:
		return
	var gun := data()
	if gun.get("melee", false):
		melee(gun)
		return
	if magazine[weapon] <= 0:
		cooldown = 0.25
		if ammo[gun.ammo] > 0:
			reload()
		else:
			message.emit("Şarjör boş, mermi bul.")
		return
	magazine[weapon] -= 1
	cooldown = gun.rate
	var origin: Vector3 = player.camera.global_position
	var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.3
	var stance_factor: float = {"prone": 0.45, "crouch": 0.7}.get(player.stance, 1.0)
	var spread: float = gun.spread * (1.8 if moving else 1.0) * (1.0 if gun.has("pellets") else stance_factor)
	spread *= 1.0 if player.is_on_floor() else 2.5
	if not player.aim_mode():
		spread *= 1.6
	var muzzle: Vector3 = player.armed.muzzle_position() if player.armed else origin
	director.muzzle_flash(muzzle)
	director.alert_noise(player.global_position, gun.noise)
	for pellet in gun.get("pellets", 1):
		var direction := aim_direction()
		direction += Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		shoot_ray(origin, direction.normalized(), muzzle, gun, pellet < 3)
	player.pitch = clampf(player.pitch + gun.kick * stance_factor, -0.75, 0.5)
	player.yaw += rng.randf_range(-0.006, 0.006)
	fired.emit(weapon)


func shoot_ray(origin: Vector3, direction: Vector3, muzzle: Vector3, gun: Dictionary, draw: bool) -> void:
	var reach := 55.0 if gun.has("pellets") else 140.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if not hit.is_empty() else origin + direction * reach
	if draw:
		director.tracer(muzzle, end)
	if hit.is_empty():
		return
	var target: Object = hit.collider
	if target.is_in_group("enemy") and target.alive:
		var head: bool = end.y - target.global_position.y > 1.55
		var distance := origin.distance_to(end)
		var falloff := clampf(1.25 - distance / 30.0, 0.3, 1.0) if gun.has("pellets") else 1.0
		var damage: float = gun.damage * falloff * (2.3 if head else 1.0) * rng.randf_range(0.9, 1.1)
		var killed: bool = target.take_hit(damage, head, end)
		hit_enemy.emit(head, killed)
	else:
		director.impact(end, hit.normal)


func melee(gun: Dictionary) -> void:
	cooldown = gun.rate
	if player.armed:
		player.armed.strike()
	var forward := aim_direction()
	forward.y = 0.0
	forward = forward.normalized()
	player.visual.rotation.y = atan2(forward.x, forward.z)
	var best: Node3D
	var best_distance := 99.0
	for enemy in director.enemies:
		if not enemy.alive:
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > gun.range + 0.4 or (distance > 0.3 and forward.dot(offset / distance) < 0.58):
			continue
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		return
	var damage: float = gun.damage
	if not best.is_alert():
		if weapon == "knife":
			damage = 300.0
			message.emit("Sessiz infaz.")
		else:
			damage *= 1.6
	var killed: bool = best.take_hit(damage, false, best.global_position + Vector3(0, 1.3, 0))
	hit_enemy.emit(false, killed)


func _physics_process(delta: float) -> void:
	if not player or not player.active:
		return
	cooldown -= delta
	player.weapon = weapon
	player.aiming = aim_held or (trigger_held and Weapons.is_gun(weapon))
	if player.armed:
		player.armed.set_weapon(weapon)
	player.aim_target = aim_point()
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			var gun := data()
			var take: int = mini(gun.mag - magazine[weapon], ammo[gun.ammo])
			magazine[weapon] += take
			ammo[gun.ammo] -= take
	if trigger_held and data().get("auto", false):
		attack()
	var gun := data()
	if not gun.get("melee", false) and reload_left <= 0.0 and cooldown <= 0.0 and magazine[weapon] == 0 and ammo[gun.ammo] > 0:
		reload()


func aim_point() -> Vector3:
	var origin: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + aim_direction() * 80.0)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else origin + aim_direction() * 80.0
