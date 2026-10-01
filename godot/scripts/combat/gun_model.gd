extends RefCounted
# Gun meshes. A real model at res://assets/weapons/<kind>.glb is used when present
# (barrel along -Z, grip at the origin, a child node named "Muzzle" at the barrel tip);
# otherwise a stand-in is built from simple parts so the systems can be played before the art lands.

# Stand-in parts: [shape, position, size, x tilt, material]. Shapes: "box", "tube"
# (cylinder along -Z, size.x = radius, size.z = length) and "tip" (wedge pointing -Z).
const PARTS := {
	"pistol": [
		["box", Vector3(0, 0.046, -0.06), Vector3(0.03, 0.032, 0.19), 0.0, "metal"],
		["box", Vector3(0, 0.02, -0.055), Vector3(0.027, 0.022, 0.16), 0.0, "frame"],
		["box", Vector3(0, -0.035, 0.015), Vector3(0.028, 0.11, 0.045), 0.3, "frame"],
		["box", Vector3(0, -0.001, -0.05), Vector3(0.006, 0.006, 0.05), 0.0, "frame"],
		["box", Vector3(0, 0.01, -0.073), Vector3(0.006, 0.024, 0.006), 0.0, "frame"],
		["tube", Vector3(0, 0.046, -0.155), Vector3(0.007, 0, 0.012), 0.0, "dark"],
		["box", Vector3(0, 0.066, -0.145), Vector3(0.004, 0.007, 0.006), 0.0, "dark"],
		["box", Vector3(0, 0.066, 0.025), Vector3(0.02, 0.007, 0.006), 0.0, "dark"],
	],
	"shotgun": [
		["box", Vector3(0, 0.03, -0.05), Vector3(0.045, 0.07, 0.2), 0.0, "metal"],
		["tube", Vector3(0, 0.052, -0.4), Vector3(0.011, 0, 0.5), 0.0, "metal"],
		["tube", Vector3(0, 0.022, -0.33), Vector3(0.012, 0, 0.42), 0.0, "dark"],
		["box", Vector3(0, 0.022, -0.32), Vector3(0.046, 0.046, 0.16), 0.0, "wood"],
		["box", Vector3(0, -0.012, 0.09), Vector3(0.034, 0.06, 0.13), 0.22, "wood"],
		["box", Vector3(0, -0.03, 0.27), Vector3(0.04, 0.1, 0.26), 0.08, "wood"],
		["box", Vector3(0, -0.04, 0.405), Vector3(0.042, 0.11, 0.015), 0.08, "dark"],
		["box", Vector3(0, -0.008, -0.03), Vector3(0.006, 0.006, 0.05), 0.0, "dark"],
		["box", Vector3(0, 0.063, -0.64), Vector3(0.005, 0.008, 0.006), 0.0, "dark"],
	],
	"rifle": [
		["box", Vector3(0, 0.03, -0.06), Vector3(0.042, 0.065, 0.3), 0.0, "metal"],
		["box", Vector3(0, 0.066, -0.03), Vector3(0.038, 0.012, 0.22), 0.0, "dark"],
		["tube", Vector3(0, 0.045, -0.38), Vector3(0.009, 0, 0.32), 0.0, "metal"],
		["tube", Vector3(0, 0.072, -0.29), Vector3(0.008, 0, 0.2), 0.0, "metal"],
		["box", Vector3(0, 0.036, -0.28), Vector3(0.046, 0.05, 0.18), 0.0, "wood"],
		["box", Vector3(0, -0.035, -0.11), Vector3(0.026, 0.09, 0.06), -0.25, "dark"],
		["box", Vector3(0, -0.11, -0.085), Vector3(0.026, 0.08, 0.058), -0.55, "dark"],
		["box", Vector3(0, -0.045, 0.04), Vector3(0.028, 0.1, 0.04), 0.3, "wood"],
		["box", Vector3(0, 0.0, 0.22), Vector3(0.04, 0.08, 0.24), 0.12, "wood"],
		["box", Vector3(0, 0.075, -0.5), Vector3(0.006, 0.03, 0.008), 0.0, "dark"],
		["tube", Vector3(0, 0.045, -0.545), Vector3(0.012, 0, 0.03), 0.0, "dark"],
	],
	"knife": [
		["box", Vector3(0, 0, 0.03), Vector3(0.022, 0.026, 0.11), 0.0, "frame"],
		["box", Vector3(0, 0, -0.028), Vector3(0.012, 0.05, 0.01), 0.0, "metal"],
		["box", Vector3(0, 0.004, -0.1), Vector3(0.004, 0.03, 0.14), 0.0, "blade"],
		["tip", Vector3(0, 0.004, -0.19), Vector3(0.004, 0.03, 0.04), 0.0, "blade"],
	],
}
const MUZZLES := {"pistol": Vector3(0, 0.046, -0.162), "shotgun": Vector3(0, 0.052, -0.65), "rifle": Vector3(0, 0.045, -0.56), "knife": Vector3(0, 0, -0.21)}


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
	var materials := {
		"metal": material(Color("2b2d2c"), 0.45, 0.7),
		"dark": material(Color("161716"), 0.6, 0.4),
		"frame": material(Color("1f201f"), 0.75, 0.1),
		"wood": material(Color("4a3527") if kind == "shotgun" else Color("5a3a22"), 0.8, 0.0),
		"blade": material(Color("9a9c98"), 0.3, 0.9),
	}
	for part: Array in PARTS.get(kind, PARTS.pistol):
		var size: Vector3 = part[2]
		var mesh: Mesh
		match part[0]:
			"tube":
				var tube := CylinderMesh.new()
				tube.top_radius = size.x
				tube.bottom_radius = size.x
				tube.height = size.z
				tube.radial_segments = 10
				tube.rings = 1
				mesh = tube
			"tip":
				var wedge := PrismMesh.new()
				wedge.size = Vector3(size.y, size.z, size.x)
				mesh = wedge
			_:
				var box := BoxMesh.new()
				box.size = size
				mesh = box
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = materials[part[4]]
		if part[0] == "tip":
			# Prism apex (+Y) to -Z, its triangle facing sideways.
			instance.basis = Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
		else:
			instance.rotation.x = part[3] + (-PI / 2.0 if part[0] == "tube" else 0.0)
		instance.position = part[1]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = MUZZLES.get(kind, MUZZLES.pistol)
	root.add_child(muzzle)
	return root


static func material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result
