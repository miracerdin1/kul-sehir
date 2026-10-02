extends RefCounted

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
		return
	failures.append(message)
	push_error("FAIL: " + message)


func frames(game: Node, count: int) -> void:
	for index in range(count):
		await game.get_tree().physics_frame


func run(game: Node3D) -> void:
	# Keep this RefCounted alive while the coroutine is suspended.
	game.set_meta("qa_runner", self)
	await frames(game, 8)
	if "--capture-qa" in OS.get_cmdline_user_args():
		await capture(game)
		return
	if "--houses-only" in OS.get_cmdline_user_args():
		game.start_game()
		game.toggle_quality()
		await preload("res://tests/houses_qa.gd").new().run(game, self)
		print("HOUSE QA RESULT: %d failures" % failures.size())
		game.get_tree().quit(0 if failures.is_empty() else 1)
		return
	check(game.street.pickups.size() == 3, "Three supplies exist")
	check(game.player.animation != null, "Imported character has animation player")
	print("ANIMATIONS: ", game.player.animation.get_animation_list())
	game.start_game()
	await frames(game, 20)
	check(game.player.is_on_floor(), "Player settles on street collision")
	var start: Vector3 = game.player.position
	Input.action_press("move_forward")
	await frames(game, 60)
	Input.action_release("move_forward")
	check(game.player.position.z < start.z - 1.5, "Forward input moves character along camera direction")
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await frames(game, 35)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(game.player.stamina < 98.0, "Sprinting consumes stamina")
	await frames(game, 15)
	Input.action_press("jump")
	await frames(game, 3)
	Input.action_release("jump")
	await frames(game, 8)
	check(game.player.position.y > 0.3, "Jump leaves the ground")
	await frames(game, 70)
	check(game.player.is_on_floor(), "Jump lands on collision")
	await check_motion(game)
	game.player.position = Vector3(-6.1, 0.3, -2.0)
	game.player.velocity = Vector3.ZERO
	await frames(game, 5)
	Input.action_press("move_left")
	await frames(game, 60)
	Input.action_release("move_left")
	check(game.player.position.x > -7.0, "Facade blocks walking through the wall")
	game.player.position = Vector3(5.7, 0.3, 1.35)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = PI / 2.0
	await frames(game, 15)
	check(game.player.arm.get_hit_length() < 2.0, "Camera retracts in front of a wall")
	game.player.position = Vector3(6.4, 0.3, 1.35)
	game.player.velocity = Vector3.ZERO
	await frames(game, 15)
	check(game.player.arm.get_hit_length() < 1.0, "Camera remains outside wall at close range")
	game.player.yaw = 0.0
	game.player.position = Vector3(0, 0.2, 15)
	game.interact()
	check(game.inventory.is_empty(), "Supplies cannot be collected remotely")
	for item: Dictionary in game.street.pickups:
		game.player.position = item.node.global_position + Vector3(0.8, 0.1, 0)
		game.player.velocity = Vector3.ZERO
		await frames(game, 5)
		while game.player.busy():
			await frames(game, 1)
		var before: Vector3 = game.player.position
		game.interact()
		check(item.collected, "Nearby supply collected: " + item.id)
		check(game.player.motion == "PickUp" and game.player.busy(), "Picking up plays PickUp: " + item.id)
		Input.action_press("move_forward")
		await frames(game, 20)
		Input.action_release("move_forward")
		var shift: Vector3 = game.player.position - before
		check(Vector2(shift.x, shift.z).length() < 0.05, "Picking up roots the survivor: " + item.id)
		check(item.node.visible, "Item stays until the hand reaches it: " + item.id)
		while game.player.busy():
			await frames(game, 1)
		check(not item.node.visible, "Item is gone after the pickup: " + item.id)
		var count: int = game.inventory.size()
		game.interact()
		check(game.inventory.size() == count, "Supply cannot be duplicated: " + item.id)
	check(game.inventory.size() == 3, "Inventory contains all three supplies")
	game.player.position = game.street.stove_position + Vector3(1.2, 0.1, 0.8)
	game.player.velocity = Vector3.ZERO
	await frames(game, 8)
	var warmth: float = game.player.warmth
	game.interact()
	check(game.completed, "Returning to stove completes objective")
	check(game.player.warmth > warmth, "Stove restores warmth")
	game.pause_game()
	start = game.player.position
	Input.action_press("move_forward")
	await frames(game, 10)
	Input.action_release("move_forward")
	check(game.player.position.is_equal_approx(start), "Pause stops movement")
	game.start_game()
	game.hud.show_inventory(game.inventory)
	check(game.hud.inventory_panel.visible and "Yakıt" in game.hud.inventory_text.text, "Inventory displays collected supplies")
	game.close_inventory()
	check(not game.hud.inventory_panel.visible and game.player.active, "Closing inventory resumes movement")
	game.toggle_quality()
	check(game.low_quality and game.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "Performance preset applies")
	await check_city(game)
	await preload("res://tests/houses_qa.gd").new().run(game, self)
	await check_combat(game)
	game.ambient.stop()
	game.player.footstep.stop()
	await frames(game, 8)
	print("QA RESULT: %d failures" % failures.size())
	game.get_tree().quit(0 if failures.is_empty() else 1)


func hold(game: Node, actions: Array, count: int) -> void:
	for action: String in actions:
		Input.action_press(action)
	await frames(game, count)
	for action: String in actions:
		Input.action_release(action)


func press(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game.player._unhandled_input(event)
	await frames(game, 2)


func check_motion(game: Node3D) -> void:
	var player = game.player
	player.position = Vector3(0, 0.2, 15)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.stamina = 100.0
	await frames(game, 10)
	check(player.motion == "Idle", "Standing still plays Idle")
	await hold(game, ["move_forward"], 40)
	check(player.motion == "Run", "Default movement plays Run, got " + player.motion)
	check(absf(player.animation.speed_scale - player.RUN_SPEED / player.CLIP_SPEED["Run"]) < 0.05, "Run clip pace matches ground speed")
	await hold(game, ["move_forward", "walk"], 40)
	check(player.motion == "Walk", "Walk key plays Walk, got " + player.motion)
	await hold(game, ["move_forward", "sprint"], 40)
	check(player.motion == "Sprint", "Sprint key plays Sprint, got " + player.motion)
	await frames(game, 30)
	check(player.motion == "Idle", "Releasing keys returns to Idle")
	await press(game, "crouch")
	check(player.stance == "crouch" and player.capsule.height < 1.3, "C crouches and lowers the capsule")
	await hold(game, ["move_forward"], 30)
	check(player.motion == "CrouchWalk", "Crouched movement plays CrouchWalk, got " + player.motion)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.CROUCH_SPEED + 0.01, "Crouching slows movement")
	await press(game, "prone")
	await hold(game, ["move_forward"], 30)
	check(player.stance == "prone" and player.motion == "Crawl", "Z goes prone and crawls")
	await frames(game, 40)
	check(player.animation.speed_scale == 0.0, "Lying still holds the crawl pose")
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 0.2, 2)
	shape.shape = box
	roof.add_child(shape)
	game.add_child(roof)
	roof.global_position = player.global_position + Vector3(0, 0.95, 0)
	await frames(game, 2)
	await press(game, "prone")
	check(player.stance == "prone", "Cannot stand up under a low ceiling")
	roof.queue_free()
	await frames(game, 2)
	await press(game, "prone")
	check(player.stance == "stand" and player.capsule.height > 1.7, "Z again stands back up")
	await press(game, "crouch")
	await hold(game, ["sprint", "move_forward"], 10)
	check(player.stance == "stand", "Sprinting from a crouch stands up")
	await frames(game, 30)
	Input.action_press("jump")
	await frames(game, 2)
	Input.action_release("jump")
	check(player.motion == "JumpAir", "Jumping plays JumpAir at once, got " + player.motion)
	await frames(game, 20)
	check(not player.is_on_floor() and player.motion == "JumpAir", "JumpAir holds while airborne")
	while not player.is_on_floor():
		await frames(game, 1)
	await frames(game, 2)
	check(player.motion == "JumpLand", "Standing landing plays JumpLand, got " + player.motion)
	await frames(game, 40)
	check(player.motion == "Idle", "Landing returns to Idle")
	Input.action_press("move_forward")
	await frames(game, 30)
	Input.action_press("jump")
	await frames(game, 2)
	Input.action_release("jump")
	while not player.is_on_floor():
		await frames(game, 1)
	await frames(game, 3)
	Input.action_release("move_forward")
	check(player.motion == "Run", "Running landing goes straight back to Run, got " + player.motion)
	await frames(game, 30)


func idle(game: Node3D) -> void:
	while game.player.busy():
		await frames(game, 1)


# Points the camera at a world position (the camera sits on a shoulder pivot, so settle twice).
func aim_at(game: Node3D, target: Vector3) -> void:
	for pass_index in 3:
		var to: Vector3 = target - game.player.camera.global_position
		game.player.yaw = atan2(-to.x, -to.z)
		game.player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))
		await frames(game, 2)


# The street opens into the city: blocks of shells, guns to find, patrol roads, a map.
func check_city(game: Node3D) -> void:
	var city = game.city
	var player = game.player
	check(city.buildings.size() >= 30, "City has enterable building shells (%d)" % city.buildings.size())
	check(city.nodes.size() >= 30, "City has road patrol points")
	var kinds: Array = city.loot.map(func(entry): return entry[0])
	check("rifle" in kinds and "shotgun" in kinds and "pistol" in kinds, "Guns are hidden around the city")
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var walled := 0
	for building: Rect2 in city.buildings:
		var middle := building.get_center()
		var query := PhysicsRayQueryParameters3D.create(Vector3(building.position.x - 2.0, 0.3, middle.y + 0.7), Vector3(middle.x, 0.3, middle.y + 0.7))
		if not space.intersect_ray(query).is_empty():
			walled += 1
	check(walled > city.buildings.size() * 0.6, "Building walls block (%d / %d)" % [walled, city.buildings.size()])
	check(city.meshes[0].visibility_range_end == city.LOW_VIEW_RANGE, "Performance preset shortens city view range")
	player.position = Vector3(0, 0.2, 24)
	player.velocity = Vector3.ZERO
	player.yaw = PI
	await frames(game, 10)
	await hold(game, ["move_forward", "sprint"], 100)
	check(player.position.z > 31.0, "Survivor walks out of the street onto the cross road (z %.1f)" % player.position.z)
	player.position = Vector3(0, 0.2, 78)
	player.velocity = Vector3.ZERO
	await frames(game, 10)
	await hold(game, ["move_forward", "sprint"], 150)
	check(player.position.z < city.BOUND.y + 2.0, "City edge stops the survivor (z %.1f)" % player.position.z)
	var event := InputEventAction.new()
	event.action = "map"
	event.pressed = true
	game._unhandled_input(event)
	check(game.city_map.visible, "M opens the city map")
	await frames(game, 2)
	game._unhandled_input(event)
	check(not game.city_map.visible, "M closes the city map")
	var walker = game.director.spawn_enemy(Vector3(44, 0.1, 33), "rifle")
	await frames(game, 2)
	var to_goal: Vector3 = walker.goal - walker.global_position
	check(absf(to_goal.x) < 8.5 or absf(to_goal.z) < 8.5, "Soldier patrols along a road")
	game.director.enemies.erase(walker)
	walker.queue_free()
	await frames(game, 2)
	await check_buildings(game)


# Doors that open, stairs to an upper floor, and supplies worth searching for.
func check_buildings(game: Node3D) -> void:
	var city = game.city
	var player = game.player
	var supplies: Array = city.loot.filter(func(entry): return entry[0] in ["food", "water"])
	check(supplies.size() >= 40, "Buildings hold supplies (%d)" % supplies.size())
	check(supplies.any(func(entry): return entry[2].y > city.FLOOR_HEIGHT), "Some supplies lie on upper floors")
	check(city.stair_list.size() >= 5, "Two-storey buildings have stairs (%d)" % city.stair_list.size())
	var flight: Array = city.stair_list[0]
	var foot: Vector3 = flight[0]
	var landing: Vector3 = flight[1]
	player.position = foot + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	var climb := landing - foot
	player.yaw = atan2(-climb.x, -climb.z)
	await frames(game, 10)
	await hold(game, ["move_forward"], 170)
	await frames(game, 10)
	check(player.position.y > city.FLOOR_HEIGHT - 0.3 and player.is_on_floor(), "Stairs lead to the upper floor (y %.2f)" % player.position.y)
	check(city.doors.size() >= 10, "Buildings have doors (%d)" % city.doors.size())
	var door: Dictionary = city.doors[0]
	var leaf: Node3D = door.leaf
	player.position = leaf.global_position + Vector3(0, -1.0, 0) + (leaf.global_position - door.pivot.global_position).normalized().cross(Vector3.UP) * 0.9
	player.velocity = Vector3.ZERO
	await frames(game, 5)
	game.find_interaction()
	check(not game.focused_door.is_empty(), "A door can be used up close")
	var was_open: bool = door.open
	game.interact()
	await frames(game, 30)
	var target: float = door.closed if was_open else door.open_yaw
	check(door.open != was_open and absf(angle_difference(door.pivot.rotation.y, target)) < 0.05, "E swings the door " + ("shut" if was_open else "open"))
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	await frames(game, 5)


func check_combat(game: Node3D) -> void:
	var director = game.director
	var player = game.player
	var combat = director.combat
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await frames(game, 10)
	check(combat.weapon == "fists" and director.enemies.is_empty(), "Survivor starts unarmed, no soldiers in QA")
	var pistol: Dictionary = director.add_pickup("pistol", 6, Vector3(0.9, 0.05, 10))
	var rounds: Dictionary = director.add_pickup("ammo9", 12, Vector3(-3.0, 0.05, 10))
	await frames(game, 3)
	game.find_interaction()
	check(game.combat_interaction.get("pickup") == pistol, "Pistol on the ground can be picked up")
	game.interact()
	check(combat.owned.pistol and combat.weapon == "pistol" and combat.magazine.pistol == 6, "Picking up the pistol arms the survivor")
	check(player.motion == "PickUp", "Weapon pickup plays PickUp")
	await idle(game)
	check(not pistol.node.visible, "Pistol leaves the ground")
	player.position = Vector3(-2.2, 0.2, 10)
	await frames(game, 5)
	game.interact()
	await idle(game)
	check(combat.ammo.ammo9 == 12, "Ammunition goes to the reserve")
	combat.attack()
	check(combat.magazine.pistol == 5, "Firing spends a round")
	await frames(game, 25)
	combat.reload()
	check(combat.reload_left > 0.0, "R starts a reload")
	await frames(game, 100)
	check(combat.magazine.pistol == 12 and combat.ammo.ammo9 == 5, "Reload fills the magazine from the reserve")
	combat.aim_held = true
	player.yaw = 0.7
	await frames(game, 25)
	check(player.aim_mode(), "Right mouse aims the pistol")
	check(absf(wrapf(player.visual.rotation.y - (player.yaw + PI), -PI, PI)) < 0.15, "Aiming turns the body to the camera")
	if player.armed.rig:
		check(player.armed.aim_weight > 0.95 and player.armed.gun != null, "Aim pose and gun are on the body")
	Input.action_press("move_back")
	await frames(game, 25)
	check(player.backwards and player.animation.speed_scale < 0.0, "Walking back while aiming plays the legs in reverse")
	Input.action_press("move_left")
	await frames(game, 20)
	Input.action_release("move_left")
	Input.action_release("move_back")
	check(absf(wrapf(player.visual.rotation.y - (player.yaw + PI), -PI, PI)) <= player.armed.MAX_TWIST + 0.1, "Strafing keeps the chest within the spine's twist")
	await frames(game, 20)
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	var target = director.spawn_enemy(Vector3(0, 0.1, 1.0), "rifle")
	await frames(game, 3)
	target.visual.rotation.y = PI
	target.wait_time = 100.0
	await aim_at(game, target.global_position + Vector3(0, 1.2, 0))
	combat.attack()
	await frames(game, 2)
	check(target.hp < 100.0, "A shot at the soldier's chest hits")
	check(target.state == "combat", "A wounded soldier turns to fight")
	for shot in 8:
		if not target.alive:
			break
		await frames(game, 20)
		await aim_at(game, target.global_position + Vector3(0, 1.2, 0))
		combat.attack()
	check(not target.alive and target.motion == "Death", "Enough hits kill the soldier and play Death")
	check(director.kills == 1, "The kill is counted")
	combat.aim_held = false
	player.position = target.global_position + Vector3(0.9, 0.1, 0.9)
	await frames(game, 5)
	game.find_interaction()
	check(game.combat_interaction.get("label", "") == "Cesedi ara", "A body can be searched")
	var rifle_rounds: int = combat.ammo.ammo762
	game.interact()
	check(target.searched and (combat.owned.rifle or combat.ammo.ammo762 > rifle_rounds), "Searching the body yields the soldier's rifle or rounds")
	await idle(game)
	var listener = director.spawn_enemy(Vector3(0, 0.1, -20.0), "pistol")
	await frames(game, 3)
	listener.visual.rotation.y = PI
	director.alert_noise(Vector3(0, 0, -5), 40.0)
	check(listener.state == "investigate", "Gunfire within earshot sends a soldier to investigate")
	player.position = Vector3(0, 0.2, 8)
	player.velocity = Vector3.ZERO
	var watcher = director.spawn_enemy(Vector3(2.0, 0.1, -4.0), "rifle")
	await frames(game, 3)
	watcher.visual.rotation.y = 0.0
	var spotted := false
	for wait in 240:
		await frames(game, 1)
		if watcher.state == "combat":
			spotted = true
			break
	check(spotted, "A soldier facing the survivor in daylight spots him")
	var health: float = player.hp
	for wait in 480:
		await frames(game, 1)
		if player.hp < health:
			break
	check(player.hp < health, "A soldier in combat wounds the survivor")
	director.hurt_player(500.0, "QA", watcher.global_position)
	await frames(game, 30)
	check(not player.alive and game.dead and director.hud.death_panel.visible, "Death shows the death screen")
	check(player.motion == "Death", "The survivor falls with Death")


func save_frame(game: Node, path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := game.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	check(error == OK, "Screenshot saved: " + path)


func capture(game: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	await frames(game, 120)
	await save_frame(game, "res://qa-output/menu.png")
	game.start_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.performance.show()
	await frames(game, 150)
	await save_frame(game, "res://qa-output/street.png")
	check(game.hud.stamina_bar.size.y <= 8.0, "HUD meters have compact height")
	Input.action_press("move_forward")
	await frames(game, 24)
	await save_frame(game, "res://qa-output/walking.png")
	Input.action_release("move_forward")
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(-3.3, 0.2, 9.0)
	game.player.yaw = 0.85
	game.player.pitch = -0.12
	await frames(game, 100)
	await save_frame(game, "res://qa-output/stove.png")
	game.player.position = Vector3(2.0, 0.2, 36.0)
	game.player.yaw = -1.2
	game.player.pitch = 0.05
	await frames(game, 100)
	await save_frame(game, "res://qa-output/city.png")
	# A doorway from outside, then the stairs from their foot.
	var door: Dictionary = game.city.doors[2]
	var across := Vector3(cos(door.closed), 0, -sin(door.closed))
	var front: Vector3 = across.cross(Vector3.UP)
	# The door swings inward, so outside is the other way.
	if front.dot(Vector3(cos(door.open_yaw), 0, -sin(door.open_yaw))) > 0.0:
		front = -front
	var outside: Vector3 = door.pivot.global_position + across * 0.5 + front * 5.0
	game.player.position = outside + Vector3(0, 0.2, 0)
	var look: Vector3 = door.pivot.global_position - outside
	game.player.yaw = atan2(-look.x, -look.z)
	game.player.pitch = 0.05
	await frames(game, 60)
	await save_frame(game, "res://qa-output/house.png")
	var flight: Array = game.city.stair_list[0]
	game.player.position = flight[0] + Vector3(0, 0.2, 0)
	var climb: Vector3 = flight[1] - flight[0]
	game.player.yaw = atan2(-climb.x, -climb.z)
	game.player.pitch = 0.2
	await frames(game, 60)
	await save_frame(game, "res://qa-output/stairs.png")
	game.city_map.toggle(true)
	await frames(game, 5)
	await save_frame(game, "res://qa-output/map.png")
	game.city_map.toggle(false)
	game.hud.show_inventory(game.inventory)
	await frames(game, 10)
	await save_frame(game, "res://qa-output/inventory.png")
	await preload("res://tests/houses_qa.gd").new().capture(game, self)
	print("CAPTURE FPS: ", Engine.get_frames_per_second())
	game.get_tree().quit(0 if failures.is_empty() else 1)
