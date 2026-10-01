extends RefCounted
# Collects boxes per material and bakes each set into one mesh, so a whole city
# block draws in a handful of calls (the HTML's merged batches). Per-box shade
# goes into vertex colour; the materials are triplanar, so no UVs are needed.

const FACES := [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
	[Vector3.BACK, Vector3.UP, Vector3.LEFT],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]

var sets := {}
var count := 0


# center is relative to the block origin; tilt is a small x/z lean for rubble.
func add(material: Material, center: Vector3, size: Vector3, yaw := 0.0, shade := 1.0, tilt := Vector2.ZERO) -> void:
	if not sets.has(material):
		sets[material] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	var arrays: Array = sets[material]
	var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.y))
	var half := size / 2.0
	var color := Color(shade, shade, shade)
	for face: Array in FACES:
		var normal: Vector3 = face[0]
		var up: Vector3 = face[1]
		var side: Vector3 = face[2]
		var middle := normal * half
		var u := up * half
		var s := side * half
		var corners := [middle - u - s, middle + u - s, middle + u + s, middle - u + s]
		for index in [0, 1, 2, 0, 2, 3]:
			arrays[0].append(center + basis * corners[index])
			arrays[1].append(basis * normal)
			arrays[2].append(color)
	count += 1


func commit(parent: Node3D, view_range: float) -> Array[MeshInstance3D]:
	var instances: Array[MeshInstance3D] = []
	for material: Material in sets:
		var arrays: Array = sets[material]
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = arrays[0]
		surface[Mesh.ARRAY_NORMAL] = arrays[1]
		surface[Mesh.ARRAY_COLOR] = arrays[2]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.visibility_range_end = view_range
		parent.add_child(instance)
		instances.append(instance)
	sets.clear()
	return instances
