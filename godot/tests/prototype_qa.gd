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
		game.interact()
		check(item.collected, "Nearby supply collected: " + item.id)
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
	game.ambient.stop()
	game.player.footstep.stop()
	await frames(game, 8)
	print("QA RESULT: %d failures" % failures.size())
	game.get_tree().quit(0 if failures.is_empty() else 1)


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
	game.hud.show_inventory(game.inventory)
	await frames(game, 10)
	await save_frame(game, "res://qa-output/inventory.png")
	print("CAPTURE FPS: ", Engine.get_frames_per_second())
	game.get_tree().quit(0 if failures.is_empty() else 1)
