extends RefCounted

const WindowBatch = preload("res://scripts/city/window_batch.gd")
const Weapons = preload("res://scripts/combat/weapons.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	qa.check(game.city.stair_list.size() == game.city.buildings.size(), "Every house has two accessible floors")
	qa.check(game.city.street_stairs.size() == 10, "All ten starting-street houses have stairs")
	qa.check(game.city.windows.size() > 100, "City windows contain breakable glazing")
	qa.check(game.city.glass_meshes.all(func(mesh): return mesh.visibility_range_end == game.city.LOW_VIEW_RANGE), "Glass follows building visibility in performance mode")
	await check_entry(game, qa)
	await check_street_stairs(game, qa)
	await check_panes(game, qa)
	await check_melee(game, qa)
	game.player.position = Vector3(0, 0.2, 10)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	await qa.frames(game, 10)


func check_entry(game: Node3D, qa: RefCounted) -> void:
	var door: Dictionary = game.city.doors[game.city.doors.size() - 8]
	var across := Vector3(cos(door.closed), 0, -sin(door.closed))
	var outward := across.cross(Vector3.UP)
	if outward.dot(Vector3(cos(door.open_yaw), 0, -sin(door.open_yaw))) > 0.0:
		outward = -outward
	var center: Vector3 = door.pivot.global_position + across * game.city.DOOR_LEAF / 2.0
	door.open = false
	door.pivot.rotation.y = door.closed
	game.player.position = center + outward * 1.4 + Vector3(0, 0.25, 0)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = atan2(outward.x, outward.z)
	await qa.frames(game, 10)
	await qa.hold(game, ["move_forward"], 40)
	qa.check((game.player.global_position - center).dot(outward) > 0.2, "Closed house door blocks entry")
	game.city.toggle_door(door)
	await qa.frames(game, 30)
	await qa.hold(game, ["move_forward"], 55)
	qa.check((game.player.global_position - center).dot(outward) < -0.7, "Player walks through the open door into the house")
	qa.check(game.player.is_on_floor(), "House floor supports the player after entry")


func check_street_stairs(game: Node3D, qa: RefCounted) -> void:
	for index in [0, 5]:
		var flight: Array = game.city.street_stairs[index]
		var climb: Vector3 = flight[1] - flight[0]
		game.player.position = flight[0] + Vector3(0, 0.2, 0)
		game.player.velocity = Vector3.ZERO
		game.player.yaw = atan2(-climb.x, -climb.z)
		await qa.frames(game, 10)
		await qa.hold(game, ["move_forward"], 170)
		await qa.frames(game, 10)
		qa.check(game.player.is_on_floor() and game.player.position.y > 3.0, "Street house stairs reach upper floor, side %d" % index)
		# Turning around tests the opening/headroom when descending as well.
		game.player.yaw += PI
		await qa.hold(game, ["move_forward"], 170)
		await qa.frames(game, 15)
		qa.check(game.player.is_on_floor() and game.player.position.y < 0.4, "Street house stairs descend to ground, side %d" % index)


func check_panes(game: Node3D, qa: RefCounted) -> void:
	# Test real windows on both wall axes and both storeys.
	var tested := {}
	for pane in game.city.windows:
		var key := "%d/%d" % [roundi(absf(pane.global_basis.z.x)), int(pane.global_position.y > 3.2)]
		if tested.has(key):
			continue
		tested[key] = true
		var direction: Vector3 = -pane.global_basis.z
		var origin: Vector3 = pane.global_position - direction * 0.6
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.2)
		var space := game.get_world_3d().direct_space_state
		var before := space.intersect_ray(query)
		qa.check(before.get("collider") == pane, "Intact pane blocks a ray: " + key)
		game.director.combat.shoot_ray(origin, direction, origin, Weapons.DATA.pistol, false)
		await qa.frames(game, 2)
		qa.check(pane.broken and pane.collision_layer == 0 and space.intersect_ray(query).is_empty(), "Shooting removes glazing and collision: " + key)
		qa.check(not pane.shatter(direction), "Broken pane cannot shatter twice: " + key)
		# Dummy rendering has no MultiMesh readback; the Vulkan capture covers this.
		if DisplayServer.get_name() != "headless":
			var hidden: Transform3D = pane.batch.get_instance_transform(pane.slot)
			qa.check(is_zero_approx(hidden.basis.determinant()), "Broken pane's render instance is removed: " + key)
	qa.check(tested.size() == 4, "Glazing tested on both axes and floors")


func check_melee(game: Node3D, qa: RefCounted) -> void:
	var fixture := Node3D.new()
	game.add_child(fixture)
	var windows := WindowBatch.new()
	windows.add(Vector3(0, 1.4, 22), Vector2(2, 2.5), 0.0)
	var pane = windows.commit(fixture, game.city.glass_material, 40.0)[0]
	var combat = game.director.combat
	game.player.position = Vector3(0, 0.2, 25)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	game.player.pitch = 0.0
	await qa.frames(game, 15)
	combat.cooldown = 0.0
	combat.attack()
	qa.check(not pane.broken, "Melee cannot break glass beyond reach")
	game.player.position = Vector3(0, 0.1, 23)
	game.player.velocity = Vector3.ZERO
	await qa.frames(game, 5)
	qa.check(game.player.test_move(game.player.global_transform, Vector3(0, 0, -1.5)), "Intact glass blocks the character")
	game.pause_game()
	combat.cooldown = 0.0
	combat.attack()
	qa.check(not pane.broken, "Paused player cannot break glass")
	game.start_game()
	combat.attack()
	await qa.frames(game, 2)
	qa.check(pane.broken, "Nearby glass breaks with a melee attack")
	qa.check(not game.player.test_move(game.player.global_transform, Vector3(0, 0, -1.5)), "Broken glass no longer blocks the character")
	fixture.queue_free()
	await qa.frames(game, 75)


func capture(game: Node3D, qa: RefCounted) -> void:
	game.hud.show_game()
	game.player.active = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(-1.5, 3.4, 19)
	camera.look_at(Vector3(-10.5, 3.5, 11))
	await qa.frames(game, 30)
	await qa.save_frame(game, "res://qa-output/houses-exterior.png")
	camera.global_position = Vector3(-10.0, 4.75, 12.5)
	camera.look_at(Vector3(-7.0, 4.7, 8.0))
	await qa.frames(game, 30)
	await qa.save_frame(game, "res://qa-output/houses-upper-floor.png")
	var pane: StaticBody3D
	for candidate in game.city.windows:
		if is_equal_approx(candidate.global_position.x, -7.0) and candidate.global_position.y < 3.0 and candidate.global_position.z > 10.0:
			pane = candidate
			break
	qa.check(pane != null, "Street facade has a ground-floor glass window")
	if pane != null:
		camera.global_position = pane.global_position + Vector3(2.4, 0.4, 1.3)
		camera.look_at(pane.global_position)
		await qa.frames(game, 20)
		await qa.save_frame(game, "res://qa-output/glass-intact.png")
		pane.shatter(Vector3.LEFT)
		await qa.frames(game, 4)
		await qa.save_frame(game, "res://qa-output/glass-breaking.png")
		await qa.frames(game, 75)
		await qa.save_frame(game, "res://qa-output/glass-broken.png")
		qa.check(is_zero_approx(pane.batch.get_instance_transform(pane.slot).basis.determinant()), "Vulkan removes the shattered pane from its MultiMesh")
	await check_panes(game, qa)
	camera.queue_free()
