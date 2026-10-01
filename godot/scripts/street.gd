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
	for x in [-20.0, 20.0]:
		AssetFactory.collider(self, Vector3(0.5, 6, 60), Vector3(x, 2, 0))
	for z in [-29.0, 29.0]:
		AssetFactory.collider(self, Vector3(42, 6, 0.5), Vector3(0, 2, z))


func create_buildings() -> void:
	for side in [-1.0, 1.0]:
		for index in range(5):
			var building := Node3D.new()
			add_child(building)
			building.position = Vector3(side * 7.0, 0.15, -22.0 + index * 11.0)
			building.rotation.y = side * PI / 2.0
			build_facade(building, index, side)
	for index in range(9):
		var brick: Material = surfaces.textured("brick_wall_001", Color("858881"), 0.28)
		box(self, Vector3(-29 + index * 7.5, 4.0, -38.0), Vector3(6.0, rng.randf_range(7, 15), 7.0), brick, false)
	var sign_root := Node3D.new()
	add_child(sign_root)
	sign_root.position = Vector3(0, 3.4, -27.8)
	box(sign_root, Vector3.ZERO, Vector3(6, 0.85, 0.12), surfaces.plain(Color("313a37")), false)
	lettering(sign_root, "TAHLİYE BÖLGESİ  /  07", Vector3(0, 0, 0.08), 48, 0.012)
	for x in [-3.1, 3.1]:
		box(sign_root, Vector3(x, -1.6, 0), Vector3(0.08, 4, 0.08), surfaces.plain(Color("454642"), 0.65, 0.5), false)


func build_facade(parent: Node3D, index: int, side: float) -> void:
	var colors := [Color("b6a28c"), Color("aaa49a"), Color("a89d8c"), Color("b1a99d")]
	var facade_texture := "brick_wall_001" if index % 3 == 1 else "blue_plaster_weathered"
	var plaster: Material = surfaces.textured(facade_texture, colors[index % 4], 0.38)
	var brick: Material = surfaces.textured("brick_wall_001", Color("aaa499"), 0.45)
	var trim: Material = surfaces.textured("rubble", Color("96978b"), 0.6)
	var metal: Material = surfaces.plain(Color("343a38"), 0.62, 0.4)
	var dark: Material = surfaces.plain(Color("131c20"), 0.35)
	var floor_count := 2 + index % 2
	var width := 10.6
	var height := floor_count * 3.0
	box(parent, Vector3(0, 0.06, 3.5), Vector3(width, 0.12, 7), trim)
	box(parent, Vector3(0, height / 2, 7), Vector3(width, height, 0.35), brick)
	for x in [-width / 2, width / 2]:
		box(parent, Vector3(x, height / 2, 3.5), Vector3(0.35, height, 7), brick)
	for floor_index in range(floor_count):
		var base := floor_index * 3.0
		box(parent, Vector3(0, base + 2.75, 0), Vector3(width, 0.5, 0.45), plaster)
		box(parent, Vector3(0, base + 2.95, 0.04), Vector3(width + 0.12, 0.12, 0.66), trim)
		if floor_index > 0:
			box(parent, Vector3(0, base + 0.47, 0), Vector3(width, 0.95, 0.45), plaster)
			box(parent, Vector3(0, base, 3.5), Vector3(width, 0.15, 7), trim)
		for column in range(4):
			var x := -4.0 + column * 2.65
			box(parent, Vector3(x - 1.05, base + 1.5, 0), Vector3(0.6, 2.6, 0.48), plaster)
			if floor_index == 0 and column == 2:
				continue
			var window_height := 1.55 if floor_index > 0 else 2.3
			var middle := base + (1.72 if floor_index > 0 else 1.25)
			box(parent, Vector3(x, middle, 0.18), Vector3(1.46, window_height, 0.035), dark, false)
			for edge in [-0.77, 0.77]:
				box(parent, Vector3(x + edge, middle, -0.065), Vector3(0.055, window_height + 0.15, 0.12), metal, false)
			box(parent, Vector3(x, middle, -0.065), Vector3(0.04, window_height, 0.12), metal, false)
			box(parent, Vector3(x, middle, -0.075), Vector3(1.6, 0.06, 0.12), metal, false)
			box(parent, Vector3(x, middle - window_height / 2, -0.14), Vector3(1.8, 0.14, 0.48), trim, false)
			if (column + floor_index + index) % 3 == 0:
				var board := box(parent, Vector3(x, middle, -0.2), Vector3(1.8, 0.17, 0.06), brick, false)
				board.rotation.z = 0.3
			if floor_index == 0:
				AssetFactory.collider(parent, Vector3(1.6, 2.4, 0.22), Vector3(x, 1.2, 0))
	box(parent, Vector3(width / 2 - 0.22, height / 2, 0), Vector3(0.6, height, 0.48), plaster)
	create_broken_parapet(parent, height, width, brick)
	for x in [-4.7, 4.6]:
		var pipe := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.045
		mesh.height = height
		mesh.radial_segments = 8
		pipe.mesh = mesh
		pipe.material_override = metal
		parent.add_child(pipe)
		pipe.position = Vector3(x, height / 2, -0.3)
	if index == 2:
		var board := Node3D.new()
		parent.add_child(board)
		board.position = Vector3(-1.0, 2.45, -0.37)
		board.rotation.y = PI
		box(board, Vector3.ZERO, Vector3(6.4, 0.55, 0.12), metal, false)
		lettering(board, "ERZAK DEPOSU" if side < 0 else "KARAKÖY TAMİR", Vector3(0, 0, 0.08), 48, 0.012)
		var interior_light := OmniLight3D.new()
		interior_light.position = Vector3(0, 2.0, 3.0)
		interior_light.light_color = Color("c7bd8f")
		interior_light.light_energy = 0.7
		interior_light.omni_range = 6.0
		parent.add_child(interior_light)


func create_broken_parapet(parent: Node3D, height: float, width: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(18):
		var x := -width / 2 + width * index / 18.0
		var next_x := x + width / 18.0
		var left_height := height + rng.randf_range(0.12, 0.75)
		var right_height := height + rng.randf_range(0.15, 0.8)
		var a := Vector3(x, height, -0.23)
		var b := Vector3(x, left_height, -0.23)
		var c := Vector3(next_x, right_height, -0.23)
		var d := Vector3(next_x, height, -0.23)
		for vertex: Vector3 in [a, b, c, a, c, d]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)


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
