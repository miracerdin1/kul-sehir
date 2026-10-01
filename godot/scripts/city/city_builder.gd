extends Node3D
# The ruined city around the first street (buildWorld in the HTML): a grid of
# blocks with enterable building shells, rubble, wrecks, sandbags and loot, out
# to a ring of collapsed blocks. street.gd keeps the first street in the middle.

const AssetFactory = preload("res://scripts/asset_factory.gd")
const BoxBatch = preload("res://scripts/city/box_batch.gd")

# Road centre lines. The first street is the x = 0 road between z -29 and 29.
const ROADS_X: Array[float] = [-88.0, -44.0, 0.0, 44.0, 88.0]
const ROADS_Z: Array[float] = [-77.0, -33.0, 33.0, 77.0]
const ROAD_HALF := 5.0
const BOUND := Vector2(97.0, 86.0)
# street.gd owns this ground rectangle (x, z, width, depth).
const STREET_AREA := Rect2(-15.0, -30.0, 30.0, 60.0)
# Line of road barriers across the first street (street.gd create_props).
const BARRIER_Z := -26.0
const VIEW_RANGE := 135.0
const LOW_VIEW_RANGE := 90.0

var surfaces
var rng := RandomNumberGenerator.new()
var materials := {}
var chunks: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var buildings: Array[Rect2] = []
# Road points soldiers patrol between (world.nodes).
var nodes: Array[Vector3] = []
# [kind, amount, position] for the combat director to place.
var loot: Array = []
var assets := AssetFactory.new()


func setup(street_surfaces) -> void:
	surfaces = street_surfaces


func _ready() -> void:
	name = "City"
	rng.seed = 4410026
	create_materials()
	create_ground()
	for x in range(ROADS_X.size() - 1):
		for z in range(ROADS_Z.size() + 1):
			create_block(x, z)
	create_boundary()
	create_street_props()
	create_nodes()
	place_key_loot()


func create_materials() -> void:
	var sources := {
		"concrete": ["blue_plaster_weathered", Color("8f918a"), 0.3],
		"plaster": ["blue_plaster_weathered", Color("a99d8a"), 0.35],
		"brick": ["brick_wall_001", Color("9a958c"), 0.3],
		"rubble": ["rubble", Color("8c8c84"), 0.6],
		"pad": ["blue_plaster_weathered", Color("77786f"), 0.22],
	}
	for key: String in sources:
		var source: Array = sources[key]
		var material: StandardMaterial3D = surfaces.textured(source[0], source[1], source[2]).duplicate()
		material.vertex_color_use_as_albedo = true
		materials[key] = material
	for key: String in ["metal", "dark", "sand", "scorch"]:
		var material := StandardMaterial3D.new()
		material.albedo_color = {"metal": Color("3b3d3a"), "dark": Color("1d1f1f"), "sand": Color("837659"), "scorch": Color("15161599")}[key]
		material.roughness = 0.6 if key == "metal" else 0.95
		material.metallic = 0.35 if key == "metal" else 0.0
		material.vertex_color_use_as_albedo = true
		if key == "scorch":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materials[key] = material


func create_ground() -> void:
	var asphalt: Material = surfaces.textured("aerial_asphalt_01", Color("999c9b"), 0.19)
	var size := Vector2(BOUND.x * 2.0 + 60.0, BOUND.y * 2.0 + 60.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	ground.mesh = plane
	ground.material_override = asphalt
	ground.position.y = -0.02
	add_child(ground)
	AssetFactory.collider(self, Vector3(size.x, 0.4, size.y), Vector3(0, -0.2, 0))


func road_span(roads: Array[float], index: int, outer: float) -> Vector2:
	var low := -outer if index == 0 else roads[index - 1] + ROAD_HALF
	var high := outer if index == roads.size() else roads[index] - ROAD_HALF
	return Vector2(low, high)


# One block between roads: a pavement pad and buildings or rubble lots on it.
func create_block(ix: int, iz: int) -> void:
	var span_x := Vector2(ROADS_X[ix] + ROAD_HALF, ROADS_X[ix + 1] - ROAD_HALF)
	var span_z := road_span(ROADS_Z, iz, BOUND.y - 6.0)
	if span_z.y - span_z.x < 12.0:
		return
	var center := Vector3((span_x.x + span_x.y) / 2.0, 0, (span_z.x + span_z.y) / 2.0)
	var chunk := make_chunk(center)
	var batch := BoxBatch.new()
	var body: StaticBody3D = chunk.get_meta("body")
	var area := Rect2(span_x.x, span_z.x, span_x.y - span_x.x, span_z.y - span_z.x)
	# Blocks beside the first street leave its building row alone.
	if area.intersects(STREET_AREA):
		if center.x > 0.0:
			area = Rect2(STREET_AREA.end.x + 1.0, area.position.y, area.end.x - STREET_AREA.end.x - 1.0, area.size.y)
		else:
			area = Rect2(area.position.x, area.position.y, STREET_AREA.position.x - 1.0 - area.position.x, area.size.y)
	batch.add(materials.pad, local(chunk, Vector3(area.get_center().x, 0.03, area.get_center().y)), Vector3(area.size.x, 0.06, area.size.y))
	var columns := maxi(1, int(area.size.x / 16.0))
	var rows := maxi(1, int(area.size.y / 16.0))
	var cell := Vector2(area.size.x / columns, area.size.y / rows)
	if rng.randf() < 0.2 and columns == 2 and rows == 2:
		make_building(batch, body, chunk, area.get_center(), area.size - Vector2(rng.randf_range(8, 12), rng.randf_range(8, 12)))
	else:
		for column in range(columns):
			for row in range(rows):
				var middle := area.position + cell * Vector2(column + 0.5, row + 0.5)
				middle += Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
				if rng.randf() < 0.78:
					var size := Vector2(rng.randf_range(9.0, minf(12.6, cell.x - 3.0)), rng.randf_range(9.0, minf(12.6, cell.y - 3.0)))
					make_building(batch, body, chunk, middle, size)
				else:
					rubble_pile(batch, body, chunk, Vector3(middle.x + rng.randf_range(-3, 3), 0, middle.y + rng.randf_range(-3, 3)), rng.randf_range(0.8, 1.4))
					if rng.randf() < 0.6:
						loot.append([pick(["ammo9", "bandage", "ammo762", "shell"]), rng.randi_range(4, 10), Vector3(middle.x + rng.randf_range(-4, 4), 0.06, middle.y + rng.randf_range(-4, 4))])
	meshes.append_array(batch.commit(chunk, VIEW_RANGE))


func make_chunk(center: Vector3) -> Node3D:
	var chunk := Node3D.new()
	chunk.position = center
	add_child(chunk)
	var body := StaticBody3D.new()
	chunk.add_child(body)
	chunk.set_meta("body", body)
	chunks.append(chunk)
	return chunk


func local(chunk: Node3D, world: Vector3) -> Vector3:
	return world - chunk.position


func solid(body: StaticBody3D, chunk: Node3D, world: Vector3, size: Vector3, yaw := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, yaw), local(chunk, world))
	body.add_child(shape)


# A run of wall pieces with a doorway, broken tops and the odd window (wallRun).
func wall_run(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, from: Vector2, to: Vector2, height: float, door: float, shade: float) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var pieces := maxi(2, roundi(length / 3.2))
	var piece := length / pieces
	var door_index := mini(pieces - 1, int(pieces * door)) if door >= 0.0 else -1
	for index in range(pieces):
		var middle := from + direction * piece * (index + 0.5)
		var size := Vector3(piece + 0.04, 0, 0.36) if along_x else Vector3(0.36, 0, piece + 0.04)
		if index == door_index:
			if height > 2.7:
				var top := minf(height, 2.4 + rng.randf_range(0.5, 1.4))
				add_wall(batch, body, chunk, material, middle, size, 2.4, top, shade)
			continue
		var roll := rng.randf()
		if roll < 0.07:
			add_wall(batch, body, chunk, material, middle, size, 0.0, 0.4, shade * 0.8)
			continue
		var top := height * (rng.randf_range(0.3, 0.8) if roll < 0.42 else rng.randf_range(0.9, 1.0))
		top = maxf(top, 1.1)
		if top > 2.5 and rng.randf() < 0.32:
			add_wall(batch, body, chunk, material, middle, size, 0.0, 1.0, shade)
			add_wall(batch, body, chunk, material, middle, size, 2.05, top, shade)
		else:
			add_wall(batch, body, chunk, material, middle, size, 0.0, top, shade)


func add_wall(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, middle: Vector2, size: Vector3, bottom: float, top: float, shade: float) -> void:
	var world := Vector3(middle.x, (bottom + top) / 2.0, middle.y)
	var box := Vector3(size.x, top - bottom, size.z)
	batch.add(material, local(chunk, world), box, 0.0, shade)
	solid(body, chunk, world, box)


# An enterable shell: four broken walls, doorways, a partial roof slab, rubble
# inside and sometimes something worth taking (makeBuilding).
func make_building(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, middle: Vector2, size: Vector2) -> void:
	var floors := 2 if rng.randf() < 0.45 else 1
	var height := floors * 3.1 + rng.randf_range(0, 0.5)
	var material: Material = materials[pick(["concrete", "concrete", "brick", "plaster"])]
	var shade := rng.randf_range(0.82, 1.05)
	var low := middle - size / 2.0
	var high := middle + size / 2.0
	buildings.append(Rect2(low, size))
	var door_side := rng.randi_range(0, 3)
	var second_door := rng.randi_range(0, 3) if rng.randf() < 0.4 else -1
	var sides := [
		[Vector2(low.x, high.y), Vector2(high.x, high.y)], [Vector2(high.x, low.y), Vector2(low.x, low.y)],
		[Vector2(low.x, low.y), Vector2(low.x, high.y)], [Vector2(high.x, high.y), Vector2(high.x, low.y)],
	]
	for index in range(4):
		var door := -1.0
		if index == door_side:
			door = rng.randf_range(0.35, 0.65)
		elif index == second_door:
			door = rng.randf_range(0.2, 0.8)
		wall_run(batch, body, chunk, material, sides[index][0], sides[index][1], height, door, shade)
	if rng.randf() < 0.62:
		var roof := size * Vector2(rng.randf_range(0.55, 1.0), rng.randf_range(0.6, 1.0))
		var corner := low + roof / 2.0 + (size - roof) * Vector2(rng.randi_range(0, 1), rng.randi_range(0, 1))
		var at := Vector3(corner.x, 3.05, corner.y)
		batch.add(materials.concrete, local(chunk, at), Vector3(roof.x, 0.3, roof.y), 0.0, shade * 0.9)
		solid(body, chunk, at, Vector3(roof.x, 0.3, roof.y))
		if floors == 2 and rng.randf() < 0.5:
			for index in range(5):
				var lump := Vector3(corner.x + rng.randf_range(-roof.x, roof.x) / 3.0, 3.3 + rng.randf_range(0, 0.3), corner.y + rng.randf_range(-roof.y, roof.y) / 3.0)
				batch.add(materials.rubble, local(chunk, lump), Vector3(rng.randf_range(0.4, 1.2), rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 1.2)), rng.randf_range(0, 3), 0.8, Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
	for index in range(rng.randi_range(2, 5)):
		var spot := inside(low, high)
		batch.add(materials.rubble, local(chunk, Vector3(spot.x, 0.12, spot.y)), Vector3(rng.randf_range(0.3, 1.0), rng.randf_range(0.12, 0.35), rng.randf_range(0.3, 1.0)), rng.randf_range(0, 3), 0.85, Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
	if rng.randf() < 0.45:
		var spot := inside(low, high)
		var kind: String = weighted([["ammo9", 15], ["ammo762", 10], ["shell", 9], ["bandage", 10]])
		loot.append([kind, rng.randi_range(5, 12) if kind != "bandage" else 1, Vector3(spot.x, 0.06, spot.y)])


func inside(low: Vector2, high: Vector2) -> Vector2:
	return Vector2(rng.randf_range(low.x + 1.4, high.x - 1.4), rng.randf_range(low.y + 1.4, high.y - 1.4))


func rubble_pile(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, at: Vector3, size: float) -> void:
	var material: Material = materials[pick(["rubble", "rubble", "brick"])]
	var core := Vector3(rng.randf_range(1.2, 2.2), 0.7, rng.randf_range(1.2, 2.2)) * size
	var yaw := rng.randf_range(0, 3)
	batch.add(material, local(chunk, at + Vector3(0, core.y / 2.0, 0)), core, yaw, 0.85)
	solid(body, chunk, at + Vector3(0, core.y / 2.0, 0), core, yaw)
	for index in range(rng.randi_range(5, 10)):
		var offset := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(0.1, 0.5), rng.randf_range(-1.6, 1.6)) * size
		batch.add(material, local(chunk, at + offset), Vector3(rng.randf_range(0.25, 1.0), rng.randf_range(0.2, 0.5), rng.randf_range(0.25, 1.0)) * size, rng.randf_range(0, 3), rng.randf_range(0.7, 1.0), Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)))
	if rng.randf() < 0.4:
		batch.add(materials.dark, local(chunk, at + Vector3(rng.randf_range(-1, 1), 0.5, rng.randf_range(-1, 1))), Vector3(0.12, rng.randf_range(1.5, 3.0), 0.12), rng.randf_range(0, 3), 1.0, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1.2, 1.2)))


# Collapsed blocks all round the edge, and an invisible wall just inside them.
func create_boundary() -> void:
	for side in [-1.0, 1.0]:
		for horizontal in [true, false]:
			var extent: float = BOUND.x if horizontal else BOUND.y
			var edge: float = (BOUND.y if horizontal else BOUND.x) + 6.0
			var center := Vector3(0, 0, side * edge) if horizontal else Vector3(side * edge, 0, 0)
			var chunk := make_chunk(center)
			var batch := BoxBatch.new()
			var t := -extent - 8.0
			while t <= extent + 8.0:
				var at := Vector3(t + rng.randf_range(-1, 1), 0, side * edge + rng.randf_range(-1.5, 1.5)) if horizontal else Vector3(side * edge + rng.randf_range(-1.5, 1.5), 0, t + rng.randf_range(-1, 1))
				var size := Vector3(rng.randf_range(5, 8), rng.randf_range(3, 6), rng.randf_range(4, 7))
				if not horizontal:
					size = Vector3(size.z, size.y, size.x)
				at.y = rng.randf_range(1.5, 3.0)
				batch.add(materials.rubble, local(chunk, at), size, rng.randf_range(-0.3, 0.3), 0.7)
				t += 6.0
			var wall := Vector3(extent * 2.0 + 20.0, 8.0, 0.5) if horizontal else Vector3(0.5, 8.0, extent * 2.0 + 20.0)
			var inner := Vector3(0, 4.0, side * (edge - 4.0)) if horizontal else Vector3(side * (edge - 4.0), 4.0, 0)
			solid(chunk.get_meta("body"), chunk, inner, wall)
			meshes.append_array(batch.commit(chunk, VIEW_RANGE + 40.0))


# A point on a road, away from the first street (streetPt).
func road_point() -> Vector3:
	for attempt in range(20):
		var along := rng.randf_range(-BOUND.x + 6.0, BOUND.x - 6.0)
		var point: Vector3
		if rng.randf() < 0.5:
			point = Vector3(pick(ROADS_X) + rng.randf_range(-4, 4), 0, rng.randf_range(-BOUND.y + 6.0, BOUND.y - 6.0))
		else:
			point = Vector3(along, 0, pick(ROADS_Z) + rng.randf_range(-4, 4))
		if not STREET_AREA.grow(3.0).has_point(Vector2(point.x, point.z)):
			return point
	return Vector3(ROADS_X[0], 0, ROADS_Z[0])


# Wrecks, rubble, sandbag walls, poles, scorch marks and two tanks on the roads.
func create_street_props() -> void:
	var chunk := make_chunk(Vector3.ZERO)
	var batch := BoxBatch.new()
	var body: StaticBody3D = chunk.get_meta("body")
	for index in range(12):
		burnt_car(batch, body, chunk, road_point(), rng.randf_range(0, TAU))
	for index in range(32):
		rubble_pile(batch, body, chunk, road_point(), rng.randf_range(0.5, 1.1))
	for index in range(7):
		sandbags(batch, body, chunk, road_point(), rng.randf_range(0, TAU), rng.randf_range(3, 5))
	for index in range(14):
		var at := road_point()
		var tilt := rng.randf() < 0.4
		var lean := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) if tilt else Vector2.ZERO
		batch.add(materials.dark, local(chunk, at + Vector3(0, 2.6, 0)), Vector3(0.16, 5.2, 0.16), 0.0, 1.0, lean)
		if not tilt:
			solid(body, chunk, at + Vector3(0, 2.6, 0), Vector3(0.16, 5.2, 0.16))
	for index in range(12):
		var at := road_point()
		var radius := rng.randf_range(1.5, 3.5)
		batch.add(materials.scorch, local(chunk, at + Vector3(0, 0.012, 0)), Vector3(radius * 2.0, 0.01, radius * 1.6), rng.randf_range(0, TAU))
	for index in range(2):
		var at := road_point()
		tank(batch, body, chunk, at, rng.randf_range(0, TAU))
		loot.append(["ammo762", rng.randi_range(10, 20), at + Vector3(rng.randf_range(-4, 4), 0.02, 4.5)])
	# Spread over the whole map, so this mesh has no view range.
	meshes.append_array(batch.commit(chunk, 0.0))


func burnt_car(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	batch.add(materials.metal, local(chunk, at + Vector3(0, 0.7, 0)), Vector3(4.2, 0.75, 1.85), yaw, rng.randf_range(0.8, 1.1))
	solid(body, chunk, at + Vector3(0, 0.75, 0), Vector3(4.2, 1.5, 1.85), yaw)
	batch.add(materials.metal, local(chunk, at + basis * Vector3(-0.2, 1.35, 0)), Vector3(2.1, 0.6, 1.65), yaw, 0.9)
	for wheel in [Vector2(-1.3, 0.95), Vector2(1.3, 0.95), Vector2(-1.3, -0.95), Vector2(1.3, -0.95)]:
		batch.add(materials.dark, local(chunk, at + basis * Vector3(wheel.x, 0.35, wheel.y)), Vector3(0.7, 0.7, 0.25), yaw, 0.6)


func tank(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	batch.add(materials.metal, local(chunk, at + Vector3(0, 1.1, 0)), Vector3(7, 1.3, 3.4), yaw, 1.2)
	solid(body, chunk, at + Vector3(0, 1.1, 0), Vector3(7, 2.2, 3.4), yaw)
	for track in [1.9, -1.9]:
		batch.add(materials.dark, local(chunk, at + basis * Vector3(0, 0.6, track)), Vector3(7.4, 1.1, 0.8), yaw)
	batch.add(materials.metal, local(chunk, at + basis * Vector3(-0.5, 2.2, 0)), Vector3(3, 0.9, 2.6), yaw + 0.35, 1.1)
	var turret := Basis(Vector3.UP, yaw + 0.35)
	batch.add(materials.dark, local(chunk, at + basis * Vector3(-0.5, 0, 0) + turret * Vector3(-2.7, 2.15, 0)), Vector3(4.0, 0.22, 0.22), yaw + 0.35, 1.0, Vector2(0, -0.12))


func sandbags(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, at: Vector3, yaw: float, length: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var count := roundi(length / 0.9)
	for row in range(3):
		for index in range(count):
			var along := (index - (count - 1) / 2.0) * 0.88 + (0.44 if row % 2 else 0.0)
			batch.add(materials.sand, local(chunk, at + basis * Vector3(along, 0.16 + row * 0.3, 0)), Vector3(0.86, 0.3, 0.46), yaw + rng.randf_range(-0.05, 0.05), rng.randf_range(0.85, 1.05))
	solid(body, chunk, at + Vector3(0, 0.45, 0), Vector3(length + 0.4, 0.9, 0.5), yaw)


func create_nodes() -> void:
	for x in ROADS_X:
		for z in ROADS_Z:
			nodes.append(Vector3(x, 0.1, z))
	for x in ROADS_X:
		for index in range(ROADS_Z.size() - 1):
			nodes.append(Vector3(x, 0.1, (ROADS_Z[index] + ROADS_Z[index + 1]) / 2.0))
	for z in ROADS_Z:
		for index in range(ROADS_X.size() - 1):
			nodes.append(Vector3((ROADS_X[index] + ROADS_X[index + 1]) / 2.0, 0.1, z))


# Both points lie on one road, so walking between them stays off the blocks.
func on_same_road(a: Vector3, b: Vector3) -> bool:
	for x in ROADS_X:
		if absf(a.x - x) < 6.0 and absf(b.x - x) < 6.0:
			# The concrete barriers close the first street's north end.
			if x == 0.0 and (a.z < BARRIER_Z) != (b.z < BARRIER_Z):
				continue
			return true
	for z in ROADS_Z:
		if absf(a.z - z) < 6.0 and absf(b.z - z) < 6.0:
			return true
	return false


# Guns placed like the HTML: a shotgun near the start, the rest further out.
func place_key_loot() -> void:
	var start := Vector2(0, 15)
	var near: Array[Rect2] = []
	var far: Array[Rect2] = []
	for building in buildings:
		(near if building.get_center().distance_to(start) < 60.0 else far).append(building)
	var order := func(list: Array[Rect2]) -> void:
		for index in range(list.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var swap := list[index]
			list[index] = list[other]
			list[other] = swap
	order.call(near)
	order.call(far)
	var place := func(kind: String, amount: int, list: Array[Rect2]) -> void:
		if list.is_empty():
			return
		var building: Rect2 = list.pop_back()
		var spot := inside(building.position, building.end)
		loot.append([kind, amount, Vector3(spot.x, 0.06, spot.y)])
	place.call("shotgun", 4, near)
	place.call("shell", 8, near)
	place.call("ammo9", 10, near)
	place.call("bandage", 1, near)
	for index in range(3):
		place.call("pistol", rng.randi_range(4, 10), far)
		place.call("rifle", rng.randi_range(10, 25), far)
	for index in range(2):
		place.call("shotgun", rng.randi_range(2, 6), far)
		place.call("knife", 1, far)


# Nearer view range on the performance setting.
func set_low_quality(low: bool) -> void:
	for instance in meshes:
		if instance.visibility_range_end > 0.0:
			instance.visibility_range_end = LOW_VIEW_RANGE if low else VIEW_RANGE


func pick(options: Array):
	return options[rng.randi() % options.size()]


func weighted(options: Array) -> String:
	var total := 0
	for option: Array in options:
		total += option[1]
	var roll := rng.randi_range(0, total - 1)
	for option: Array in options:
		roll -= option[1]
		if roll < 0:
			return option[0]
	return options[0][0]
