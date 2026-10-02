extends RefCounted
# Quick pickups, vaulting over low walls and through broken windows, the glass sound,
# and the city's tanks and APCs patrolling the roads.

const AssetFactory = preload("res://scripts/asset_factory.gd")
const BreakableGlass = preload("res://scripts/city/breakable_glass.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	qa.check(preload("res://scripts/expedition.gd").PICKUP_TIME <= 0.8, "Picking something up takes under a second")
	qa.check(BreakableGlass.glass_sound() is AudioStreamOggVorbis, "Glass breaking uses the synthesized sound files")
	await check_vault(game, qa)
	await check_window(game, qa)
	await check_vehicles(game, qa)
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
	game.drive_vehicles(false)
	await qa_frames(game, 5)
	qa.check(not tank.engine.playing, "Parked vehicles fall silent")


func near_road(at: Vector3) -> bool:
	const City = preload("res://scripts/city/city_builder.gd")
	for x in City.ROADS_X:
		if absf(at.x - x) < City.ROAD_HALF + 1.0:
			return true
	for z in City.ROADS_Z:
		if absf(at.z - z) < City.ROAD_HALF + 1.0:
			return true
	return false
