extends RefCounted

const BreakableGlass = preload("res://scripts/city/breakable_glass.gd")

var transforms: Array[Transform3D] = []
var sizes: Array[Vector2] = []
var display: MultiMeshInstance3D


func add(at: Vector3, size: Vector2, yaw: float) -> void:
	transforms.append(Transform3D(Basis(Vector3.UP, yaw), at))
	sizes.append(size)


func commit(parent: Node3D, material: Material, view_range: float) -> Array[StaticBody3D]:
	var panes: Array[StaticBody3D] = []
	if transforms.is_empty():
		return panes
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	display = MultiMeshInstance3D.new()
	display.multimesh = instances
	display.material_override = material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.visibility_range_end = view_range
	parent.add_child(display)
	for index in range(transforms.size()):
		var size := sizes[index]
		var transform := transforms[index]
		instances.set_instance_transform(index, Transform3D(transform.basis.scaled_local(Vector3(size.x, size.y, 0.025)), transform.origin))
		var pane := BreakableGlass.new()
		pane.setup(size, instances, index)
		parent.add_child(pane)
		pane.transform = transform
		panes.append(pane)
	return panes
