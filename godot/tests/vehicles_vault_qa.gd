extends RefCounted
# Quick pickups, vaulting over low walls and through broken windows, the glass sound,
# the city's tanks and APCs patrolling the roads and opening fire, footsteps, and
# soldiers walking into houses.

const AssetFactory = preload("res://scripts/asset_factory.gd")
const BreakableGlass = preload("res://scripts/city/breakable_glass.gd")
const Footsteps = preload("res://scripts/footsteps.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	qa.check(preload("res://scripts/expedition.gd").PICKUP_TIME <= 0.8, "Picking something up takes under a second")
	qa.check(BreakableGlass.glass_sound() is AudioStreamOggVorbis, "Glass breaking uses the synthesized sound files")
	await check_vault(game, qa)
	await check_window(game, qa)
	check_footsteps(qa)
	var health: float = game.player.hp
	game.player.hp = 1e9
	await check_vehicles(game, qa)
	await check_soldier_indoors(game, qa)
	game.player.hp = health
	game.player.bleeding = false
	game.player.position = Vector3(0, 0.2, 10)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	await qa.frames(game, 10)


func place(game: Node3D, at: Vector3, yaw: float) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.player.yaw = yaw
	game.player.pitch = -0.1
	await qa_frames(game, 12)


func qa_frames(game: Node, count: int) -> void:
	for index in range(count):
		await game.get_tree().physics_frame


func press_jump(game: Node3D) -> void:
	Input.action_press("jump")
	await qa_frames(game, 2)
	Input.action_release("jump")


func check_vault(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	var wall := AssetFactory.collider(game, Vector3(4.0, 0.9, 0.4), Vector3(0, 0.45, 97.0))
	await place(game, Vector3(0, 0.1, 98.0), 0.0)
	await press_jump(game)
	qa.check(player.vaulting(), "Space in front of a waist-high wall starts a vault")
	await qa_frames(game, 60)
	qa.check(not player.vaulting() and player.position.z < 96.4 and player.is_on_floor(), "The vault lands on the far side of the wall")
	qa.check(player.visual.rotation.x == 0.0 and not player.collision.disabled, "The body is upright and solid again after the vault")
	# A window still glazed (here: a solid pane above the sill) is not vaulted.
	var pane := AssetFactory.collider(game, Vector3(4.0, 1.4, 0.05), Vector3(0, 1.65, 97.0))
	await place(game, Vector3(0, 0.1, 98.0), 0.0)
	await press_jump(game)
	await qa_frames(game, 50)
	qa.check(player.position.z > 97.3, "An unbroken window above the sill blocks the vault")
	pane.queue_free()
	var high := AssetFactory.collider(game, Vector3(4.0, 2.4, 0.4), Vector3(0, 1.2, 94.0))
	await place(game, Vector3(0, 0.1, 95.0), 0.0)
	await press_jump(game)
	qa.check(not player.vaulting(), "A wall above chest height is jumped at, not vaulted")
	await qa_frames(game, 50)
	wall.queue_free()
	high.queue_free()
	await qa_frames(game, 3)


func check_window(game: Node3D, qa: RefCounted) -> void:
	var player = game.player
	var crossed := false
	var tried := 0
	for pane in game.city.windows:
		if tried >= 10 or crossed:
			break
		if absf(pane.global_position.y - 1.75) > 0.25 or pane.global_position.length() < 30.0:
			continue
		tried += 1
		var normal: Vector3 = pane.global_basis.z
		normal.y = 0.0
		normal = normal.normalized()
		for side in [1.0, -1.0]:
			var outside: Vector3 = normal * side
			var start: Vector3 = pane.global_position + outside * 0.95
			start.y = 0.1
			pane.shatter(-outside)
			await place(game, start, atan2(outside.x, outside.z))
			if not player.is_on_floor():
				continue
			await press_jump(game)
			if not player.vaulting():
				continue
			await qa_frames(game, 60)
			var after: float = (player.global_position - pane.global_position).dot(outside)
			if after < -0.3 and player.is_on_floor():
				crossed = true
				break
	qa.check(crossed, "The survivor vaults in through a broken ground-floor window")


func check_vehicles(game: Node3D, qa: RefCounted) -> void:
	var vehicles: Array = game.get_tree().get_nodes_in_group("armored_vehicle").filter(func(vehicle): return vehicle.mobile)
	qa.check(vehicles.size() == 4, "Four city vehicles can drive")
	var tanks: Array = vehicles.filter(func(vehicle): return vehicle.kind == "tank")
	# The tank nearest the survivor (track links only animate within sight).
	tanks.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(-30, 0, -50)) < b.global_position.distance_to(Vector3(-30, 0, -50)))
	var tank = tanks[0]
	qa.check(tank.tracks.multimesh.instance_count > 120 and tank.wheels.multimesh.instance_count == 12, "The tank has track links and six road wheels a side")
	game.player.position = Vector3(-30, 0.2, -50)
	game.player.velocity = Vector3.ZERO
	var starts: Array[Vector3] = []
	for vehicle in vehicles:
		starts.append(vehicle.global_position)
	var turret: float = tank.turret.rotation.y
	game.drive_vehicles(true)
	# Patrol checks first: the crews do not look out for the survivor yet.
	for vehicle in vehicles:
		vehicle.sight_time = 1e9
	await qa_frames(game, 300)
	var moved := 0
	for index in range(vehicles.size()):
		if vehicles[index].global_position.distance_to(starts[index]) > 4.0:
			moved += 1
	qa.check(moved >= 3, "Tanks and APCs drive along the roads (%d of 4 moved)" % moved)
	qa.check(tank.engine.playing, "A moving tank has its engine running")
	# (Headless runs keep no MultiMesh data, so check the distance each track has run.)
	qa.check(tank.travelled.x > 3.0 and tank.travelled.y > 3.0, "The tracks run as the tank drives")
	qa.check(absf(tank.turret.rotation.y - turret) > 0.01, "The turret sweeps while on patrol")
	var on_roads: bool = vehicles.all(func(vehicle): return near_road(vehicle.global_position))
	qa.check(on_roads, "Vehicles stay on the roads")
	# Step in front of a driving tank: it stops short instead of running him over.
	var mover = null
	for vehicle in vehicles:
		if vehicle.speed > 1.5:
			mover = vehicle
			break
	if mover != null:
		var forward: Vector3 = -mover.global_basis.z
		game.player.position = mover.global_position + forward * 8.5 + Vector3.UP * 0.2
		game.player.velocity = Vector3.ZERO
		await qa_frames(game, 150)
		var gap: float = (game.player.global_position - mover.global_position).dot(forward)
		qa.check(mover.speed < 0.3 and gap > 3.6, "A tank stops for the survivor in its path")
	else:
		qa.check(false, "A vehicle was driving for the stop test")
	# In the open in front of a tank, then an APC: they see him and open fire.
	for kind in ["tank", "apc"]:
		var shots := 0
		for vehicle in vehicles.filter(func(candidate): return candidate.kind == kind):
			shots = await fire_at_player(game, vehicle)
			if shots > 0:
				break
		qa.check(shots > 0, "The %s sees the survivor and fires (%d shots)" % [kind, shots])
	for vehicle in vehicles:
		vehicle.sight_time = 1e9
	game.drive_vehicles(false)
	await qa_frames(game, 5)
	qa.check(not tank.engine.playing, "Parked vehicles fall silent")


# Puts the survivor 25 m in front of a vehicle; returns the cannon and machine-gun
# shots it fired at him within ten seconds.
func fire_at_player(game: Node3D, vehicle: Node3D) -> int:
	if vehicle.destroyed:
		return 0
	var forward: Vector3 = -vehicle.global_basis.z
	forward.y = 0.0
	game.player.position = vehicle.global_position + forward.normalized() * 25.0 + Vector3.UP * 0.2
	game.player.velocity = Vector3.ZERO
	var before: int = vehicle.cannon_shots + vehicle.mg_shots
	vehicle.sight_time = 0.0
	for tick in range(20):
		await qa_frames(game, 30)
		if vehicle.cannon_shots + vehicle.mg_shots > before and (vehicle.kind != "tank" or vehicle.cannon_shots > 0):
			break
	vehicle.sight_time = 1e9
	vehicle.sees_player = false
	return vehicle.cannon_shots + vehicle.mg_shots - before if vehicle.kind != "tank" else vehicle.cannon_shots


func check_footsteps(qa: RefCounted) -> void:
	var takes := {}
	var last: AudioStream = null
	var repeated := false
	for index in range(24):
		var take := Footsteps.step()
		repeated = repeated or take == last
		last = take
		takes[take] = true
	qa.check(takes.size() >= 4 and not repeated and last is AudioStreamOggVorbis, "Footsteps vary between several takes and never repeat back to back")


# A soldier outside a house with a closed door walks in, opening the door, and up
# the stairs to the upper floor.
func check_soldier_indoors(game: Node3D, qa: RefCounted) -> void:
	var region = game.navigation
	for wait in range(60):
		if region.ready_to_use:
			break
		await qa_frames(game, 30)
	qa.check(region.ready_to_use, "The walkable area for soldiers is baked")
	if not region.ready_to_use:
		return
	var city = game.city
	game.player.position = Vector3(0, 0.2, 15)
	game.player.velocity = Vector3.ZERO
	var reached := false
	var opened := false
	var tried := 0
	for door: Dictionary in city.doors:
		if tried >= 3 or reached:
			break
		var at: Vector3 = door.leaf.global_position
		if at.y > 1.5 or Vector2(at.x, at.z).distance_to(Vector2(0, 15)) < 30.0:
			continue
		var houses: Array = city.buildings.filter(func(house: Rect2): return house.grow(0.5).has_point(Vector2(at.x, at.z)))
		if houses.is_empty():
			continue
		var house: Rect2 = houses[0]
		var middle := house.get_center()
		var out := (Vector2(at.x, at.z) - middle).normalized()
		var start: Vector3 = region.snap(Vector3(at.x + out.x * 3.0, 0.1, at.z + out.y * 3.0))
		var upstairs := Vector3.INF
		for attempt in range(12):
			var inner := house.grow(-1.4)
			var wanted := Vector3(randf_range(inner.position.x, inner.end.x), city.FLOOR_HEIGHT + 0.1, randf_range(inner.position.y, inner.end.y))
			var point: Vector3 = region.snap(wanted)
			if absf(point.y - wanted.y) < 0.4 and house.has_point(Vector2(point.x, point.z)):
				upstairs = point
				break
		if start == Vector3.INF or house.grow(0.2).has_point(Vector2(start.x, start.z)) or upstairs == Vector3.INF:
			continue
		tried += 1
		if door.open:
			city.toggle_door(door)
		var soldier = game.director.spawn_enemy(start, "rifle")
		await qa_frames(game, 2)
		soldier.state = "patrol"
		soldier.wait_time = 0.0
		soldier.goal = upstairs
		for tick in range(60):
			await qa_frames(game, 30)
			opened = opened or door.open
			var spot: Vector3 = soldier.global_position
			if spot.y > city.FLOOR_HEIGHT - 0.4 and house.has_point(Vector2(spot.x, spot.z)):
				reached = true
				break
		qa.check(soldier.steps.stream is AudioStreamOggVorbis, "A walking soldier's boots can be heard")
		game.director.enemies.erase(soldier)
		soldier.queue_free()
		await qa_frames(game, 2)
	qa.check(opened, "A soldier opens a closed door on his way in")
	qa.check(reached, "A soldier walks into a house and up the stairs")


func near_road(at: Vector3) -> bool:
	const City = preload("res://scripts/city/city_builder.gd")
	for x in City.ROADS_X:
		if absf(at.x - x) < City.ROAD_HALF + 1.0:
			return true
	for z in City.ROADS_Z:
		if absf(at.z - z) < City.ROAD_HALF + 1.0:
			return true
	return false
