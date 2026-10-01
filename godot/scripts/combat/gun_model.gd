extends RefCounted
# Gun meshes. A real model at res://assets/weapons/<kind>.glb is used when present
# (barrel along -Z, grip at the origin, a child node named "Muzzle" at the barrel tip);
# otherwise a simple stand-in is built so the systems can be played before the art lands.

const SIZES := {
	"pistol": {"body": Vector3(0.035, 0.05, 0.2), "barrel": 0.04, "grip": 0.11, "stock": 0.0},
	"shotgun": {"body": Vector3(0.05, 0.08, 0.42), "barrel": 0.38, "grip": 0.12, "stock": 0.3},
	"rifle": {"body": Vector3(0.05, 0.09, 0.4), "barrel": 0.3, "grip": 0.12, "stock": 0.28},
	"knife": {"body": Vector3(0.02, 0.03, 0.12), "barrel": 0.0, "grip": 0.0, "stock": 0.0},
}


static func build(kind: String) -> Node3D:
	var path := "res://assets/weapons/%s.glb" % kind
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		if not model.has_node("Muzzle"):
			var tip := Marker3D.new()
			tip.name = "Muzzle"
			tip.position = Vector3(0, 0.05, -0.5)
			model.add_child(tip)
		return model
	var root := Node3D.new()
	root.name = kind
	var size: Dictionary = SIZES.get(kind, SIZES.pistol)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("2b2d2c")
	metal.metallic = 0.7
	metal.roughness = 0.45
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("4a3527") if kind == "shotgun" else Color("23251f")
	wood.roughness = 0.8
	var body: Vector3 = size.body
	add_box(root, Vector3(0, body.y * 0.5, -body.z * 0.35), body, metal)
	if kind == "knife":
		add_box(root, Vector3(0, 0, -0.16), Vector3(0.006, 0.025, 0.2), metal)
	if size.barrel > 0.0:
		var barrel := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.012 if kind == "pistol" else 0.016
		tube.bottom_radius = tube.top_radius
		tube.height = size.barrel
		barrel.mesh = tube
		barrel.material_override = metal
		barrel.rotation.x = PI / 2.0
		barrel.position = Vector3(0, body.y * 0.65, -body.z * 0.85 - size.barrel * 0.5 + 0.02)
		root.add_child(barrel)
	if size.grip > 0.0:
		var grip := add_box(root, Vector3(0, -size.grip * 0.4, 0.02), Vector3(0.03, size.grip, 0.045), wood)
		grip.rotation.x = 0.25
	if size.stock > 0.0:
		add_box(root, Vector3(0, 0.0, size.stock * 0.5 + 0.03), Vector3(0.04, 0.09, size.stock), wood)
	if kind == "rifle":
		add_box(root, Vector3(0, -0.07, -0.12), Vector3(0.03, 0.14, 0.05), metal)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, body.y * 0.65, -body.z * 0.85 - size.barrel + 0.02)
	root.add_child(muzzle)
	return root


static func add_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
