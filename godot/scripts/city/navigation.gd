extends NavigationRegion3D
# Walkable area for the soldiers: baked once at start from the street's and the city's
# static colliders (floors, stairs, upper storeys), so a path can lead through a
# doorway, up the stairs and along the upper floor. Doors and vehicles are left out
# of the bake: soldiers open doors as they reach them, and vehicles move.

signal baked

const SOURCE_GROUP := "navigation_source"

var ready_to_use := false
var bake_started := 0


func bake_from(sources: Array[Node]) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	# Fine cells: with the default 25 cm a doorway (1.4 m less the agent's width each
	# side) and the 1.15 m stair flight close up in the bake.
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, mesh.cell_height)
	mesh.agent_radius = 0.3
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 42.0
	mesh.region_min_size = 4.0
	mesh.filter_baking_aabb = AABB(Vector3(-100, -1, -90), Vector3(200, 9, 180))
	for source in sources:
		source.add_to_group(SOURCE_GROUP)
	# Doors and vehicles must not end up as walls in the bake.
	var hidden: Array[CollisionShape3D] = []
	for node in get_tree().get_nodes_in_group("armored_vehicle"):
		hidden.append_array(shapes(node))
	var city = sources.filter(func(source): return source.get("doors") != null)
	if not city.is_empty():
		for door: Dictionary in city[0].doors:
			hidden.append_array(shapes(door.leaf))
	for shape in hidden:
		shape.disabled = true
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, data, get_parent())
	for shape in hidden:
		shape.disabled = false
	bake_started = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, data, func(): finish.call_deferred(mesh))


func shapes(node: Node) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for child in node.find_children("*", "CollisionShape3D", true, false):
		if not child.disabled:
			found.append(child)
	return found


func finish(mesh: NavigationMesh) -> void:
	navigation_mesh = mesh
	ready_to_use = true
	print("Navigation baked in %d ms, %d polygons" % [Time.get_ticks_msec() - bake_started, mesh.get_polygon_count()])
	baked.emit()


# The closest walkable point, or Vector3.INF before the bake is done.
func snap(point: Vector3) -> Vector3:
	if not ready_to_use:
		return Vector3.INF
	return NavigationServer3D.map_get_closest_point(get_navigation_map(), point)
