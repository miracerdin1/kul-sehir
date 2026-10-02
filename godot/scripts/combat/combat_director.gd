extends Node3D
# Runs the fight: spawns and tracks soldiers, weapon pickups and bodies, routes
# noise and damage, and draws the short-lived effects (flash, tracer, impact).

const Explosives = preload("res://scripts/combat/armor/explosives.gd")

const Enemy = preload("res://scripts/combat/enemy.gd")
const PlayerCombat = preload("res://scripts/combat/player_combat.gd")
const CombatHud = preload("res://scripts/combat/combat_hud.gd")
const GunModel = preload("res://scripts/combat/gun_model.gd")
const Weapons = preload("res://scripts/combat/weapons.gd")
const MAX_ENEMIES := 4
# More soldiers roam the city as the days pass (spawnManager: 5 + day, at most 11).
const ENEMY_CAP := 7
# A wound bleeds 0.5 HP/s (the HTML rate) for 18-32 s, then clots on its own: about 9-16 HP
# lost without a bandage instead of draining to death.
const BLEED_RATE := 0.5
const BLEED_MIN := 18.0
const BLEED_MAX := 32.0
# Patrol points along the street (x across, z along); soldiers wander between them.
const ROUTE: Array[Vector3] = [
	Vector3(-3, 0, -24), Vector3(3, 0, -24), Vector3(3.5, 0, -12), Vector3(-3, 0, -6),
	Vector3(-5.5, 0.15, -20), Vector3(5.5, 0.15, -3), Vector3(0, 0, -16), Vector3(-2.5, 0, 3),
	Vector3(2.5, 0, 6), Vector3(-5.5, 0.15, 10),
]

signal player_died(cause: String)

var game: Node3D
var player: CharacterBody3D
var explosives: Node3D
var combat: PlayerCombat
var hud: CombatHud
var enemies: Array = []
var pickups: Array[Dictionary] = []
var conditions := {"daylight": 1.0, "visibility": 120.0}
var effects: Array = []
var kills := 0
var spawn_time := 70.0
var spawning := false
var condition_time := 0.0
var rng := RandomNumberGenerator.new()
var route: Array[Vector3] = []
# kind -> [mesh, material] shared by every pickup of that kind.
var pickup_looks := {}
var flash_material: StandardMaterial3D
var tracer_material: StandardMaterial3D
var dust_material: StandardMaterial3D
var blood_material: StandardMaterial3D


func setup(expedition: Node3D) -> void:
	game = expedition
	player = expedition.player
	route = ROUTE.duplicate()
	route.append_array(expedition.city.nodes)
	rng.randomize()
	combat = PlayerCombat.new()
	add_child(combat)
	combat.setup(player, self)
	explosives = Explosives.new()
	explosives.director = self
	add_child(explosives)
	combat.message.connect(say)
	hud = CombatHud.new()
	add_child(hud)
	hud.setup(self)
	combat.hit_enemy.connect(hud.show_hit)
	flash_material = glow(Color(1.0, 0.75, 0.35, 0.9))
	tracer_material = glow(Color(1.0, 0.92, 0.7, 0.55))
	dust_material = glow(Color(0.55, 0.53, 0.5, 0.6), false)
	blood_material = glow(Color(0.35, 0.03, 0.03, 0.8), false)


func glow(color: Color, unshaded := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


# First entry into the street: the pistol by the stove, a knife, and two soldiers at the far end.
func start() -> void:
	add_pickup("rpg", 3, Vector3(-4.3, 0.16, 11.8))
	add_pickup("mine", 3, Vector3(-4.3, 0.16, 10.6))
	add_pickup("rockets", 3, Vector3(-4.3, 0.16, 13.1))
	add_pickup("pistol", 6, Vector3(-5.7, 0.16, 12.2))
	add_pickup("ammo9", 12, Vector3(-6.2, 0.16, 12.9))
	add_pickup("knife", 1, Vector3(5.6, 0.16, 9.5))
	add_pickup("bandage", 1, Vector3(-8.6, 0.28, -2.4))
	spawn_enemy(Vector3(-2.0, 0.1, -24.0), "rifle")
	spawn_enemy(Vector3(3.5, 0.1, -12.0), "pistol")
	for entry: Array in game.city.loot:
		add_pickup(entry[0], entry[1], entry[2])
	var far: Array = game.city.nodes.filter(func(node: Vector3): return node.distance_to(player.global_position) > 42.0 and node.distance_to(player.global_position) < 100.0)
	far.shuffle()
	for node: Vector3 in far.slice(0, MAX_ENEMIES - 1):
		spawn_enemy(node + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), "rifle" if rng.randf() < 0.7 else "pistol")
	spawning = true


func on_same_road(a: Vector3, b: Vector3) -> bool:
	return game.city.on_same_road(a, b)


func paused() -> bool:
	return game.paused


func spawn_enemy(at: Vector3, gun: String) -> Node:
	var enemy := Enemy.new()
	enemy.setup(self, player, at, route, gun)
	add_child(enemy)
	enemies.append(enemy)
	return enemy


func add_pickup(kind: String, amount: int, at: Vector3) -> Dictionary:
	var node: Node3D
	if Weapons.is_gun(kind) or kind == "knife":
		node = GunModel.build(kind)
		node.rotation = Vector3(0, rng.randf_range(0, TAU), PI / 2.0)
		node.position = at + Vector3(0, 0.04, 0)
	else:
		var instance := MeshInstance3D.new()
		instance.mesh = pickup_mesh(kind)
		instance.material_override = pickup_material(kind)
		# Small things are only drawn close by.
		instance.visibility_range_end = 50.0
		instance.position = at + Vector3(0, instance.mesh.get_aabb().size.y / 2.0, 0)
		instance.rotation.y = rng.randf_range(0, TAU)
		node = instance
	add_child(node)
	var entry := {"kind": kind, "amount": amount, "node": node, "taken": false}
	pickups.append(entry)
	return entry


# Ammunition boxes, a cardboard ration pack, a water bottle, a bandage roll.
func pickup_mesh(kind: String) -> Mesh:
	if not pickup_looks.has(kind):
		var mesh: PrimitiveMesh
		if kind in ["water", "mine"]:
			var bottle := CylinderMesh.new()
			bottle.top_radius = 0.22 if kind == "mine" else 0.035
			bottle.bottom_radius = 0.22 if kind == "mine" else 0.05
			bottle.height = 0.09 if kind == "mine" else 0.3
			bottle.radial_segments = 10
			mesh = bottle
		else:
			var box := BoxMesh.new()
			box.size = {"food": Vector3(0.32, 0.2, 0.24), "bandage": Vector3(0.12, 0.06, 0.12)}.get(kind, Vector3(0.22, 0.12, 0.14))
			mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = {"food": Color("9b7a4b"), "water": Color("8eb0bf"), "bandage": Color("d8d2c2")}.get(kind, Color("5a5f3e"))
		material.roughness = 0.35 if kind == "water" else 0.8
		pickup_looks[kind] = [mesh, material]
	return pickup_looks[kind][0]


func pickup_material(kind: String) -> Material:
	return pickup_looks[kind][1]


# The closest weapon pickup or unsearched body within reach, or an empty dictionary.
func nearest_interaction(from: Vector3) -> Dictionary:
	var best := {}
	var best_distance := 2.1
	for entry in pickups:
		if entry.taken:
			continue
		var distance := from.distance_to(entry.node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = {"label": Weapons.label(entry.kind, entry.amount) + " al", "pickup": entry, "node": entry.node}
	for enemy in enemies:
		if enemy.alive or enemy.searched:
			continue
		var distance := from.distance_to(enemy.global_position)
		if distance < best_distance + 0.1:
			best_distance = distance
			best = {"label": "Cesedi ara", "body": enemy, "node": enemy}
	return best


func use(interaction: Dictionary) -> void:
	if interaction.has("pickup"):
		var entry: Dictionary = interaction.pickup
		if not combat.give(entry.kind, entry.amount):
			say("Zaten bir bıçağın var." if entry.kind == "knife" else "Buna ihtiyacın yok.")
			return
		entry.taken = true
		say("Aldın: " + Weapons.label(entry.kind, entry.amount) + (" · 1-5 tuşlarıyla silah değiştir" if Weapons.is_gun(entry.kind) else ""))
	elif interaction.has("body"):
		var enemy: Node = interaction.body
		enemy.searched = true
		var found: Array[String] = []
		for item: Array in enemy.loot:
			if combat.give(item[0], item[1]):
				found.append(Weapons.label(item[0], item[1]))
		say("Buldun: " + ", ".join(found) if not found.is_empty() else "İşine yarar bir şey yok.")


func alert_noise(at: Vector3, radius: float) -> void:
	for enemy in enemies:
		if enemy.alive and enemy.global_position.distance_to(at) < radius:
			enemy.hear(at)


func hurt_player(damage: float, cause: String, from: Vector3) -> void:
	if not player.alive:
		return
	player.hp -= damage
	hud.show_damage(from)
	if player.hp <= 0.0:
		kill_player(cause)


func kill_player(cause: String) -> void:
	player.hp = 0.0
	player.die()
	hud.show_death(cause, kills)
	player_died.emit(cause)


func enemy_killed(_enemy: Node, head: bool) -> void:
	kills += 1
	say("Kafadan vuruş. Düşman etkisiz." if head else "Düşman etkisiz.")


func start_bleeding() -> void:
	player.bleeding = true
	player.bleed_time = rng.randf_range(BLEED_MIN, BLEED_MAX)
	say("Kanaman var. Sargı sar (H).")


func say(text: String) -> void:
	game.hud.notify(text)


func _physics_process(delta: float) -> void:
	update_effects(delta)
	if paused() or not player.alive:
		return
	condition_time -= delta
	if condition_time <= 0.0:
		condition_time = 1.0
		var climate: Node = game.street.climate
		var state: Dictionary = climate.get_environment_state()
		conditions.daylight = state.daylight
		conditions.visibility = clampf(2.0 / maxf(float(climate.state.values.fog), 0.001), 30.0, 170.0)
	if player.bleeding:
		player.hp -= BLEED_RATE * delta
		player.bleed_time -= delta
		if player.hp <= 0.0:
			kill_player("Kan kaybı")
			return
		if player.bleed_time <= 0.0:
			player.bleeding = false
			say("Kanama kendiliğinden durdu.")
	elif player.hp < 100.0 and player.warmth > 45.0:
		player.hp = minf(100.0, player.hp + 0.22 * delta)
	if spawning:
		spawn_time -= delta
		if spawn_time <= 0.0:
			spawn_time = rng.randf_range(28.0, 50.0) if conditions.daylight < 0.3 else rng.randf_range(40.0, 75.0)
			var alive := enemies.filter(func(enemy): return enemy.alive).size()
			var cap := mini(MAX_ENEMIES + game.street.climate.state.day_number() - 1, ENEMY_CAP)
			if alive < cap:
				spawn_far()
				if rng.randf() < 0.35 and alive + 1 < cap:
					spawn_far()


# A new soldier walks in from a road out of sight (spawnFar).
func spawn_far() -> void:
	var options: Array = game.city.nodes.filter(func(node: Vector3): return node.distance_to(player.global_position) > 48.0 and node.distance_to(player.global_position) < 95.0)
	if options.is_empty():
		return
	var node: Vector3 = options[rng.randi() % options.size()]
	spawn_enemy(node + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), "rifle" if rng.randf() < 0.7 else "pistol")


func add_effect(node: Node3D, life: float) -> void:
	add_child(node)
	effects.append([node, life, life])


func update_effects(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var effect: Array = effects[index]
		effect[1] -= delta
		if effect[1] <= 0.0:
			effect[0].queue_free()
			effects.remove_at(index)
		elif effect[0] is MeshInstance3D and effect[2] > 0.2:
			effect[0].scale = Vector3.ONE * (0.4 + 0.6 * effect[1] / effect[2])


func sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 8
	shape.rings = 4
	mesh.mesh = shape
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func muzzle_flash(at: Vector3) -> void:
	var flash := sphere(0.07, flash_material)
	flash.position = at
	add_effect(flash, 0.05)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position = at
	add_effect(light, 0.05)


func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, length)
	line.mesh = box
	line.material_override = tracer_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	line.transform = Transform3D(Basis.looking_at(to - from, up), (from + to) * 0.5)
	add_effect(line, 0.05)


func impact(at: Vector3, normal: Vector3) -> void:
	var dust := sphere(0.09, dust_material)
	dust.position = at + normal * 0.05
	add_effect(dust, 0.45)


func blood(at: Vector3) -> void:
	var drop := sphere(0.08, blood_material)
	drop.position = at
	add_effect(drop, 0.3)
