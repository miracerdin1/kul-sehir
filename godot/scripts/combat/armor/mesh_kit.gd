extends RefCounted
# Builds one ArrayMesh from boxes, slabs and cylinders, one surface per material.
# Vertex colour carries per-part shade. Every triangle is wound so it faces out.

var tools := {}


func tool_for(material: Material) -> SurfaceTool:
	if not tools.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[material] = surface
	return tools[material]


# One triangle; swapped if needed so (b - a) x (c - a) points along outward, the
# winding the box batches use.
func tri(surface: SurfaceTool, points: Array, normals: Array, outward: Vector3, color: Color, uvs := []) -> void:
	var order := [0, 1, 2]
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(outward) < 0.0:
		order = [0, 2, 1]
	for index in order:
		surface.set_normal(normals[index])
		surface.set_color(color)
		surface.set_uv(uvs[index] if not uvs.is_empty() else Vector2(points[index].x + points[index].z, points[index].y))
		surface.add_vertex(points[index])


func quad(surface: SurfaceTool, corners: Array, normal: Vector3, shade: float) -> void:
	var color := Color(shade, shade, shade)
	var normals := [normal, normal, normal]
	tri(surface, [corners[0], corners[1], corners[2]], normals, normal, color)
	tri(surface, [corners[0], corners[2], corners[3]], normals, normal, color)


func box(material: Material, center: Vector3, size: Vector3, basis := Basis.IDENTITY, shade := 1.0) -> void:
	var surface := tool_for(material)
	var half := size / 2.0
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var middle: Vector3 = normal * half
		var u: Vector3 = face[1] * half
		var s: Vector3 = face[2] * half
		var corners := []
		for corner in [middle - u - s, middle + u - s, middle + u + s, middle - u + s]:
			corners.append(center + basis * corner)
		quad(surface, corners, (basis * normal).normalized(), shade)


# A six-sided solid between a lower and an upper rectangle (x from/to, z from/to),
# for sloped glacis plates, angled turret cheeks and boat-shaped hulls.
func wedge(material: Material, bottom: Rect2, low: float, top: Rect2, high: float, shade := 1.0) -> void:
	var surface := tool_for(material)
	var b := [Vector3(bottom.position.x, low, bottom.position.y), Vector3(bottom.end.x, low, bottom.position.y), Vector3(bottom.end.x, low, bottom.end.y), Vector3(bottom.position.x, low, bottom.end.y)]
	var t := [Vector3(top.position.x, high, top.position.y), Vector3(top.end.x, high, top.position.y), Vector3(top.end.x, high, top.end.y), Vector3(top.position.x, high, top.end.y)]
	var middle := Vector3.ZERO
	for point in b + t:
		middle += point / 8.0
	var faces := [[b[0], t[0], t[1], b[1]], [b[1], t[1], t[2], b[2]], [b[2], t[2], t[3], b[3]], [b[3], t[3], t[0], b[0]], [t[0], t[3], t[2], t[1]], [b[0], b[1], b[2], b[3]]]
	for face: Array in faces:
		var normal: Vector3 = (face[1] - face[0]).cross(face[3] - face[0])
		if normal.length() < 0.0001:
			normal = (face[2] - face[1]).cross(face[0] - face[1])
		normal = normal.normalized()
		var centre: Vector3 = (face[0] + face[1] + face[2] + face[3]) / 4.0
		if normal.dot(centre - middle) < 0.0:
			normal = -normal
		quad(surface, face, normal, shade)


# A cylinder or cone along basis.y, centred on center.
func cylinder(material: Material, center: Vector3, basis: Basis, bottom_radius: float, top_radius: float, height: float, segments := 14, shade := 1.0, caps := true) -> void:
	var surface := tool_for(material)
	var color := Color(shade, shade, shade)
	var axis := (basis * Vector3.UP).normalized()
	for index in range(segments):
		var a := TAU * index / segments
		var b := TAU * (index + 1) / segments
		var p := [
			center + basis * Vector3(cos(a) * bottom_radius, -height / 2.0, sin(a) * bottom_radius),
			center + basis * Vector3(cos(a) * top_radius, height / 2.0, sin(a) * top_radius),
			center + basis * Vector3(cos(b) * top_radius, height / 2.0, sin(b) * top_radius),
			center + basis * Vector3(cos(b) * bottom_radius, -height / 2.0, sin(b) * bottom_radius),
		]
		var na := (basis * Vector3(cos(a), 0, sin(a))).normalized()
		var nb := (basis * Vector3(cos(b), 0, sin(b))).normalized()
		var outward := (na + nb).normalized()
		var u0 := float(index) / segments * 2.0
		var u1 := float(index + 1) / segments * 2.0
		tri(surface, [p[0], p[1], p[2]], [na, na, nb], outward, color, [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1)])
		tri(surface, [p[0], p[2], p[3]], [na, nb, nb], outward, color, [Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0)])
		if caps:
			for level in [-1.0, 1.0]:
				var radius := top_radius if level > 0.0 else bottom_radius
				if radius <= 0.0:
					continue
				var hub: Vector3 = center + axis * level * height / 2.0
				var edge_a: Vector3 = center + basis * Vector3(cos(a) * radius, level * height / 2.0, sin(a) * radius)
				var edge_b: Vector3 = center + basis * Vector3(cos(b) * radius, level * height / 2.0, sin(b) * radius)
				var normal: Vector3 = axis * level
				tri(surface, [hub, edge_a, edge_b], [normal, normal, normal], normal, color)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material: Material in tools:
		var surface: SurfaceTool = tools[material]
		surface.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	tools.clear()
	return mesh


func instance(parent: Node3D, view_range: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = commit()
	node.visibility_range_end = view_range
	parent.add_child(node)
	return node
