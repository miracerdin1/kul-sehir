extends RefCounted
# Boots that sound like boots, soldiers who can be heard coming and who follow the
# survivor into houses and upstairs, and armour that shoots back.

const Footsteps = preload("res://scripts/footsteps.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	await check_steps(game, qa)
	await check_navigation(game, qa)
	await check_houses(game, qa)
	await check_armour(game, qa)


func check_steps(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	player.position = Vector3(0, 0.2, 18)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await qa.frames(game, 5)
	await qa.hold(game, ["move_forward", "sprint"], 70)
	qa.check(player.footstep.stream in Footsteps.streams(true), "Running plays the running boot steps")
	await qa.frames(game, 20)
	await qa.hold(game, ["move_forward", "walk"], 90)
	qa.check(player.footstep.stream in Footsteps.streams(false), "Walking plays the softer walking steps")
	var takes := {}
	for index in 12:
		Footsteps.step(player.footstep, true, -10.0)
		takes[player.footstep.stream] = true
	qa.check(takes.size() >= 3, "Steps vary between takes (%d)" % takes.size())


func check_navigation(game: Node3D, qa: RefCounted) -> void:
	var waited := 0
	while not game.navigation.baked and waited < 1200:
		await qa.frames(game, 1)
		waited += 1
	qa.check(game.navigation.baked, "Soldiers' walking mesh is baked (%d frames)" % waited)


# A house well away from the survivor: a soldier walks in through its door (opening it)
# and then climbs to the upper floor, and its boots are heard on the way.
func check_houses(game: Node3D, qa: RefCounted) -> void:
	var city = game.city
	var nav = game.navigation
	var director = game.director
	game.player.position = Vector3(0, 0.2, 12)
	game.player.velocity = Vector3.ZERO
	var house := Rect2()
	var door := {}
	for building: Rect2 in city.buildings:
		if building.get_center().distance_to(Vector2(0, 12)) < 55.0:
			continue
		for candidate: Dictionary in city.doors:
			var leaf: Vector3 = candidate.leaf.global_position
			if building.grow(0.6).has_point(Vector2(leaf.x, leaf.z)):
				house = building
				door = candidate
				break
		if not door.is_empty():
			break
	qa.check(not door.is_empty(), "Found a house with a door away from the survivor")
	if door.is_empty():
		return
	if door.open:
		city.toggle_door(door)
	await qa.frames(game, 30)
	var leaf: Vector3 = door.leaf.global_position
	var outward := Vector3(leaf.x - house.get_center().x, 0, leaf.z - house.get_center().y).normalized()
	var start: Vector3 = nav.closest(Vector3(leaf.x, 0.2, leaf.z) + outward * 6.0)
	var soldier = director.spawn_enemy(start + Vector3(0, 0.1, 0), "rifle")
	await qa.frames(game, 3)
	soldier.state = "investigate"
	soldier.wait_time = 0.0
	soldier.goal = nav.closest(Vector3(house.get_center().x, 0.3, house.get_center().y))
	var heard := false
	var inside := false
	for wait in 900:
		await qa.frames(game, 1)
		heard = heard or soldier.footstep.playing
		if house.grow(-0.4).has_point(Vector2(soldier.global_position.x, soldier.global_position.z)) and soldier.global_position.y < 1.0:
			inside = true
			break
	qa.check(heard, "A walking soldier's boots can be heard")
	qa.check(door.open, "The soldier opens the closed door")
	qa.check(inside, "The soldier walks into the house (%s)" % str(soldier.global_position))
	soldier.state = "investigate"
	soldier.wait_time = 0.0
	soldier.goal = nav.closest(Vector3(house.get_center().x, city.FLOOR_HEIGHT + 0.3, house.get_center().y))
	var upstairs := false
	for wait in 1200:
		await qa.frames(game, 1)
		if soldier.global_position.y > city.FLOOR_HEIGHT - 0.4 and house.has_point(Vector2(soldier.global_position.x, soldier.global_position.z)):
			upstairs = true
			break
	qa.check(upstairs, "The soldier climbs the stairs to the upper floor (y %.1f)" % soldier.global_position.y)
	# A noise inside a house brings a soldier in to look.
	var listener = director.spawn_enemy(start + Vector3(0, 0.1, 0), "pistol")
	await qa.frames(game, 3)
	listener.hear(Vector3(house.get_center().x, 0.2, house.get_center().y))
	var came := false
	for wait in 900:
		await qa.frames(game, 1)
		if house.has_point(Vector2(listener.global_position.x, listener.global_position.z)):
			came = true
			break
	qa.check(came, "A noise inside a house draws a soldier in")
	for enemy in [soldier, listener]:
		director.enemies.erase(enemy)
		enemy.queue_free()
	await qa.frames(game, 2)


# The tank stops, turns its turret, sprays machine-gun fire and puts a shell near
# the survivor; the ZPT opens up with its heavy machine gun.
func check_armour(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	var vehicles: Array = game.get_tree().get_nodes_in_group("armored_vehicle").filter(func(item): return item.mobile and not item.destroyed)
	for kind in ["tank", "apc"]:
		var matching: Array = vehicles.filter(func(item): return item.kind == kind)
		qa.check(not matching.is_empty(), "A patrolling %s exists" % kind)
		if matching.is_empty():
			continue
		var vehicle = matching[0]
		vehicle.weapons_free = true
		var ahead: Vector3 = -vehicle.global_basis.z
		player.position = vehicle.global_position + ahead * 24.0 + Vector3(0, 0.2, 0)
		player.velocity = Vector3.ZERO
		player.hp = 1000.0
		var shots: int = vehicle.shots
		var cannon: int = vehicle.cannon_shots
		var lowest: float = player.hp
		for wait in 900:
			await qa.frames(game, 1)
			player.velocity = Vector3.ZERO
			lowest = minf(lowest, player.hp)
			if vehicle.shots - shots >= 4 and (kind == "apc" or vehicle.cannon_shots > cannon) and lowest < 1000.0:
				break
		qa.check(vehicle.hold_time > 0.0 or vehicle.speed < 0.5, "The %s halts with the survivor in its sights" % kind)
		qa.check(vehicle.shots - shots >= 4, "The %s opens fire on the survivor (%d rounds)" % [kind, vehicle.shots - shots])
		if kind == "tank":
			qa.check(vehicle.cannon_shots > cannon, "The tank fires its main gun")
		qa.check(lowest < 1000.0, "The %s's fire wounds the survivor" % kind)
		player.hp = 100.0
		player.bleeding = false
		vehicle.weapons_free = false
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	await qa.frames(game, 10)
