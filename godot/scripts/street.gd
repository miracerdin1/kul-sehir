extends Node3D

const Surfaces = preload("res://scripts/surfaces.gd")
const AssetFactory = preload("res://scripts/asset_factory.gd")
const Climate = preload("res://scripts/world/climate.gd")

var surfaces := Surfaces.new()
var assets := AssetFactory.new()
var rng := RandomNumberGenerator.new()
var pickups: Array[Dictionary] = []
var stove_position := Vector3(-4.9, 0.16, 8.0)
var fire_light: OmniLight3D
var sun: DirectionalLight3D
var environment: Environment
var climate: Node3D
var time := 0.0


func _ready() -> void:
	rng.seed = 7102026
	create_atmosphere()
	create_ground()
	create_buildings()
	create_props()
	create_debris()
	create_pickups()
	create_ash()


func create_atmosphere() -> void:
	climate = Climate.new()
	add_child(climate)
	sun = climate.sun
	environment = climate.environment


func box(parent: Node3D, at: Vector3, size: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	if solid:
		AssetFactory.collider(parent, size, at)
	return instance


func create_ground() -> void:
	var asphalt: Material = surfaces.textured("aerial_asphalt_01", Color("999c9b"), 0.19)
	var concrete: Material = surfaces.textured("blue_plaster_weathered", Color("9a9b91"), 0.45)
	box(self, Vector3(0, -0.18, 0), Vector3(90, 0.36, 100), asphalt)
	for side in [-1.0, 1.0]:
		box(self, Vector3(side * 6.0, 0.075, 0), Vector3(2.0, 0.15, 57), concrete)
		for z in range(-28, 29, 2):
			box(self, Vector3(side * 5.0, 0.1, z), Vector3(0.2, 0.2, 1.94), concrete, false)
	var paint: Material = surfaces.plain(Color("878575"))
	for z in range(-27, 26, 6):
		box(self, Vector3(0, 0.005, z), Vector3(0.11, 0.007, 1.8), paint, false)
	# The street opens onto the city (scripts/city/), which keeps the outer edge.


func create_buildings() -> void:
	var sign_root := Node3D.new()
	add_child(sign_root)
	sign_root.position = Vector3(0, 3.4, -27.8)
	box(sign_root, Vector3.ZERO, Vector3(6, 0.85, 0.12), surfaces.plain(Color("313a37")), false)
	lettering(sign_root, "TAHLİYE BÖLGESİ  /  07", Vector3(0, 0, 0.08), 48, 0.012)
	for x in [-3.1, 3.1]:
		box(sign_root, Vector3(x, -1.6, 0), Vector3(0.08, 4, 0.08), surfaces.plain(Color("454642"), 0.65, 0.5), false)


func lettering(parent: Node3D, text: String, at: Vector3, font_size: int, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color("d6cdb1")
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	label.position = at


func create_props() -> void:
	var car: Node3D = assets.model("covered_car", self, Vector3(2.7, 0.03, 2.0), 1.5)
	car.rotation.y = -0.12
	AssetFactory.collider(car, Vector3(1.9, 1.3, 4.0), Vector3(0, 0.65, 0))
	var other_car: Node3D = assets.model("covered_car", self, Vector3(-3.0, 0.03, -16.0), 1.4)
	other_car.rotation.y = 0.35
	AssetFactory.collider(other_car, Vector3(1.9, 1.2, 4.0), Vector3(0, 0.6, 0))
	assets.model("barrel_stove", self, stove_position, 1.35)
	AssetFactory.collider(self, Vector3(0.65, 1.05, 0.65), stove_position + Vector3(0, 0.52, 0))
	for index in range(4):
		var barrier: Node3D = assets.model("concrete_road_barrier", self, Vector3(-4.0 + index * 2.7, 0, -26.0), 0.9)
		barrier.rotation.y = rng.randf_range(-0.15, 0.15)
		AssetFactory.collider(barrier, Vector3(2.5, 0.85, 0.65), Vector3(0, 0.42, 0))
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color("ff9e43")
	fire_light.light_energy = 3.0
	fire_light.omni_range = 6.5
	fire_light.position = stove_position + Vector3(0, 0.65, 0.4)
	add_child(fire_light)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("e58a32")
	glow.emission_enabled = true
	glow.emission = Color("ff7b23")
	glow.emission_energy_multiplier = 2.0
	box(self, stove_position + Vector3(0, 0.45, 0.29), Vector3(0.27, 0.19, 0.015), glow, false)


func create_debris() -> void:
	var stone: Material = surfaces.textured("rubble", Color("96978d"), 1.0)
	for index in range(65):
		var side := -1.0 if index % 2 == 0 else 1.0
		var position_on_ground := Vector3(side * rng.randf_range(4.0, 6.8), 0.16, rng.randf_range(-25, 25))
		if position_on_ground.distance_to(stove_position) < 2.0:
			continue
		if index % 5 == 0:
			var rock: Node3D = assets.model("rock_04", self, position_on_ground, rng.randf_range(0.15, 0.45))
			rock.rotation.y = rng.randf_range(0, TAU)
			continue
		var fragment := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(rng.randf_range(0.2, 0.65), rng.randf_range(0.1, 0.35), rng.randf_range(0.2, 0.7))
		fragment.mesh = mesh
		fragment.material_override = stone
		fragment.position = position_on_ground
		fragment.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2))
		add_child(fragment)


func create_pickups() -> void:
	add_pickup("fuel", "Yakıt", "metal_jerrycan", Vector3(-4.1, 0.15, 5.0), 0.48)
	add_pickup("food", "Erzak", "long_life_food", Vector3(-8.8, 0.28, -1.2), 0.34)
	add_pickup("parts", "Metal parça", "can_rusted", Vector3(4.2, 0.15, -15.0), 0.28)


func add_pickup(id: String, label: String, asset: String, at: Vector3, height: float) -> void:
	var node: Node3D = assets.model(asset, self, at, height)
	pickups.append({"id": id, "label": label, "node": node, "collected": false})


func create_ash() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 130
	particles.lifetime = 12.0
	particles.visibility_aabb = AABB(Vector3(-12, -2, -30), Vector3(24, 20, 60))
	particles.position = Vector3(0, 8, 0)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(8, 4, 26)
	material.direction = Vector3(0.3, -1, 0.05)
	material.spread = 18.0
	material.initial_velocity_min = 0.35
	material.initial_velocity_max = 0.7
	material.gravity = Vector3(0.02, -0.02, 0)
	material.scale_min = 0.012
	material.scale_max = 0.027
	particles.process_material = material
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.025, 0.025)
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.65, 0.69, 0.69, 0.4)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	surface.billboard_keep_scale = true
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = surface
	particles.draw_pass_1 = mesh
	add_child(particles)


func _process(delta: float) -> void:
	var game = get_parent()
	var camera: Camera3D = get_viewport().get_camera_3d()
	climate.tick(delta, camera, not game.paused, game.low_quality)
	if game.paused:
		return
	time += delta
	fire_light.light_energy = 2.8 + sin(time * 8.1) * 0.25 + sin(time * 13.2) * 0.13
