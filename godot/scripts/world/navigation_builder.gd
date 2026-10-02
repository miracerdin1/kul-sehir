extends NavigationRegion3D
# Where soldiers can walk: roads, pavements, house floors and stairs. Baked once in
# the background from the static boxes of the first street and the city. Doors,
# glass, vehicles and mines are left out: doorways stay open on the mesh (soldiers
# open closed doors as they reach them), and moving things are dodged by steering.

const CELL_SIZE := 0.2
const CELL_HEIGHT := 0.1

var baked := false
# A unit box as triangles, wound like Godot's own BoxMesh.
var box_faces := PackedVector3Array()


func build(roots: Array) -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
	var mesh := NavigationMesh.new()
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 42.0
	mesh.region_min_size = 4.0
	mesh.edge_max_error = 1.0
	var arrays := BoxMesh.new().get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		box_faces.append(vertices[index])
	var source := NavigationMeshSourceGeometryData3D.new()
	for root: Node in roots:
		collect(root, source)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func() -> void:
		navigation_mesh = mesh
		baked = true)


func collect(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	if node is AnimatableBody3D or node.is_in_group("breakable_glass") or node.is_in_group("armored_vehicle") or node.is_in_group("explosive"):
		return
	if node is StaticBody3D:
		for child in node.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and not child.disabled:
				var size: Vector3 = child.shape.size
				source.add_faces(box_faces, child.global_transform * Transform3D(Basis.from_scale(size), Vector3.ZERO))
	for child in node.get_children():
		collect(child, source)


# A walkable point on the mesh near a spot, or the spot itself before the bake ends.
func closest(point: Vector3) -> Vector3:
	if not baked:
		return point
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not baked:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)
