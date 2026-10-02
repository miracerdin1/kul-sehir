extends StaticBody3D

const BoxBatch = preload("res://scripts/city/box_batch.gd")
var kind := "tank"
var hp := 280.0
var destroyed := false
var visuals: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("armored_vehicle")
	hp = 280.0 if kind == "tank" else 170.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("525e3f")
	steel.roughness = 0.8
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("252824")
	var batch := BoxBatch.new()
	var tank := kind == "tank"
	batch.add(steel, Vector3(0, 1.1, 0), Vector3(3.1, 1.0, 5.5))
	batch.add(steel, Vector3(0, 1.9, 0.3), Vector3(2.2, 0.7, 3.6 if not tank else 2.2))
	batch.add(steel, Vector3(0, 2.3, 0.2), Vector3(1.0, 0.15, 1.0))
	batch.add(rubber, Vector3(0, 2.0, -2.5 if tank else -1.2), Vector3(0.17, 0.17, 3.5 if tank else 1.8))
	for side in [-1.0, 1.0]:
		if tank:
			batch.add(rubber, Vector3(side * 1.65, 0.55, 0), Vector3(0.55, 0.9, 5.7))
		for wheel in range(4):
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5 if tank else 0.62
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = 0.4
			cylinder.radial_segments = 12
			tire.mesh = cylinder
			tire.material_override = rubber
			tire.rotation.z = PI / 2
			tire.position = Vector3(side * 1.7, 0.6, -1.9 + wheel * 1.25)
			add_child(tire)
			visuals.append(tire)
		batch.add(rubber, Vector3(side * 0.7, 1.9, -1.52), Vector3(0.55, 0.22, 0.04))
		batch.add(steel, Vector3(side * 1.1, 1.4, 2.8), Vector3(0.5, 0.65, 0.35))
	visuals.append_array(batch.commit(self, 135.0))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.8, 2.5, 5.7)
	shape.shape = box
	shape.position.y = 1.25
	add_child(shape)


func blast_target() -> Vector3:
	return global_position + Vector3.UP * 1.1


func take_explosion(damage: float) -> bool:
	if destroyed:
		return false
	hp = maxf(0.0, hp - damage)
	if hp > 0.0:
		return false
	destroyed = true
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color("24221f")
	burnt.roughness = 1.0
	for mesh in visuals:
		mesh.material_override = burnt
	# A wreck remains solid cover, but cannot take damage again.
	return true
