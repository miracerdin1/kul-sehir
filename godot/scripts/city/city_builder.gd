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
const FLOOR_HEIGHT := 3.2
const DOOR_WIDTH := 1.1
const DOOR_LEAF := 0.98
const DOOR_HEIGHT := 2.3
const DOOR_VIEW_RANGE := 45.0
const STAIR_WIDTH := 1.15
const STAIR_RUN := 5.4

var surfaces
var rng := RandomNumberGenerator.new()
var materials := {}
var chunks: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var buildings: Array[Rect2] = []
# Doors that open with E: {pivot, leaf, closed, open_yaw, open}.
var doors: Array = []
# [foot, landing] of every staircase.
var stair_list: Array = []
var door_material: StandardMaterial3D
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
	for key: String in ["metal", "dark", "sand", "scorch", "wood"]:
		var material := StandardMaterial3D.new()
		material.albedo_color = {"metal": Color("3b3d3a"), "dark": Color("1d1f1f"), "sand": Color("837659"), "scorch": Color("15161599"), "wood": Color("5b4632")}[key]
		material.roughness = 0.6 if key == "metal" else 0.95
		material.metallic = 0.35 if key == "metal" else 0.0
		material.vertex_color_use_as_albedo = true
		if key == "scorch":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materials[key] = material
	door_material = materials.wood.duplicate()
	door_material.vertex_color_use_as_albedo = false
	door_material.albedo_color = Color("4d3b2b")


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
						var kind: String = pick(["ammo9", "bandage", "ammo762", "shell", "food", "food"])
						var amount := 1 if kind == "bandage" else rng.randi_range(1, 3) if kind == "food" else rng.randi_range(4, 10)
						loot.append([kind, amount, Vector3(middle.x + rng.randf_range(-4, 4), 0.06, middle.y + rng.randf_range(-4, 4))])
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


# A run of wall pieces, floor by floor: a framed doorway on the ground floor,
# windows with sills, and a broken top edge on the highest floor (wallRun).
func wall_run(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, from: Vector2, to: Vector2, floors: int, door: float, shade: float, middle: Vector2) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	var pieces := maxi(2, roundi(length / 3.2))
	var piece := length / pieces
	var door_index := mini(pieces - 1, int(pieces * door)) if door >= 0.0 else -1
	for index in range(pieces):
		var center := from + direction * piece * (index + 0.5)
		for level in range(floors):
			var base := level * FLOOR_HEIGHT
			var top := base + FLOOR_HEIGHT
			if level == floors - 1:
				var roll := rng.randf()
				if roll < 0.08:
					top = base + rng.randf_range(0.3, 0.7)
				elif roll < 0.4:
					top = base + FLOOR_HEIGHT * rng.randf_range(0.5, 0.88)
			if level == 0 and index == door_index:
				doorway(batch, body, chunk, material, center, direction, piece, top, shade, middle)
			elif top - base > 2.4 and rng.randf() < (0.3 if level == 0 else 0.55):
				window(batch, body, chunk, material, center, direction, piece, base, top, shade)
			else:
				wall_part(batch, body, chunk, material, center, direction, 0.0, piece + 0.04, base, top, shade)


# One stretch of wall, offset along the run from a piece's centre.
func wall_part(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, center: Vector2, direction: Vector2, offset: float, width: float, bottom: float, top: float, shade: float, depth := 0.36) -> void:
	if width <= 0.02 or top - bottom <= 0.02:
		return
	var at := center + direction * offset
	var along_x := absf(direction.x) > 0.5
	var box := Vector3(width, top - bottom, depth) if along_x else Vector3(depth, top - bottom, width)
	var world := Vector3(at.x, (bottom + top) / 2.0, at.y)
	batch.add(material, local(chunk, world), box, 0.0, shade)
	solid(body, chunk, world, box)


func window(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, center: Vector2, direction: Vector2, piece: float, base: float, top: float, shade: float) -> void:
	var opening := minf(1.3, piece - 0.9)
	var side := (piece - opening) / 2.0
	var sill := base + 0.95
	var head := minf(top, base + 2.2)
	wall_part(batch, body, chunk, material, center, direction, 0.0, piece + 0.04, base, sill, shade)
	wall_part(batch, body, chunk, material, center, direction, 0.0, piece + 0.04, head, top, shade)
	for sign in [-1.0, 1.0]:
		wall_part(batch, body, chunk, material, center, direction, sign * (opening + side) / 2.0, side + 0.04, sill, head, shade)
	# A concrete sill sticking out both sides, and now and then a board nailed across.
	wall_part(batch, body, chunk, materials.concrete, center, direction, 0.0, opening + 0.2, sill, sill + 0.08, shade * 0.85, 0.5)
	if rng.randf() < 0.3:
		var along_x := absf(direction.x) > 0.5
		var board := Vector3(opening + 0.3, 0.16, 0.04) if along_x else Vector3(0.04, 0.16, opening + 0.3)
		var lean := rng.randf_range(-0.25, 0.25)
		batch.add(materials.wood, local(chunk, Vector3(center.x, sill + rng.randf_range(0.4, 0.9), center.y)), board, 0.0, 0.8, Vector2(0, lean) if along_x else Vector2(lean, 0))


# A doorway one door wide, with a wooden frame and often a door that opens with E.
func doorway(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, material: Material, center: Vector2, direction: Vector2, piece: float, top: float, shade: float, middle: Vector2) -> void:
	var side := (piece - DOOR_WIDTH) / 2.0
	var wall_top := maxf(top, DOOR_HEIGHT + 0.3)
	for sign in [-1.0, 1.0]:
		wall_part(batch, body, chunk, material, center, direction, sign * (DOOR_WIDTH + side) / 2.0, side + 0.04, 0.0, wall_top, shade)
		wall_part(batch, body, chunk, materials.wood, center, direction, sign * (DOOR_WIDTH / 2.0 - 0.05), 0.1, 0.0, DOOR_HEIGHT, 0.9, 0.44)
	wall_part(batch, body, chunk, material, center, direction, 0.0, DOOR_WIDTH + 0.04, DOOR_HEIGHT, wall_top, shade)
	wall_part(batch, body, chunk, materials.wood, center, direction, 0.0, DOOR_WIDTH, DOOR_HEIGHT - 0.1, DOOR_HEIGHT, 0.9, 0.44)
	if rng.randf() < 0.7:
		make_door(chunk, center - direction * (DOOR_WIDTH / 2.0 - 0.1), direction, middle)


func make_door(chunk: Node3D, hinge: Vector2, direction: Vector2, middle: Vector2) -> void:
	var pivot := Node3D.new()
	pivot.position = local(chunk, Vector3(hinge.x, 0.0, hinge.y))
	# Local +x runs along the wall from the hinge across the doorway.
	var closed := atan2(-direction.y, direction.x)
	pivot.rotation.y = closed
	chunk.add_child(pivot)
	var leaf := AnimatableBody3D.new()
	leaf.position = Vector3(DOOR_LEAF / 2.0, DOOR_HEIGHT / 2.0 - 0.04, 0)
	pivot.add_child(leaf)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_LEAF, DOOR_HEIGHT - 0.12, 0.07)
	shape.shape = box
	leaf.add_child(shape)
	var mesh := MeshInstance3D.new()
	var panel := BoxMesh.new()
	panel.size = box.size
	mesh.mesh = panel
	mesh.material_override = door_material
	mesh.visibility_range_end = DOOR_VIEW_RANGE
	leaf.add_child(mesh)
	var handle := MeshInstance3D.new()
	var knob := BoxMesh.new()
	knob.size = Vector3(0.12, 0.04, 0.16)
	handle.mesh = knob
	handle.material_override = materials.metal
	handle.position = Vector3(DOOR_LEAF / 2.0 - 0.12, -0.1, 0)
	handle.visibility_range_end = DOOR_VIEW_RANGE / 2.0
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(handle)
	# The door swings into the building.
	var inward := closed + 1.75
	var outward := closed - 1.75
	var tip_in := hinge + Vector2(cos(inward), -sin(inward))
	var tip_out := hinge + Vector2(cos(outward), -sin(outward))
	if tip_out.distance_to(middle) < tip_in.distance_to(middle):
		inward = outward
	var open := rng.randf() < 0.55
	if open:
		pivot.rotation.y = lerp_angle(closed, inward, rng.randf_range(0.45, 1.0))
	doors.append({"pivot": pivot, "leaf": leaf, "closed": closed, "open_yaw": inward, "open": open})


# Open or close a door; the panel swings over a third of a second.
func toggle_door(door: Dictionary) -> void:
	door.open = not door.open
	var tween: Tween = door.pivot.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(door.pivot, "rotation:y", door.open_yaw if door.open else door.closed, 0.35).set_trans(Tween.TRANS_SINE)


# The closest door within reach of a point, or an empty dictionary.
func nearest_door(from: Vector3, reach := 1.6) -> Dictionary:
	var best := {}
	for door: Dictionary in doors:
		var leaf: Node3D = door.leaf
		var distance := Vector2(from.x, from.z).distance_to(Vector2(leaf.global_position.x, leaf.global_position.z))
		if distance < reach:
			reach = distance
			best = door
	return best


# An enterable shell: walls with doorways and windows, a floor slab and stairs
# in two-storey buildings, a broken roof, rubble inside, and supplies (makeBuilding).
func make_building(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, middle: Vector2, size: Vector2) -> void:
	var floors := 2 if rng.randf() < 0.5 else 1
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
		wall_run(batch, body, chunk, material, sides[index][0], sides[index][1], floors, door, shade, middle)
	var hole := Rect2()
	if floors == 2:
		var free: Array = range(4).filter(func(side): return side != door_side and side != second_door)
		var wall: Array = sides[free[rng.randi() % free.size()]]
		hole = stairs(batch, body, chunk, wall[0], wall[1], middle, shade)
		var inner := Rect2(low + Vector2(0.18, 0.18), size - Vector2(0.36, 0.36))
		for part: Rect2 in cut(inner, hole):
			var at := Vector3(part.get_center().x, FLOOR_HEIGHT - 0.1, part.get_center().y)
			batch.add(materials.concrete, local(chunk, at), Vector3(part.size.x, 0.2, part.size.y), 0.0, shade * 0.88)
			solid(body, chunk, at, Vector3(part.size.x, 0.2, part.size.y))
		for index in range(rng.randi_range(2, 5)):
			var spot := free_spot(low, high, hole)
			batch.add(materials.rubble, local(chunk, Vector3(spot.x, FLOOR_HEIGHT + 0.1, spot.y)), Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.12, 0.3), rng.randf_range(0.3, 0.9)), rng.randf_range(0, 3), 0.85)
	# A broken roof slab over part of the top floor.
	if rng.randf() < 0.62:
		var roof := size * Vector2(rng.randf_range(0.55, 1.0), rng.randf_range(0.6, 1.0))
		var corner := low + roof / 2.0 + (size - roof) * Vector2(rng.randi_range(0, 1), rng.randi_range(0, 1))
		var at := Vector3(corner.x, floors * FLOOR_HEIGHT - 0.15, corner.y)
		batch.add(materials.concrete, local(chunk, at), Vector3(roof.x, 0.3, roof.y), 0.0, shade * 0.9)
		solid(body, chunk, at, Vector3(roof.x, 0.3, roof.y))
		for index in range(rng.randi_range(0, 5)):
			var lump := Vector3(corner.x + rng.randf_range(-roof.x, roof.x) / 3.0, at.y + 0.25 + rng.randf_range(0, 0.3), corner.y + rng.randf_range(-roof.y, roof.y) / 3.0)
			batch.add(materials.rubble, local(chunk, lump), Vector3(rng.randf_range(0.4, 1.2), rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 1.2)), rng.randf_range(0, 3), 0.8, Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
	for index in range(rng.randi_range(2, 5)):
		var spot := free_spot(low, high, hole)
		batch.add(materials.rubble, local(chunk, Vector3(spot.x, 0.12, spot.y)), Vector3(rng.randf_range(0.3, 1.0), rng.randf_range(0.12, 0.35), rng.randf_range(0.3, 1.0)), rng.randf_range(0, 3), 0.85, Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
	# Supplies on every floor, ammunition and bandages now and then.
	for level in range(floors):
		for index in range(rng.randi_range(0, 2) + (1 if rng.randf() < 0.6 else 0)):
			var spot := free_spot(low, high, hole)
			var kind: String = weighted([["food", 6], ["water", 3]])
			loot.append([kind, rng.randi_range(1, 3) if kind == "food" else rng.randi_range(1, 2), Vector3(spot.x, level * FLOOR_HEIGHT + 0.06, spot.y)])
		if rng.randf() < 0.35:
			var spot := free_spot(low, high, hole)
			var kind: String = weighted([["ammo9", 15], ["ammo762", 10], ["shell", 9], ["bandage", 10]])
			loot.append([kind, rng.randi_range(5, 12) if kind != "bandage" else 1, Vector3(spot.x, level * FLOOR_HEIGHT + 0.06, spot.y)])


# A straight concrete flight along one wall up to the first floor. Returns the
# stairwell, which the floor slab leaves open.
func stairs(batch: BoxBatch, body: StaticBody3D, chunk: Node3D, from: Vector2, to: Vector2, middle: Vector2, shade: float) -> Rect2:
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	if (middle - from).dot(normal) < 0.0:
		normal = -normal
	var start := from + direction * 1.4 + normal * (0.18 + STAIR_WIDTH / 2.0)
	var steps := 16
	var rise := FLOOR_HEIGHT / steps
	var tread := STAIR_RUN / steps
	var along_x := absf(direction.x) > 0.5
	for index in range(steps):
		var at := start + direction * tread * (index + 0.5)
		var height := rise * (index + 1)
		var box := Vector3(tread + 0.01, height, STAIR_WIDTH) if along_x else Vector3(STAIR_WIDTH, height, tread + 0.01)
		batch.add(materials.concrete, local(chunk, Vector3(at.x, height / 2.0, at.y)), box, 0.0, shade * (0.95 if index % 2 else 0.85))
	# The survivor walks on a smooth ramp under the step edges.
	var run := Vector3(direction.x * STAIR_RUN, FLOOR_HEIGHT, direction.y * STAIR_RUN)
	var x_axis := run.normalized()
	var y_axis := Vector3(-direction.x * FLOOR_HEIGHT, STAIR_RUN, -direction.y * FLOOR_HEIGHT).normalized()
	var basis := Basis(x_axis, y_axis, x_axis.cross(y_axis))
	var shape := CollisionShape3D.new()
	var ramp := BoxShape3D.new()
	ramp.size = Vector3(run.length() + 0.2, 0.3, STAIR_WIDTH)
	shape.shape = ramp
	shape.transform = Transform3D(basis, local(chunk, Vector3(start.x, 0, start.y) + run / 2.0 - y_axis * 0.15))
	body.add_child(shape)
	# A rail along the open side.
	var rail_mid := start + direction * STAIR_RUN / 2.0 + normal * (STAIR_WIDTH / 2.0 + 0.04)
	batch.add_basis(materials.metal, local(chunk, Vector3(rail_mid.x, FLOOR_HEIGHT / 2.0 + 0.95, rail_mid.y)), Vector3(run.length(), 0.06, 0.06), basis)
	var end := start + direction * STAIR_RUN
	stair_list.append([Vector3(start.x - direction.x * 0.9, 0.1, start.y - direction.y * 0.9), Vector3(end.x + direction.x * 0.9, FLOOR_HEIGHT + 0.1, end.y + direction.y * 0.9)])
	var a := start - normal * STAIR_WIDTH / 2.0
	var b := end + normal * STAIR_WIDTH / 2.0
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(0.05)


# The parts of a rectangle left around a hole inside it.
func cut(outer: Rect2, hole: Rect2) -> Array[Rect2]:
	var parts: Array[Rect2] = []
	if not outer.intersects(hole):
		parts.append(outer)
		return parts
	var inner := outer.intersection(hole)
	if inner.position.y > outer.position.y:
		parts.append(Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)))
	if inner.end.y < outer.end.y:
		parts.append(Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, outer.end.y - inner.end.y)))
	if inner.position.x > outer.position.x:
		parts.append(Rect2(Vector2(outer.position.x, inner.position.y), Vector2(inner.position.x - outer.position.x, inner.size.y)))
	if inner.end.x < outer.end.x:
		parts.append(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(outer.end.x - inner.end.x, inner.size.y)))
	return parts


func inside(low: Vector2, high: Vector2) -> Vector2:
	return Vector2(rng.randf_range(low.x + 1.4, high.x - 1.4), rng.randf_range(low.y + 1.4, high.y - 1.4))


# A spot inside the walls clear of the stairwell.
func free_spot(low: Vector2, high: Vector2, avoid: Rect2) -> Vector2:
	var spot := inside(low, high)
	for attempt in range(12):
		if not avoid.grow(0.6).has_point(spot):
			return spot
		spot = inside(low, high)
	return spot


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
