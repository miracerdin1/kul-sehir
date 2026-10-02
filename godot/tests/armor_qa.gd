extends RefCounted

const Vehicle = preload("res://scripts/combat/armor/armored_vehicle.gd")
const AssetFactory = preload("res://scripts/asset_factory.gd")


func run(game: Node3D, qa: RefCounted) -> void:
	var combat = game.director.combat
	var service = game.director.explosives
	qa.check(game.get_tree().get_nodes_in_group("armored_vehicle").size() == 4, "Two tanks and two APCs exist")
	game.player.position = Vector3(0, 0.2, 100)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = PI
	game.player.pitch = 0.0
	var tank := Vehicle.new()
	game.add_child(tank)
	tank.position = Vector3(0, 0, 110)
	await qa.frames(game, 15)
	combat.shoot_ray(Vector3(0, 1.1, 104), Vector3.BACK, Vector3(0, 1.1, 104), combat.Weapons.DATA.rifle, false)
	qa.check(tank.hp == 280.0, "Small arms do not destroy armored vehicles")
	combat.give("rpg", 3)
	combat.give("mine", 2)
	qa.check(combat.select("rpg") and combat.magazine.rpg == 1 and combat.ammo.rockets == 2, "RPG pickup and selection initialize ammo")
	await qa.aim_at(game, tank.blast_target())
	combat.cooldown = 0.0
	combat.attack()
	qa.check(combat.magazine.rpg == 0, "Firing RPG consumes one loaded rocket")
	await qa.frames(game, 80)
	qa.check(tank.hp == 100.0 and not tank.destroyed, "Swept rocket impact damages tank once")
	await qa.frames(game, 180)
	qa.check(combat.magazine.rpg == 1 and combat.ammo.rockets == 1, "RPG reload takes a reserve rocket")
	combat.cooldown = 0.0
	combat.attack()
	await qa.frames(game, 80)
	qa.check(tank.destroyed and tank.hp == 0.0 and tank.collision_layer == 1, "Second rocket leaves a solid destroyed tank")
	qa.check(not tank.take_explosion(500), "Destroyed tank cannot be destroyed twice")
	tank.queue_free()
	await qa.frames(game, 2)
	var apc := Vehicle.new()
	apc.kind = "apc"
	game.add_child(apc)
	apc.position = Vector3(0, 0, 110)
	game.player.position = Vector3(2.6, 0.15, 109.8)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	await qa.frames(game, 12)
	qa.check(service.place_mine() and combat.mines == 1, "G places a mine on the ground and spends inventory")
	qa.check(not service.place_mine() and combat.mines == 1, "Overlapping mine placement does not spend inventory")
	game.pause_game()
	await qa.frames(game, 150)
	qa.check(not apc.destroyed and not service.place_mine(), "Pause freezes mine arming and rejects placement")
	game.player.position = Vector3(10, 0.15, 110)
	game.start_game()
	await qa.frames(game, 150)
	qa.check(apc.destroyed, "Armed mine destroys nearby APC")
	apc.queue_free()
	await qa.frames(game, 2)
	var shielded := Vehicle.new()
	game.add_child(shielded)
	shielded.position = Vector3(0, 0, 110)
	var wall := AssetFactory.collider(game, Vector3(10, 5, 0.3), Vector3(0, 2, 106.8))
	await qa.frames(game, 3)
	service.explode(Vector3(0, 1.2, 105), 320, 6)
	qa.check(shielded.hp == 280.0, "Solid wall blocks blast damage")
	var health: float = game.player.hp
	service.explode(game.player.global_position + Vector3(0, 1, 3), 60, 6)
	qa.check(game.player.hp < health, "Nearby explosions also hurt the player")
	game.player.hp = health
	wall.queue_free()
	shielded.queue_free()
	game.player.position = Vector3(0, 0.2, 15)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	combat.weapon = "fists"
	combat.owned.rpg = false
	combat.magazine.rpg = 0
	combat.ammo.rockets = 0
	combat.mines = 0
	combat.cooldown = 0.0
	combat.reload_left = 0.0
	combat.aim_held = false
	await qa.frames(game, 125)


func capture(game: Node3D, qa: RefCounted) -> void:
	game.start_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.active = false
	game.player.position = Vector3(15, 0.2, 43)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	for point in [Vector3(0, 0, 43), Vector3(44, 0, 20)]:
		camera.position = point + Vector3(7, 4, -8)
		camera.look_at(point + Vector3.UP)
		await qa.frames(game, 30)
		await qa.save_frame(game, "res://qa-output/armor-%d.png" % int(point.x))
	camera.position = Vector3(7, 4, 35)
	camera.look_at(Vector3(0, 1, 43))
	game.director.explosives.explode(Vector3(0, 1, 39.9), 320, 6)
	await qa.frames(game, 8)
	await qa.save_frame(game, "res://qa-output/armor-explosion.png")
	await qa.frames(game, 150)
	await qa.save_frame(game, "res://qa-output/armor-wreck.png")
	camera.queue_free()
