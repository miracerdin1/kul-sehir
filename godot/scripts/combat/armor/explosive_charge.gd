extends StaticBody3D

var service: Node3D
var mine := false
var direction := Vector3.FORWARD
var age := 0.0
var spent := false
var light: OmniLight3D
var excluded: Array[RID] = []


func _ready() -> void:
	excluded = [get_rid()]
	add_to_group("explosive_charge")
	collision_layer = 1 if mine else 0
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.22 if mine else 0.08
	cylinder.height = 0.09 if mine else 0.5
	shape.shape = cylinder
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var model := CylinderMesh.new()
	model.top_radius = cylinder.radius
	model.bottom_radius = cylinder.radius
	model.height = cylinder.height
	model.radial_segments = 12
	mesh.mesh = model
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("676749")
	mesh.material_override = material
	if not mine:
		mesh.rotation.x = PI / 2
	add_child(mesh)
	light = OmniLight3D.new()
	light.light_color = Color("ff8c35")
	light.light_energy = 0.8
	light.omni_range = 2.0
	light.visible = not mine
	add_child(light)


func _physics_process(delta: float) -> void:
	if spent or service.director.paused():
		return
	age += delta
	if mine:
		if age < 2.0:
			return
		light.visible = true
		for target in get_tree().get_nodes_in_group("armored_vehicle") + service.director.enemies:
			if target.get("destroyed") == true or target.get("alive") == false:
				continue
			var point: Vector3 = target.global_position
			if point.distance_to(global_position) < 4.0 and service.visible_from(global_position + Vector3.UP * 0.2, target, target.blast_target() if target.has_method("blast_target") else point + Vector3.UP, excluded):
				detonate()
				return
		return
	if age > 4.0:
		queue_free()
		return
	var next := global_position + direction * 32.0 * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next)
	query.exclude = [service.director.player.get_rid(), get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal * 0.08
		detonate()
		return
	global_position = next


func detonate() -> void:
	if spent:
		return
	spent = true
	collision_layer = 0
	service.explode(global_position, 320.0 if mine else 180.0, 6.0, excluded)
	queue_free()
