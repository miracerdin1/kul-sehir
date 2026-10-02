extends AnimatableBody3D
# A T-72-style tank or a BTR-style eight-wheeled APC. Built from primitive meshes merged
# per part (hull, turret, gun, wheels, track links). City vehicles patrol the road grid:
# they drive between junctions, take corners in an arc (the tank pivots on the spot for
# sharp turns) and stop for people and other vehicles in their way. The turret sweeps
# the street; when the crew sees the survivor the vehicle halts, swings the turret onto
# him and opens fire: the tank with its main gun (an explosive shell) and coaxial
# machine gun, the APC with its heavy machine gun.

const CityBuilder = preload("res://scripts/city/city_builder.gd")

const TRACK_X := 1.5
const LINK_PITCH := 0.16
# Track loop in the hull's side plane (z forward-negative, y up): idler at the front,
# sprocket at the back, road wheels along the bottom.
const IDLER := Vector2(-3.05, 0.66)
const SPROCKET := Vector2(3.0, 0.66)
const TRACK_RADIUS := 0.36
const TRACK_BOTTOM := 0.035
const ROAD_WHEELS := [-2.35, -1.45, -0.55, 0.35, 1.25, 2.15]
const ROAD_WHEEL_RADIUS := 0.38
const APC_WHEELS := [-2.35, -1.05, 0.95, 2.25]
const APC_WHEEL_RADIUS := 0.55
const APC_WHEEL_X := 1.3
# Normal deceleration; hard braking for something in the way is 1.6x this.
const BRAKE := 3.5
const ENGINE_SOUND := "res://assets/audio/tank_engine.ogg"
const CANNON_SOUND := "res://assets/audio/tank_cannon.ogg"
const MG_SOUND := "res://assets/audio/heavy_mg.ogg"
const SIGHT_RANGE := 70.0
const CANNON_RANGE := Vector2(10.0, 70.0)
const MG_RANGE := 50.0
# The first street (x = 0 between the two cross roads) is too narrow for armour.
const BLOCKED_EDGE := [Vector2i(2, 1), Vector2i(2, 2)]

static var shared := {}

var kind := "tank"
var hp := 280.0
var destroyed := false
var visuals: Array[GeometryInstance3D] = []
# Set by the combat director when the game starts; only then do city vehicles drive.
var director: Node
var mobile := false
var turret: Node3D
var gun: Node3D
var wheels: MultiMeshInstance3D
var add_cogs: MultiMeshInstance3D
var wheel_spots: Array[Transform3D] = []
var tracks: MultiMeshInstance3D
var track_points: PackedVector3Array = PackedVector3Array()
var track_length := 0.0
var engine: AudioStreamPlayer3D
var exhaust: CPUParticles3D
var speed := 0.0
var travelled := Vector2.ZERO
var from_node := Vector2i(-1, -1)
var to_node := Vector2i(-1, -1)
var next_node := Vector2i(-1, -1)
var blocked_time := 0.0
var turret_time := 0.0
var sight_time := 0.0
var sees_player := false
var track_dirty := true
var cannon_wait := 0.0
var mg_wait := 0.0
var mg_burst := 0
var warned := false
var cannon_shots := 0
var mg_shots := 0
var shots: AudioStreamPlayer3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("armored_vehicle")
	# sync_to_physics is switched on only once it drives: set while parked, the body
	# would keep the position it had on entering the tree.
	sync_to_physics = false
	var tank := kind == "tank"
	hp = 280.0 if tank else 170.0
	if tank:
		build_tank()
	else:
		build_apc()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 1.42, 6.9) if tank else Vector3(2.9, 1.95, 7.4)
	shape.shape = box
	shape.position.y = 0.71 if tank else 1.25
	add_child(shape)
	var top := CollisionShape3D.new()
	var dome := BoxShape3D.new()
	dome.size = Vector3(2.3, 0.6, 2.5) if tank else Vector3(1.3, 0.5, 1.3)
	top.shape = dome
	top.position = Vector3(0, 1.72, 0.35) if tank else Vector3(0, 2.45, -0.9)
	add_child(top)
	update_running_gear()


# Materials -------------------------------------------------------------------------

static func paint(key: String) -> StandardMaterial3D:
	if shared.has(key):
		return shared[key]
	if not shared.has("grime"):
		var noise := FastNoiseLite.new()
		noise.frequency = 0.035
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		# Keep the grime subtle: dark patches only take paint down to about 70 %.
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.68, 0.68, 0.66))
		ramp.set_color(1, Color(1, 1, 1))
		texture.color_ramp = ramp
		shared.grime = texture
	var material := StandardMaterial3D.new()
	var colors := {"steel": Color("484d38"), "steel_dark": Color("393d2c"), "rubber": Color("1f201d"), "metal": Color("3a3a36"),
		"track": Color("34322e"), "wood": Color("3a2e22"), "lens": Color("c9d3c4"), "burnt": Color("23211e")}
	material.albedo_color = colors[key]
	material.roughness = {"lens": 0.15, "rubber": 0.95, "track": 0.75}.get(key, 0.82)
	material.metallic = {"track": 0.55, "metal": 0.5, "lens": 0.3}.get(key, 0.12)
	if key in ["steel", "steel_dark", "track", "metal", "burnt"]:
		# Mottled grime and wear so plates do not read as flat plastic.
		material.albedo_texture = shared.grime
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(0.45, 0.45, 0.45)
		material.roughness_texture = shared.grime
	shared[key] = material
	return material


# Mesh merging: primitive meshes appended per material into one ArrayMesh -----------

class Parts:
	var tools := {}

	func add(mesh: PrimitiveMesh, material: Material, at: Transform3D) -> void:
		if not tools.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = tool
		tools[material].append_from(mesh, 0, at)

	func box(material: Material, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		add(mesh, material, Transform3D(basis, center))

	# Axis "x", "y" or "z"; radius2 < 0 means a straight cylinder.
	func cylinder(material: Material, center: Vector3, radius: float, length: float, axis := "y", segments := 16, radius2 := -1.0, basis := Basis.IDENTITY) -> void:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius if radius2 < 0.0 else radius2
		mesh.height = length
		mesh.radial_segments = segments
		mesh.rings = 1
		var turn := Basis.IDENTITY
		if axis == "x":
			turn = Basis(Vector3.BACK, PI / 2.0)
		elif axis == "z":
			turn = Basis(Vector3.RIGHT, PI / 2.0)
		add(mesh, material, Transform3D(basis * turn, center))

	func dome(material: Material, center: Vector3, radius: float, height: float, scale: Vector3) -> void:
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.is_hemisphere = true
		mesh.radial_segments = 28
		mesh.rings = 8
		add(mesh, material, Transform3D(Basis.from_scale(scale), center))

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for material: Material in tools:
			var tool: SurfaceTool = tools[material]
			tool.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		return mesh


func instance(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.visibility_range_end = 150.0
	parent.add_child(node)
	visuals.append(node)
	return node


# Tank -------------------------------------------------------------------------------

func build_tank() -> void:
	var steel := paint("steel")
	var dark := paint("steel_dark")
	var metal := paint("metal")
	var rubber := paint("rubber")
	var hull := Parts.new()
	# Lower hull between the tracks, then the sloped glacis and its lower plate.
	hull.box(steel, Vector3(0, 0.92, 0.1), Vector3(2.4, 0.95, 6.2))
	var glacis_low := Vector2(-3.12, 0.56)
	var glacis_top := Vector2(-2.2, 1.395)
	# Rotating about x by -angle tips the plate's long (z) axis up toward the back.
	var glacis := Basis(Vector3.RIGHT, -atan2(glacis_top.y - glacis_low.y, glacis_top.x - glacis_low.x))
	var glacis_center := Vector3(0, (glacis_low.y + glacis_top.y) / 2.0, (glacis_low.x + glacis_top.x) / 2.0)
	var glacis_length := glacis_low.distance_to(glacis_top)
	hull.box(steel, glacis_center, Vector3(2.4, 0.1, glacis_length + 0.05), glacis)
	hull.box(steel, Vector3(0, 0.5, -3.02), Vector3(2.4, 0.16, 0.28), Basis(Vector3.RIGHT, 0.6))
	# Reactive armour bricks over the glacis, and the splash guard ridge (the "V").
	for row in range(3):
		for column in range(5):
			hull.box(dark, glacis_center + glacis * Vector3(-0.98 + column * 0.49, 0.1, -0.42 + row * 0.42), Vector3(0.44, 0.08, 0.36), glacis)
	for side in [-1.0, 1.0]:
		hull.box(dark, glacis_center + glacis * Vector3(side * 0.55, 0.07, 0.62), Vector3(1.0, 0.08, 0.06), glacis * Basis(Vector3.UP, side * 0.5))
	# Rear plate, engine deck louvres, unditching log and fuel drums.
	hull.box(steel, Vector3(0, 0.92, 3.22), Vector3(2.4, 0.95, 0.08))
	for index in range(7):
		hull.box(metal, Vector3(0, 1.405, 1.25 + index * 0.24), Vector3(2.0, 0.025, 0.12))
	hull.cylinder(paint("wood"), Vector3(0, 1.53, 2.95), 0.14, 3.3, "x", 10)
	for side in [-1.0, 1.0]:
		hull.cylinder(dark, Vector3(side * 0.55, 1.08, 3.55), 0.3, 0.95, "x", 16)
		hull.cylinder(metal, Vector3(side * 0.55, 1.08, 3.55), 0.31, 0.06, "x", 16)
		hull.box(metal, Vector3(side * 0.55, 0.8, 3.3), Vector3(0.12, 0.2, 0.25))
	# Fenders over the tracks, with stowage boxes, a mud flap at the front and side skirts.
	for side in [-1.0, 1.0]:
		var x: float = side * TRACK_X
		hull.box(steel, Vector3(x, 1.13, 0.0), Vector3(0.72, 0.04, 6.6))
		hull.box(steel, Vector3(x, 1.0, -3.45), Vector3(0.72, 0.04, 0.42), Basis(Vector3.RIGHT, -0.75))
		for spot in [[-1.2, 0.9], [0.0, 1.1], [1.3, 0.8], [2.35, 0.7]]:
			hull.box(dark if spot[0] > 0.0 else steel, Vector3(x + side * 0.02, 1.27, spot[0]), Vector3(0.6, 0.26, spot[1]))
		for panel in range(4):
			hull.box(rubber, Vector3(side * 1.84, 0.93, -3.15 + panel * 0.74), Vector3(0.03, 0.42, 0.7))
		hull.box(metal, Vector3(side * 1.05, 1.32, -2.32), Vector3(0.2, 0.14, 0.14))
		hull.cylinder(paint("lens"), Vector3(side * 1.05, 1.32, -2.4), 0.06, 0.02, "z", 12)
		hull.box(metal, Vector3(side * 0.6, 0.55, -3.22), Vector3(0.14, 0.18, 0.24))
		# Tow cable along the hull side.
		hull.cylinder(metal, Vector3(side * 1.19, 1.25, 0.5), 0.025, 4.0, "z", 6)
	# Exhaust on the left rear fender, turret ring.
	hull.box(metal, Vector3(-1.5, 1.3, 2.75), Vector3(0.5, 0.3, 0.6))
	hull.box(paint("rubber"), Vector3(-1.78, 1.3, 2.75), Vector3(0.04, 0.16, 0.42))
	hull.cylinder(dark, Vector3(0, 1.45, 0.35), 1.02, 0.12, "y", 28)
	# Running gear hubs that do not turn: return rollers and the sprocket/idler mounts.
	for side in [-1.0, 1.0]:
		for z in [-1.6, 0.0, 1.6]:
			hull.cylinder(metal, Vector3(side * TRACK_X, 0.93, z), 0.1, 0.36, "x", 12)
		hull.box(steel, Vector3(side * 1.25, 0.66, IDLER.x + 0.1), Vector3(0.12, 0.3, 0.3))
	instance(hull.commit(), self)

	turret = Node3D.new()
	turret.position = Vector3(0, 1.45, 0.35)
	add_child(turret)
	var top := Parts.new()
	top.dome(steel, Vector3(0, 0.0, 0.05), 1.25, 1.0, Vector3(1.0, 1.0, 1.1))
	# Reactive armour wrapped round the turret cheeks.
	for side in [-1.0, 1.0]:
		for step in range(4):
			var angle: float = side * (0.32 + step * 0.22)
			var at := Vector3(sin(angle) * 1.06, 0.2, -cos(angle) * 1.18)
			top.box(dark, at, Vector3(0.3, 0.26, 0.14), Basis(Vector3.UP, -angle))
			top.box(dark, at + Vector3(0, 0.22, 0.05), Vector3(0.28, 0.12, 0.3), Basis(Vector3.UP, -angle))
		# Smoke grenade launchers.
		for tube in range(4):
			var at := Vector3(side * (0.92 + tube * 0.06), 0.42, -0.3 + tube * 0.17)
			top.cylinder(metal, at, 0.05, 0.24, "z", 8, -1.0, Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.UP, side * 0.5))
	top.box(steel, Vector3(0, 0.22, -1.12), Vector3(0.6, 0.46, 0.42))
	# Commander's cupola with its heavy machine gun, gunner's hatch, searchlight.
	top.cylinder(steel, Vector3(0.48, 0.56, 0.2), 0.36, 0.24, "y", 20)
	top.cylinder(dark, Vector3(0.48, 0.71, 0.24), 0.31, 0.06, "y", 20)
	top.box(metal, Vector3(0.48, 0.86, -0.12), Vector3(0.13, 0.15, 0.5))
	top.cylinder(metal, Vector3(0.48, 0.88, -0.85), 0.025, 1.05, "z", 8)
	top.box(dark, Vector3(0.62, 0.8, 0.05), Vector3(0.12, 0.2, 0.3))
	top.cylinder(dark, Vector3(-0.45, 0.52, 0.22), 0.3, 0.06, "y", 18)
	for at in [Vector3(-0.3, 0.55, -0.12), Vector3(-0.58, 0.55, -0.05)]:
		top.box(metal, at, Vector3(0.12, 0.12, 0.08))
	top.box(dark, Vector3(-0.66, 0.42, -0.82), Vector3(0.32, 0.32, 0.26))
	top.cylinder(paint("lens"), Vector3(-0.66, 0.42, -0.96), 0.12, 0.02, "z", 14)
	# Stowage bin and snorkel across the turret rear, antenna.
	top.box(dark, Vector3(0, 0.22, 1.3), Vector3(1.6, 0.36, 0.42))
	top.cylinder(metal, Vector3(0, 0.5, 1.12), 0.1, 1.7, "x", 10)
	top.cylinder(metal, Vector3(-0.62, 1.55, 0.95), 0.012, 2.1, "y", 4, -1.0, Basis(Vector3.RIGHT, -0.12))
	instance(top.commit(), turret)

	gun = Node3D.new()
	gun.position = Vector3(0, 0.24, -1.2)
	turret.add_child(gun)
	var barrel := Parts.new()
	barrel.cylinder(metal, Vector3(0, 0, -2.5), 0.075, 4.9, "z", 14)
	for z in [-0.75, -1.55, -3.55, -4.3]:
		barrel.cylinder(steel, Vector3(0, 0, z), 0.098, 0.68, "z", 14)
	barrel.cylinder(steel, Vector3(0, 0, -2.55), 0.135, 0.62, "z", 16)
	barrel.cylinder(dark, Vector3(0, 0, -4.98), 0.088, 0.12, "z", 14)
	for band in [-1.16, -1.95, -3.15, -3.95]:
		barrel.cylinder(dark, Vector3(0, 0, band), 0.104, 0.05, "z", 14)
	instance(barrel.commit(), gun)

	# Road wheels, sprockets and idlers turn; one MultiMesh holds them all.
	var wheel := Parts.new()
	for offset in [-0.12, 0.12]:
		wheel.cylinder(rubber, Vector3(offset, 0, 0), ROAD_WHEEL_RADIUS, 0.17, "x", 22)
	wheel.cylinder(dark, Vector3(0, 0, 0), ROAD_WHEEL_RADIUS - 0.08, 0.4, "x", 22)
	wheel.cylinder(metal, Vector3(0, 0, 0), 0.13, 0.48, "x", 10)
	for spoke in range(6):
		wheel.box(metal, Vector3(0, 0, 0), Vector3(0.43, 0.05, ROAD_WHEEL_RADIUS * 1.4), Basis(Vector3.RIGHT, spoke * PI / 6.0))
	for side in [-1.0, 1.0]:
		for z in ROAD_WHEELS:
			wheel_spots.append(Transform3D(Basis.IDENTITY, Vector3(side * TRACK_X, ROAD_WHEEL_RADIUS + 0.06, z)))
	wheels = multi(wheel.commit(), wheel_spots.size())
	var cog := Parts.new()
	cog.cylinder(dark, Vector3.ZERO, 0.3, 0.42, "x", 20)
	cog.cylinder(metal, Vector3.ZERO, 0.1, 0.5, "x", 10)
	for tooth in range(12):
		var angle := tooth * TAU / 12.0
		cog.box(dark, Vector3(0, sin(angle) * 0.32, cos(angle) * 0.32), Vector3(0.36, 0.08, 0.08), Basis(Vector3.RIGHT, -angle))
	var cogs: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for at in [IDLER, SPROCKET]:
			cogs.append(Transform3D(Basis.IDENTITY, Vector3(side * TRACK_X, at.y, at.x)))
	var cog_node := multi(cog.commit(), cogs.size())
	cog_node.set_meta("spots", cogs)
	add_cogs = cog_node

	# Track links: a plate with a grouser, laid round the loop and moved as it drives.
	var link := Parts.new()
	link.box(paint("track"), Vector3(0, 0, 0), Vector3(0.58, 0.05, LINK_PITCH - 0.015))
	link.box(paint("track"), Vector3(0, -0.035, 0), Vector3(0.58, 0.03, 0.04))
	link.box(metal, Vector3(0, 0.035, 0), Vector3(0.08, 0.04, 0.1))
	build_track_loop()
	var count := int(track_length / LINK_PITCH)
	tracks = multi(link.commit(), count * 2)
	add_engine(-1.75, 2.75)



func multi(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.visibility_range_end = 120.0
	add_child(node)
	visuals.append(node)
	return node


# Samples the closed track path every 2 cm: bottom run forward, up round the idler,
# back along the top, down round the sprocket.
func build_track_loop() -> void:
	var path: Array[Vector2] = []
	var front_wheel: float = ROAD_WHEELS[0]
	var rear_wheel: float = ROAD_WHEELS[ROAD_WHEELS.size() - 1]
	path.append(Vector2(rear_wheel, TRACK_BOTTOM))
	path.append(Vector2(front_wheel, TRACK_BOTTOM))
	for step in range(17):
		var angle := -PI / 2.0 + step * PI / 16.0
		path.append(IDLER + Vector2(-cos(angle), sin(angle)) * TRACK_RADIUS)
	for step in range(17):
		var angle := PI / 2.0 - step * PI / 16.0
		path.append(SPROCKET + Vector2(cos(angle), sin(angle)) * TRACK_RADIUS)
	path.append(Vector2(rear_wheel, TRACK_BOTTOM))
	var lengths: Array[float] = [0.0]
	for index in range(1, path.size()):
		lengths.append(lengths[index - 1] + path[index].distance_to(path[index - 1]))
	track_length = lengths[lengths.size() - 1]
	var segment := 0
	var distance := 0.0
	while distance < track_length:
		while lengths[segment + 1] < distance:
			segment += 1
		var a := path[segment]
		var b := path[segment + 1]
		var t := (distance - lengths[segment]) / maxf(0.0001, lengths[segment + 1] - lengths[segment])
		var at := a.lerp(b, t)
		var along := b - a
		# x: position along the hull (z), y: height, z: link pitch angle.
		track_points.append(Vector3(at.x, at.y, atan2(-along.y, along.x)))
		distance += 0.02


# APC ----------------------------------------------------------------------------------

func build_apc() -> void:
	var steel := paint("steel")
	var dark := paint("steel_dark")
	var metal := paint("metal")
	var hull := Parts.new()
	hull.box(steel, Vector3(0, 1.32, 0.15), Vector3(2.62, 0.96, 6.3))
	# Wedge nose: upper and lower plates meeting at the trim vane.
	var tip := Vector2(-3.75, 1.2)
	for plate in [[tip, Vector2(-3.0, 1.82)], [tip, Vector2(-3.05, 0.84)]]:
		var a: Vector2 = plate[0]
		var b: Vector2 = plate[1]
		hull.box(steel, Vector3(0, (a.y + b.y) / 2.0, (a.x + b.x) / 2.0), Vector3(2.62, 0.08, a.distance_to(b) + 0.06), Basis(Vector3.RIGHT, -atan2(b.y - a.y, b.x - a.x)))
	hull.box(dark, Vector3(0, 1.22, -3.72), Vector3(2.3, 0.05, 0.4), Basis(Vector3.RIGHT, 0.3))
	# Upper hull: inward-sloped sides, roof, sloped rear.
	for side in [-1.0, 1.0]:
		hull.box(steel, Vector3(side * 1.16, 2.03, 0.05), Vector3(0.08, 0.5, 6.1), Basis(Vector3.BACK, -side * 0.38))
		for at in APC_WHEELS:
			hull.box(dark, Vector3(side * 1.3, 1.02, at), Vector3(0.5, 0.06, 1.25))
		hull.box(dark, Vector3(side * 1.33, 1.35, -0.05), Vector3(0.04, 0.75, 0.8))
		hull.box(metal, Vector3(side * 1.0, 1.95, -2.95), Vector3(0.22, 0.12, 0.08))
		hull.cylinder(paint("lens"), Vector3(side * 1.0, 1.95, -3.0), 0.05, 0.02, "z", 10)
		for vision in range(3):
			hull.box(metal, Vector3(side * 1.05, 2.15, -1.6 + vision * 1.6), Vector3(0.05, 0.1, 0.22), Basis(Vector3.BACK, -side * 0.38))
	hull.box(steel, Vector3(0, 2.26, 0.05), Vector3(1.85, 0.08, 6.1))
	hull.box(steel, Vector3(0, 1.68, 3.38), Vector3(2.62, 0.08, 1.15), Basis(Vector3.RIGHT, 0.95))
	hull.box(metal, Vector3(0, 2.32, 1.9), Vector3(1.4, 0.04, 1.4))
	for hatch in [Vector3(-0.5, 2.32, -1.9), Vector3(0.5, 2.32, -1.9), Vector3(0.0, 2.32, 1.0)]:
		hull.cylinder(dark, hatch, 0.32, 0.06, "y", 16)
	hull.cylinder(paint("wood"), Vector3(1.05, 2.42, 0.6), 0.12, 2.0, "z", 8)
	instance(hull.commit(), self)

	turret = Node3D.new()
	turret.position = Vector3(0, 2.3, -0.9)
	add_child(turret)
	var top := Parts.new()
	top.cylinder(steel, Vector3(0, 0.24, 0), 0.52, 0.48, "y", 18, 0.7)
	top.box(steel, Vector3(0, 0.25, -0.62), Vector3(0.42, 0.34, 0.3))
	top.cylinder(dark, Vector3(0, 0.5, 0.05), 0.4, 0.05, "y", 16)
	for side in [-1.0, 1.0]:
		for tube in range(3):
			top.cylinder(metal, Vector3(side * 0.55, 0.28, 0.1 + tube * 0.13), 0.045, 0.2, "z", 8, -1.0, Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.UP, side * 1.2))
	instance(top.commit(), turret)
	gun = Node3D.new()
	gun.position = Vector3(0, 0.25, -0.75)
	turret.add_child(gun)
	var barrel := Parts.new()
	barrel.cylinder(metal, Vector3(0, 0, -1.0), 0.055, 2.0, "z", 10)
	barrel.cylinder(dark, Vector3(0, 0, -0.35), 0.08, 0.5, "z", 10)
	barrel.cylinder(metal, Vector3(0.18, -0.02, -0.45), 0.025, 0.7, "z", 6)
	instance(barrel.commit(), gun)

	var wheel := Parts.new()
	wheel.cylinder(paint("rubber"), Vector3.ZERO, APC_WHEEL_RADIUS, 0.4, "x", 24)
	wheel.cylinder(dark, Vector3.ZERO, 0.3, 0.42, "x", 16)
	wheel.cylinder(metal, Vector3.ZERO, 0.12, 0.46, "x", 8)
	for lug in range(14):
		wheel.box(paint("rubber"), Vector3.ZERO, Vector3(0.38, 0.06, APC_WHEEL_RADIUS * 2.05), Basis(Vector3.RIGHT, lug * PI / 14.0))
	for side in [-1.0, 1.0]:
		for z in APC_WHEELS:
			wheel_spots.append(Transform3D(Basis.IDENTITY, Vector3(side * APC_WHEEL_X, APC_WHEEL_RADIUS, z)))
	wheels = multi(wheel.commit(), wheel_spots.size())
	add_engine(1.05, 3.05)


# Engine, exhaust ----------------------------------------------------------------------

func add_engine(exhaust_x: float, exhaust_z: float) -> void:
	rng.randomize()
	shots = AudioStreamPlayer3D.new()
	shots.unit_size = 14.0
	shots.max_distance = 160.0
	add_child(shots)
	engine = AudioStreamPlayer3D.new()
	var stream: AudioStream = load(ENGINE_SOUND)
	engine.stream = stream
	engine.unit_size = 9.0
	engine.max_distance = 95.0
	engine.volume_db = -6.0
	engine.pitch_scale = 0.8 if kind == "tank" else 1.15
	add_child(engine)
	exhaust = CPUParticles3D.new()
	exhaust.position = Vector3(exhaust_x, 1.35, exhaust_z)
	exhaust.amount = 14
	exhaust.lifetime = 1.8
	exhaust.direction = Vector3(-signf(exhaust_x) * 0.6, 1.0, 0.4)
	exhaust.spread = 25.0
	exhaust.initial_velocity_min = 0.6
	exhaust.initial_velocity_max = 1.3
	exhaust.gravity = Vector3(0, 0.3, 0)
	exhaust.scale_amount_min = 0.5
	exhaust.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	exhaust.scale_amount_curve = curve
	var puff := QuadMesh.new()
	puff.size = Vector2(0.7, 0.7)
	var smoke := StandardMaterial3D.new()
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.albedo_color = Color(0.16, 0.15, 0.14, 0.22)
	smoke.vertex_color_use_as_albedo = true
	puff.material = smoke
	exhaust.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	exhaust.color_ramp = fade
	exhaust.emitting = false
	add_child(exhaust)


func set_engine(running: bool) -> void:
	if engine == null:
		return
	if running and not engine.playing:
		engine.play(randf() * 1.5)
	elif not running and engine.playing:
		engine.stop()
	exhaust.emitting = running


# Driving ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if destroyed or not mobile or director == null:
		return
	var paused: bool = director.paused()
	engine.stream_paused = paused
	if paused:
		return
	set_engine(true)
	sync_to_physics = true
	if to_node.x < 0:
		start_route()
	var tank := kind == "tank"
	var max_speed := 4.8 if tank else 6.5
	aim_turret(delta)
	fire(delta)
	var turn_rate := 0.6 if tank else 0.5
	var target := node_point(to_node)
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < (5.0 if tank else 6.0):
		advance_route()
		target = node_point(to_node)
		to_target = target - global_position
		to_target.y = 0.0
	var wanted := atan2(-to_target.x, -to_target.z)
	var error := wrapf(wanted - rotation.y, -PI, PI)
	var turn := clampf(error, -turn_rate * delta, turn_rate * delta)
	var target_speed := max_speed * clampf(1.0 - absf(error) / 1.1, 0.0, 1.0)
	# Sharp turns: the tank pivots on its tracks; the APC (which cannot) creeps round
	# slowly on the spot, as a stand-in for a multi-point turn.
	var turning_round := absf(error) > (0.9 if tank else 1.4)
	if turning_round:
		target_speed = 0.0
		if not tank:
			turn = clampf(error, -turn_rate * 0.5 * delta, turn_rate * 0.5 * delta)
	elif not tank:
		target_speed = maxf(target_speed, 1.6)
		turn *= clampf(speed / 2.0, 0.0, 1.0)
	var braking := false
	# Engaging the survivor: halt and fight from where it stands.
	if sees_player:
		target_speed = 0.0
		turn = 0.0
		braking = true
	elif not turning_round and something_ahead(max_speed):
		target_speed = 0.0
		braking = true
		turn = 0.0
		blocked_time += delta
		# Facing a wreck, a person or another vehicle for long: turn back the way it came.
		if blocked_time > 4.0:
			blocked_time = 0.0
			var back := from_node
			from_node = to_node
			to_node = back
			next_node = Vector2i(-1, -1)
	else:
		blocked_time = 0.0
	var accel := (1.6 if tank else 2.4) if target_speed > speed else BRAKE
	if braking:
		accel = BRAKE * 1.6
	speed = move_toward(speed, target_speed, accel * delta)
	rotation.y += turn
	var forward := -global_basis.z
	global_position += forward * speed * delta
	# Each side's track or wheels: forward travel plus the pivot difference.
	var half := TRACK_X if tank else APC_WHEEL_X
	var spin := turn * half
	travelled += Vector2(speed * delta + spin, speed * delta - spin)
	if absf(speed) > 0.01 or absf(turn) > 0.0001:
		track_dirty = true
	engine.pitch_scale = (0.8 if tank else 1.15) + absf(speed) / max_speed * 0.45 + absf(turn / maxf(delta, 0.0001)) * 0.15
	engine.volume_db = -6.0 + absf(speed) / max_speed * 4.0
	if track_dirty and near_camera():
		update_running_gear()


func something_ahead(max_speed: float) -> bool:
	var forward := -global_basis.z
	var right := global_basis.x
	var half_width := 1.8 if kind == "tank" else 1.45
	var nose := 3.5 if kind == "tank" else 3.8
	var people: Array = [director.player]
	people.append_array(director.enemies)
	for body in people:
		if not is_instance_valid(body) or body.get("alive") == false:
			continue
		var offset: Vector3 = body.global_position - global_position
		var ahead := offset.dot(forward)
		var stopping := speed * speed / (2.0 * BRAKE * 1.6) + speed * 0.3
		if ahead > 0.0 and ahead < nose + 2.0 + stopping and absf(offset.dot(right)) < half_width + 0.9:
			return true
	for other in get_tree().get_nodes_in_group("armored_vehicle"):
		if other == self:
			continue
		var offset: Vector3 = other.global_position - global_position
		var ahead := offset.dot(forward)
		if ahead > 0.0 and ahead < nose + 4.5 + max_speed and absf(offset.dot(right)) < 3.6:
			return true
	return false


func near_camera() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or camera.global_position.distance_to(global_position) < 90.0


func node_point(node: Vector2i) -> Vector3:
	return Vector3(CityBuilder.ROADS_X[node.x], global_position.y, CityBuilder.ROADS_Z[node.y])


func edge_open(a: Vector2i, b: Vector2i) -> bool:
	if b.x < 0 or b.y < 0 or b.x >= CityBuilder.ROADS_X.size() or b.y >= CityBuilder.ROADS_Z.size():
		return false
	return not ((a == BLOCKED_EDGE[0] and b == BLOCKED_EDGE[1]) or (a == BLOCKED_EDGE[1] and b == BLOCKED_EDGE[0]))


# Joins the road it was parked on, heading the way it faces.
func start_route() -> void:
	var at := global_position
	var forward := -global_basis.z
	var best := INF
	for i in range(CityBuilder.ROADS_X.size()):
		for j in range(CityBuilder.ROADS_Z.size()):
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a := Vector2i(i, j)
				var b: Vector2i = a + step
				if not edge_open(a, b):
					continue
				var pa := node_point(a)
				var pb := node_point(b)
				var along := (pb - pa).normalized()
				var t := clampf((at - pa).dot(along), 0.0, pa.distance_to(pb))
				var distance := (pa + along * t).distance_to(at)
				if distance < best:
					best = distance
					var heading_b := forward.dot(along) >= 0.0
					from_node = a if heading_b else b
					to_node = b if heading_b else a


func advance_route() -> void:
	if next_node.x < 0:
		next_node = pick_next(from_node, to_node)
	from_node = to_node
	to_node = next_node
	next_node = Vector2i(-1, -1)


func pick_next(previous: Vector2i, current: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = current + step
		if candidate != previous and edge_open(current, candidate):
			options.append(candidate)
	if options.is_empty():
		return previous
	# Usually straight on, sometimes a turn.
	var straight := current + (current - previous)
	if straight in options and randf() < 0.55:
		return straight
	return options.pick_random()


func aim_turret(delta: float) -> void:
	if turret == null:
		return
	turret_time += delta
	sight_time -= delta
	var player: Node3D = director.player
	if sight_time <= 0.0:
		sight_time = 0.5
		sees_player = false
		var distance := player.global_position.distance_to(global_position)
		if player.get("alive") and distance < SIGHT_RANGE:
			var eye := turret.global_position + Vector3.UP * 0.9
			var query := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * 1.2)
			query.exclude = [get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			sees_player = hit.is_empty() or hit.collider == player
		if sees_player and not warned:
			warned = true
			cannon_wait = maxf(cannon_wait, 3.0)
			director.say(("Tank" if kind == "tank" else "ZPT") + " seni gördü! Siper al!")
		elif warned and distance > SIGHT_RANGE + 20.0:
			warned = false
	var wanted := sin(turret_time * 0.25) * 0.9
	var pitch := 0.0
	if sees_player:
		var local := to_local(player.global_position)
		wanted = atan2(-local.x, -local.z)
		var flat := Vector2(local.x, local.z).length()
		pitch = clampf(atan2(local.y + 1.0 - turret.position.y, flat), -0.12, 0.3)
	var step := (0.5 if kind == "tank" else 0.9) * delta
	turret.rotation.y += clampf(wrapf(wanted - turret.rotation.y, -PI, PI), -step, step)
	gun.rotation.x = move_toward(gun.rotation.x, pitch, 0.2 * delta)


func update_running_gear() -> void:
	track_dirty = false
	var tank := kind == "tank"
	var radius := ROAD_WHEEL_RADIUS if tank else APC_WHEEL_RADIUS
	for index in range(wheel_spots.size()):
		var spot := wheel_spots[index]
		var side := travelled.x if spot.origin.x < 0.0 else travelled.y
		wheels.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.RIGHT, -side / radius), spot.origin))
	if not tank:
		return
	var cogs: Array = add_cogs.get_meta("spots")
	for index in range(cogs.size()):
		var spot: Transform3D = cogs[index]
		var side := travelled.x if spot.origin.x < 0.0 else travelled.y
		add_cogs.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.RIGHT, -side / 0.33), spot.origin))
	var count := tracks.multimesh.instance_count / 2
	var samples := track_points.size()
	for side_index in range(2):
		var x := -TRACK_X if side_index == 0 else TRACK_X
		# Driving forward, the bottom run stays on the ground and the loop runs backwards
		# relative to the hull.
		var shift: float = -(travelled.x if side_index == 0 else travelled.y)
		for link in range(count):
			var distance := fposmod(link * track_length / count + shift, track_length)
			var point := track_points[mini(samples - 1, int(distance / 0.02))]
			tracks.multimesh.set_instance_transform(side_index * count + link, Transform3D(Basis(Vector3.RIGHT, point.z), Vector3(x, point.y, point.x)))


# Firing --------------------------------------------------------------------------------

# How far the turret still has to swing to bear on the survivor (radians).
func lay_error() -> float:
	var local := to_local(director.player.global_position)
	return absf(wrapf(atan2(-local.x, -local.z) - turret.rotation.y, -PI, PI))


func fire(delta: float) -> void:
	cannon_wait -= delta
	mg_wait -= delta
	if not sees_player or turret == null or not director.player.alive:
		mg_burst = 0
		return
	var distance: float = director.player.global_position.distance_to(global_position)
	var error := lay_error()
	if kind == "tank" and cannon_wait <= 0.0 and error < 0.05 and distance > CANNON_RANGE.x and distance < CANNON_RANGE.y:
		fire_cannon(distance)
		return
	if mg_wait <= 0.0 and error < 0.2 and distance < MG_RANGE:
		fire_machine_gun(distance)


func muzzle() -> Vector3:
	return gun.global_transform * (Vector3(0, 0, -5.05) if kind == "tank" else Vector3(0, 0, -2.05))


# One shell: it flies straight to whatever it meets first along the line of fire,
# usually close to the survivor, and bursts there.
func fire_cannon(distance: float) -> void:
	cannon_wait = rng.randf_range(6.5, 9.5)
	var player: Node3D = director.player
	var from := muzzle()
	var spread := 0.6 + distance * 0.035
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
		spread += 1.4
	var aim: Vector3 = player.global_position + Vector3.UP * 0.9 + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-0.4, 0.4), rng.randf_range(-spread, spread))
	var direction := (aim - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 160.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var impact: Vector3 = from + direction * 160.0 if hit.is_empty() else hit.position
	director.tracer(from, impact)
	director.muzzle_flash(from)
	# A direct hit kills; a near miss a couple of metres off still hurts badly.
	var own: Array[RID] = [get_rid()]
	director.explosives.explode(impact - direction * 0.3, 110.0, 5.5, own)
	cannon_shots += 1
	report(CANNON_SOUND, from, 4.0)
	# Recoil: the barrel slams back and runs out again.
	var recoil := gun.create_tween()
	recoil.tween_property(gun, "position:z", gun.position.z + 0.4, 0.05)
	recoil.tween_property(gun, "position:z", gun.position.z, 0.6).set_trans(Tween.TRANS_SINE)
	director.alert_noise(global_position, 120.0)


# Machine gun bursts, like a soldier's rifle but heavier and less precise.
func fire_machine_gun(distance: float) -> void:
	if mg_burst <= 0:
		mg_burst = rng.randi_range(4, 8)
	mg_burst -= 1
	mg_shots += 1
	mg_wait = 0.11 if mg_burst > 0 else rng.randf_range(1.4, 2.6)
	var player: Node3D = director.player
	var from := muzzle() if kind != "tank" else gun.global_transform * Vector3(0.3, 0.05, -1.5)
	director.muzzle_flash(from)
	var accuracy := 0.5 - distance * 0.008
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
		accuracy -= 0.15
	if player.stance == "crouch":
		accuracy -= 0.1
	elif player.stance == "prone":
		accuracy -= 0.2
	accuracy = clampf(accuracy, 0.05, 0.6)
	var target: Vector3 = player.global_position + Vector3(0, player.camera_height * 0.8, 0)
	if rng.randf() < accuracy:
		director.tracer(from, target)
		var heavy := kind == "apc"
		director.hurt_player(rng.randf_range(12.0, 20.0) if heavy else rng.randf_range(8.0, 13.0), "Makineli ateşi", global_position)
		if rng.randf() < 0.3 and not player.bleeding:
			director.start_bleeding()
	else:
		target += Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-0.6, 1.4), rng.randf_range(-2.0, 2.0))
		director.tracer(from, target)
	if shots.stream == null or shots.stream.resource_path != MG_SOUND:
		shots.stream = load(MG_SOUND)
	shots.global_position = from
	shots.volume_db = 0.0
	shots.pitch_scale = rng.randf_range(0.95, 1.05)
	shots.play()
	director.alert_noise(global_position, 60.0)


func report(path: String, at: Vector3, loudness: float) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(path)
	sound.unit_size = 25.0
	sound.max_distance = 260.0
	sound.volume_db = loudness
	director.add_effect(sound, 2.3)
	sound.global_position = at
	sound.play()


# Damage -------------------------------------------------------------------------------

func blast_target() -> Vector3:
	return global_position + Vector3.UP * 1.1


func take_explosion(damage: float) -> bool:
	if destroyed:
		return false
	hp = maxf(0.0, hp - damage)
	if hp > 0.0:
		return false
	destroyed = true
	speed = 0.0
	set_engine(false)
	var burnt := paint("burnt")
	for mesh in visuals:
		mesh.material_override = burnt
	# The turret is knocked askew; the wreck remains solid cover.
	if turret:
		turret.rotation.y += randf_range(-0.5, 0.5)
		turret.rotation.z = randf_range(-0.08, 0.08)
	if gun:
		gun.rotation.x = -0.1
	return true
