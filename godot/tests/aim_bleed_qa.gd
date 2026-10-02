extends RefCounted
# Rifle scope zoom on right click, and wounds that stop bleeding on their own.


func run(game: Node3D, qa: RefCounted) -> void:
	var director = game.director
	var player = game.player
	var combat = director.combat
	player.position = Vector3(0, 0.2, 10)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await qa.frames(game, 10)
	var normal_fov: float = player.camera.fov
	combat.give("rifle", 20)
	combat.aim_held = true
	await qa.frames(game, 30)
	qa.check(combat.weapon == "rifle" and player.camera.fov < 35.0, "Aiming the rifle zooms the camera in")
	combat.aim_held = false
	await qa.frames(game, 40)
	qa.check(absf(player.camera.fov - normal_fov) < 1.0, "Releasing aim zooms back out")
	combat._unhandled_input(click("aim", true))
	combat._unhandled_input(click("aim", false))
	await qa.frames(game, 30)
	qa.check(combat.aim_held and player.camera.fov < 35.0, "One right click keeps the rifle aimed after release")
	combat._unhandled_input(click("aim", true))
	combat._unhandled_input(click("aim", false))
	await qa.frames(game, 40)
	qa.check(not combat.aim_held and absf(player.camera.fov - normal_fov) < 1.0, "A second right click lowers the rifle")
	combat.owned.rifle = false
	combat.magazine.rifle = 0
	combat.ammo.ammo762 = 0
	combat.weapon = "fists"
	await qa.frames(game, 5)
	player.hp = 100.0
	director.start_bleeding()
	qa.check(player.bleeding and player.bleed_time >= director.BLEED_MIN, "A hit can start bleeding")
	player.bleed_time = 0.3
	await qa.frames(game, 40)
	var health: float = player.hp
	qa.check(not player.bleeding, "Bleeding stops on its own")
	await qa.frames(game, 60)
	qa.check(player.alive and player.hp >= health, "Health stops draining once the bleeding stops")
	player.hp = 100.0


func click(action: String, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event
