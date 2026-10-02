extends RefCounted
# Patrolling armour, vaulting through windows and over low walls, quick pickups,
# and the glass sound.

const BreakableGlass = preload("res://scripts/city/breakable_glass.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	await check_pickup(game, qa)
	await check_vault(game, qa)
	await check_vehicles(game, qa)
	qa.check(BreakableGlass.glass_sound().get_length() > 1.0, "Breaking glass plays the full shatter")


func check_pickup(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	await qa.frames(game, 10)
	var item: Dictionary = game.director.add_pickup("food", 1, Vector3(0.6, 0.06, 9.6))
	await qa.frames(game, 2)
	game.interact()
	var waited := 0
	while player.busy() and waited < 200:
		await qa.frames(game, 1)
		waited += 1
	qa.check(item.taken and waited <= 48, "Picking an item up takes under a second (%d frames)" % waited)


# Through a ground-floor window of a house on the first street: the glass breaks,
# the survivor goes over the sill and lands inside on their feet.
func check_vault(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	var pane: StaticBody3D = null
	var front := Vector3.ZERO
	for window: StaticBody3D in game.city.windows:
		if window.broken or window.global_position.y > 2.5 or Vector2(window.global_position.x, window.global_position.z).length() > 30.0:
			continue
		for side in [1.0, -1.0]:
			var normal: Vector3 = window.global_basis.z.normalized() * side
			player.position = Vector3(window.global_position.x, 0.1, window.global_position.z) + normal * 0.75
			player.velocity = Vector3.ZERO
			player.yaw = atan2(normal.x, normal.z)
			await qa.frames(game, 6)
			var ledge: Dictionary = player.find_vault()
			if not ledge.is_empty() and ledge.glass == window:
				pane = window
				front = normal
				break
		if pane:
			break
	qa.check(pane != null, "A closed ground-floor window can be vaulted through")
	if pane == null:
		return
	Input.action_press("jump")
	await qa.frames(game, 2)
	Input.action_release("jump")
	qa.check(player.vaulting() and player.motion == "Vault", "Space at the window starts the vault, got " + player.motion)
	qa.check(pane.broken, "Vaulting into the glass breaks it")
	await qa.frames(game, 30)
	var flat: Vector3 = player.position - pane.global_position
	flat.y = 0.0
	qa.check(player.vaulting() and flat.length() < 1.0, "Halfway the survivor is at the sill (%.2f m)" % flat.length())
	await qa.frames(game, 50)
	var side: float = (player.position - pane.global_position).dot(front)
	qa.check(not player.vaulting() and side < -0.4, "The vault lands on the far side (%.2f)" % side)
	await qa.frames(game, 10)
	qa.check(player.is_on_floor() and not player.collision.disabled, "The survivor lands on their feet with collision back")
	# A full-height wall is not a vault.
	player.position = Vector3(-6.1, 0.1, -2.0)
	player.velocity = Vector3.ZERO
	player.yaw = PI / 2.0
	await qa.frames(game, 6)
	qa.check(player.find_vault().is_empty(), "A tall wall cannot be vaulted")
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	await qa.frames(game, 10)


# The city's tanks and carriers drive the roads, their wheels and tracks turn,
# and they keep out of the first street.
func check_vehicles(game: Node3D, qa: RefCounted) -> void:
	var vehicles: Array = game.get_tree().get_nodes_in_group("armored_vehicle").filter(func(vehicle): return vehicle.city != null)
	qa.check(vehicles.size() == 4, "Four armoured vehicles patrol the city")
	var start := {}
	for vehicle in vehicles:
		vehicle.wait = 0.0
		start[vehicle] = vehicle.global_position
	var player = game.player
	player.position = Vector3(0, 0.2, 10)
	await qa.frames(game, 900)
	var moved := 0
	var street_clear := true
	for vehicle in vehicles:
		if vehicle.global_position.distance_to(start[vehicle]) > 4.0:
			moved += 1
		if game.city.STREET_AREA.has_point(Vector2(vehicle.global_position.x, vehicle.global_position.z)):
			street_clear = false
	qa.check(moved >= 3, "Armour drives along the roads (%d of %d moved)" % [moved, vehicles.size()])
	qa.check(street_clear, "Armour keeps out of the first street")
	var tank = vehicles.filter(func(vehicle): return vehicle.kind == "tank")[0]
	var wheel: Node3D = tank.parts.wheels[0].node
	qa.check(absf(tank.travel[0]) > 1.0 and absf(wheel.rotation.x) > 0.01 and tank.parts.tracks[0].uv1_offset.x != 0.0, "Tank wheels turn and tracks run as it drives")
	qa.check(tank.engine.playing, "Tank engine is running")
	var body: Vector3 = PhysicsServer3D.body_get_state(tank.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM).origin
	qa.check(body.distance_to(tank.global_position) < 0.1, "Tank collision follows the tank")


# Pictures of both vehicle types up close and of a vault over a sill.
func capture(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	for kind in ["tank", "apc"]:
		var vehicle = game.get_tree().get_nodes_in_group("armored_vehicle").filter(func(item): return item.kind == kind and item.city != null)[0]
		vehicle.wait = 30.0
		var side: Vector3 = vehicle.global_basis.x * 7.5 - vehicle.global_basis.z * 4.0
		player.position = vehicle.global_position + side + Vector3(0, 0.2, 0)
		player.velocity = Vector3.ZERO
		var look: Vector3 = vehicle.global_position + Vector3(0, 1.4, 0) - (player.position + Vector3(0, 1.5, 0))
		player.yaw = atan2(-look.x, -look.z) + 0.25
		player.pitch = -0.08
		await qa.frames(game, 40)
		await qa.save_frame(game, "res://qa-output/vehicle-%s.png" % kind)
	# Mid-vault through a street window, seen from the side.
	for window: StaticBody3D in game.city.windows:
		if window.broken or window.global_position.y > 2.5 or Vector2(window.global_position.x, window.global_position.z).length() > 30.0:
			continue
		var normal: Vector3 = window.global_basis.z.normalized()
		for side in [1.0, -1.0]:
			player.position = Vector3(window.global_position.x, 0.1, window.global_position.z) + normal * side * 0.75
			player.velocity = Vector3.ZERO
			player.yaw = atan2(normal.x * side, normal.z * side) - 0.9
			player.pitch = -0.1
			await qa.frames(game, 6)
			player.yaw += 0.9
			await qa.frames(game, 2)
			if player.find_vault().is_empty():
				continue
			Input.action_press("jump")
			await qa.frames(game, 2)
			Input.action_release("jump")
			player.yaw -= 1.1
			for shot in 3:
				await qa.frames(game, 16)
				await qa.save_frame(game, "res://qa-output/vault-%d.png" % shot)
			return
