extends RefCounted

var scenes: Dictionary = {}


func model(asset: String, parent: Node3D, at: Vector3, target_height: float = 0.0) -> Node3D:
	var path := "res://assets/models/%s/%s.gltf" % [asset, asset]
	if not scenes.has(path):
		scenes[path] = load(path)
	var container := Node3D.new()
	container.name = asset
	parent.add_child(container)
	var instance: Node3D = scenes[path].instantiate()
	container.add_child(instance)
	var bounds := mesh_bounds(instance)
	var factor := target_height / bounds.size.y if target_height > 0.0 and bounds.size.y > 0.001 else 1.0
	instance.scale *= factor
	instance.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	container.position = at
	return container


static func mesh_bounds(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	collect_bounds(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	var result: AABB = boxes[0]
	for box in boxes:
		result = result.merge(box)
	return result


static func collect_bounds(node: Node, transform: Transform3D, boxes: Array[AABB]) -> void:
	var local := transform
	if node is Node3D:
		local = transform * node.transform
	if node is MeshInstance3D and node.mesh:
		boxes.append(local * node.get_aabb())
	for child in node.get_children():
		collect_bounds(child, local, boxes)


static func collider(parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = at
	return body
