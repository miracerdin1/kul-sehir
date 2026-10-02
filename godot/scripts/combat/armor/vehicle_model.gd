extends RefCounted
# Builds the tank (a T-72-like main battle tank) and the ZPT (a BTR-80-like 8x8
# carrier) from primitives. Front is -Z. Returns the parts the vehicle animates:
# the turret (yaw), the gun (pitch), the wheels (spin) and per-side track
# materials (their texture scrolls as the tracks move).

const MeshKit = preload("res://scripts/combat/armor/mesh_kit.gd")
const TRACK_LINK := 0.16
const VIEW := 140.0
const DETAIL_VIEW := 70.0

static var materials := {}


static func material(key: String) -> StandardMaterial3D:
	if materials.is_empty():
		create_materials()
	return materials[key]


static func create_materials() -> void:
	# Olive paint with dust and darker grime patches, mapped from world space so it
	# stays even across every part.
	var grime := NoiseTexture2D.new()
	grime.seamless = true
	grime.width = 256
	grime.height = 256
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	grime.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color("3e4430"))
	ramp.set_color(1, Color("6f7350"))
	ramp.add_point(0.55, Color("565d3e"))
	grime.color_ramp = ramp
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = grime
	paint.uv1_triplanar = true
	paint.uv1_scale = Vector3(0.35, 0.35, 0.35)
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.82
	paint.metallic = 0.12
	materials.paint = paint
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("2f312c")
	steel.metallic = 0.55
	steel.roughness = 0.55
	steel.vertex_color_use_as_albedo = true
	materials.steel = steel
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("1e1f1c")
	rubber.roughness = 0.95
	rubber.vertex_color_use_as_albedo = true
	materials.rubber = rubber
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("0e0f0d")
	dark.roughness = 0.9
	materials.dark = dark
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color("5b4630")
	rust.roughness = 0.9
	rust.vertex_color_use_as_albedo = true
	materials.rust = rust
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color("22313a")
	lens.metallic = 0.6
	lens.roughness = 0.15
	materials.lens = lens


# Steel track links: a bar, the cleat and two pins per link.
static func track_material() -> StandardMaterial3D:
	var image := Image.create(32, 16, false, Image.FORMAT_RGB8)
	image.fill(Color("26271f"))
	for x in range(32):
		for y in range(16):
			if x < 9:
				image.set_pixel(x, y, Color("3f3f37") if y > 1 and y < 14 else Color("2d2d27"))
			elif x > 27:
				image.set_pixel(x, y, Color("141512"))
			if (y == 3 or y == 12) and x >= 12 and x <= 16:
				image.set_pixel(x, y, Color("55544a"))
	var texture := ImageTexture.create_from_image(image)
	var track := StandardMaterial3D.new()
	track.albedo_texture = texture
	track.roughness = 0.75
	track.metallic = 0.4
	track.cull_mode = BaseMaterial3D.CULL_DISABLED
	return track


static func span(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))


static func build(kind: String, root: Node3D) -> Dictionary:
	if materials.is_empty():
		create_materials()
	return build_tank(root) if kind == "tank" else build_carrier(root)


# --- Tank -------------------------------------------------------------------

static func build_tank(root: Node3D) -> Dictionary:
	var parts := {"meshes": [], "wheels": [], "tracks": [], "track_meshes": []}
	var kit := MeshKit.new()
	var paint := material("paint")
	var steel := material("steel")
	var rubber := material("rubber")
	var dark := material("dark")
	# Hull: lower plate sloping forward, the long upper glacis, the flat deck.
	kit.wedge(paint, span(-1.12, 1.12, -2.85, 3.1), 0.42, span(-1.2, 1.2, -3.4, 3.15), 1.0, 0.92)
	kit.wedge(paint, span(-1.2, 1.2, -3.4, -1.85), 1.0, span(-1.18, 1.18, -1.95, -1.85), 1.56, 1.02)
	kit.box(paint, Vector3(0, 1.28, 0.65), Vector3(2.4, 0.56, 5.0), Basis.IDENTITY, 0.96)
	# Rear plate and engine deck grilles.
	kit.box(paint, Vector3(0, 1.0, 3.17), Vector3(2.3, 0.9, 0.08), Basis.IDENTITY, 0.85)
	kit.box(dark, Vector3(0, 1.565, 2.25), Vector3(1.9, 0.02, 1.5))
	for slat in range(7):
		kit.box(steel, Vector3(0, 1.585, 1.62 + slat * 0.21), Vector3(1.9, 0.04, 0.05))
	# Driver's hatch and periscopes on the glacis top.
	kit.cylinder(paint, Vector3(0, 1.585, -1.6), Basis.IDENTITY, 0.3, 0.28, 0.05, 14, 0.9)
	kit.box(material("lens"), Vector3(0, 1.62, -1.92), Vector3(0.3, 0.07, 0.06))
	# Headlights, tow hooks and the dozer-blade ridge low on the nose.
	for side in [-1.0, 1.0]:
		kit.cylinder(steel, Vector3(side * 0.95, 1.08, -3.25), Basis(Vector3.RIGHT, PI / 2.0), 0.09, 0.09, 0.12, 10)
		kit.box(steel, Vector3(side * 0.75, 0.52, -3.0), Vector3(0.12, 0.16, 0.3))
	kit.box(paint, Vector3(0, 0.72, -3.27), Vector3(2.3, 0.14, 0.12), Basis(Vector3.RIGHT, 0.6), 0.85)
	# Fenders over the tracks, side skirts, stowage bins and two fuel drums.
	for side in [-1.0, 1.0]:
		kit.box(paint, Vector3(side * 1.5, 1.08, -0.05), Vector3(0.66, 0.05, 6.75), Basis.IDENTITY, 0.94)
		kit.box(paint, Vector3(side * 1.5, 1.0, -3.47), Vector3(0.66, 0.05, 0.45), Basis(Vector3.RIGHT, -0.55), 0.94)
		for panel in range(6):
			kit.box(rubber, Vector3(side * 1.82, 0.85, -2.55 + panel * 0.98), Vector3(0.04, 0.42, 0.94), Basis.IDENTITY, 0.9 + (panel % 2) * 0.1)
		kit.box(paint, Vector3(side * 1.5, 1.3, -0.3), Vector3(0.52, 0.38, 1.1), Basis.IDENTITY, 0.88)
		kit.box(paint, Vector3(side * 1.5, 1.27, 1.25), Vector3(0.52, 0.32, 0.8), Basis.IDENTITY, 0.83)
		kit.cylinder(material("rust"), Vector3(side * 0.6, 1.4, 3.42), Basis(Vector3.BACK, PI / 2.0), 0.28, 0.28, 0.95, 14)
	parts.meshes.append(kit.instance(root, VIEW))
	# Running gear: six road wheels, front idler, rear sprocket, return rollers.
	var wheel_mesh := tank_wheel(0.36)
	for side in [-1.0, 1.0]:
		for index in range(6):
			add_wheel(parts, root, wheel_mesh, Vector3(side * 1.5, 0.42, -2.35 + index * 0.94), side, 0.36)
		add_wheel(parts, root, tank_wheel(0.3), Vector3(side * 1.5, 0.66, -3.0), side, 0.3)
		add_wheel(parts, root, sprocket(), Vector3(side * 1.5, 0.68, 3.05), side, 0.32)
		var rollers := MeshKit.new()
		for z in [-1.6, 0.0, 1.6]:
			rollers.cylinder(rubber, Vector3(side * 1.5, 0.98, z), Basis(Vector3.BACK, PI / 2.0), 0.09, 0.09, 0.3, 10)
		parts.meshes.append(rollers.instance(root, DETAIL_VIEW))
		var track := track_material()
		parts.tracks.append(track)
		var belt := MeshInstance3D.new()
		belt.mesh = track_belt(side * 1.5, track)
		belt.visibility_range_end = VIEW
		root.add_child(belt)
		parts.meshes.append(belt)
	# Turret: low cast dome, rear bustle, cupola, hatches, roof gun, smoke dischargers.
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.56, -0.25)
	root.add_child(turret)
	parts.turret = turret
	kit.cylinder(paint, Vector3(0, 0.3, 0.05), Basis.from_scale(Vector3(1.0, 1.0, 1.12)), 1.28, 0.92, 0.6, 22, 1.0)
	kit.cylinder(paint, Vector3(0, 0.66, 0.05), Basis.from_scale(Vector3(1.0, 1.0, 1.12)), 0.92, 0.55, 0.12, 22, 0.96)
	kit.box(paint, Vector3(0, 0.33, 1.25), Vector3(1.5, 0.42, 0.75), Basis.IDENTITY, 0.9)
	kit.box(paint, Vector3(0, 0.3, -1.12), Vector3(0.72, 0.46, 0.4), Basis.IDENTITY, 0.93)
	kit.cylinder(paint, Vector3(0.45, 0.78, 0.25), Basis.IDENTITY, 0.33, 0.31, 0.18, 16, 0.9)
	kit.cylinder(paint, Vector3(0.45, 0.9, 0.25), Basis.IDENTITY, 0.29, 0.27, 0.06, 16, 0.85)
	kit.cylinder(paint, Vector3(-0.45, 0.74, 0.3), Basis.IDENTITY, 0.28, 0.27, 0.06, 16, 0.85)
	kit.box(material("lens"), Vector3(-0.42, 0.82, -0.32), Vector3(0.22, 0.16, 0.2))
	kit.box(paint, Vector3(-0.42, 0.78, -0.22), Vector3(0.3, 0.14, 0.36), Basis.IDENTITY, 0.85)
	# Heavy machine gun on the cupola ring.
	kit.box(steel, Vector3(0.45, 1.05, 0.05), Vector3(0.14, 0.16, 0.5))
	kit.cylinder(steel, Vector3(0.45, 1.06, -0.55), Basis(Vector3.RIGHT, PI / 2.0), 0.025, 0.025, 0.9, 8)
	kit.box(steel, Vector3(0.6, 1.0, 0.1), Vector3(0.14, 0.18, 0.24))
	for side in [-1.0, 1.0]:
		for tube in range(4):
			var at := Vector3(side * (0.78 + tube * 0.09), 0.42 + tube * 0.025, -0.85 + tube * 0.12)
			kit.cylinder(steel, at, Basis(Vector3.RIGHT, PI / 2.0 - 0.5), 0.045, 0.045, 0.28, 8)
	# Snorkel tube and spare boxes on the bustle, the radio antenna.
	kit.cylinder(paint, Vector3(0, 0.62, 1.45), Basis(Vector3.BACK, PI / 2.0), 0.1, 0.1, 1.4, 10, 0.8)
	kit.cylinder(steel, Vector3(-0.55, 1.75, 1.2), Basis(Vector3.RIGHT, -0.08), 0.008, 0.006, 2.3, 4)
	parts.meshes.append(kit.instance(turret, VIEW))
	# Main gun: thick breech end, thermal sleeve in bands, fume extractor, muzzle.
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, 0.3, -1.3)
	turret.add_child(gun)
	parts.gun = gun
	var along := Basis(Vector3.RIGHT, PI / 2.0)
	kit.cylinder(paint, Vector3(0, 0, -0.45), along, 0.16, 0.14, 0.9, 14, 0.9)
	# Sleeve bands run on from the breech end without a gap.
	for band in range(4):
		kit.cylinder(paint, Vector3(0, 0, -1.12 - band * 0.48), along, 0.125, 0.125, 0.5, 14, 0.95 - band * 0.03)
		kit.cylinder(steel, Vector3(0, 0, -1.37 - band * 0.48), along, 0.135, 0.135, 0.04, 14)
	kit.cylinder(paint, Vector3(0, 0, -2.95), along, 0.165, 0.165, 0.55, 16, 0.9)
	kit.cylinder(paint, Vector3(0, 0, -3.84), along, 0.11, 0.1, 1.3, 14, 0.93)
	kit.cylinder(steel, Vector3(0, 0, -4.5), along, 0.12, 0.12, 0.07, 14)
	parts.meshes.append(kit.instance(gun, VIEW))
	parts.muzzle = Vector3(0, 0, -4.55)
	return parts


static func add_wheel(parts: Dictionary, root: Node3D, mesh: Mesh, at: Vector3, side: float, radius: float) -> void:
	var wheel := MeshInstance3D.new()
	wheel.mesh = mesh
	wheel.position = at
	# Wheel meshes are built around their own x axis; the far side faces outward too.
	wheel.scale.x = side
	wheel.visibility_range_end = DETAIL_VIEW
	root.add_child(wheel)
	parts.wheels.append({"node": wheel, "side": side, "radius": radius})
	parts.meshes.append(wheel)


static func tank_wheel(radius: float) -> ArrayMesh:
	var kit := MeshKit.new()
	var axle := Basis(Vector3.BACK, PI / 2.0)
	kit.cylinder(material("rubber"), Vector3.ZERO, axle, radius, radius, 0.22, 18)
	kit.cylinder(material("paint"), Vector3(0.12, 0, 0), axle, radius * 0.8, radius * 0.72, 0.04, 18, 0.9)
	kit.cylinder(material("steel"), Vector3(0.16, 0, 0), axle, radius * 0.25, radius * 0.18, 0.06, 10)
	# Bolts round the hub show the wheel turning.
	for bolt in range(6):
		var angle := TAU * bolt / 6.0
		kit.box(material("steel"), Vector3(0.15, cos(angle) * radius * 0.45, sin(angle) * radius * 0.45), Vector3(0.04, 0.05, 0.05))
	return kit.commit()


static func sprocket() -> ArrayMesh:
	var kit := MeshKit.new()
	var axle := Basis(Vector3.BACK, PI / 2.0)
	kit.cylinder(material("steel"), Vector3.ZERO, axle, 0.27, 0.27, 0.24, 16)
	kit.cylinder(material("paint"), Vector3(0.13, 0, 0), axle, 0.2, 0.14, 0.05, 14, 0.85)
	for tooth in range(12):
		var angle := TAU * tooth / 12.0
		kit.box(material("steel"), Vector3(0, cos(angle) * 0.3, sin(angle) * 0.3), Vector3(0.22, 0.08, 0.08), Basis(Vector3.RIGHT, angle))
	return kit.commit()


# The track as a closed belt in the side profile: along the ground under the road
# wheels, up round the idler, back along the return rollers, down round the sprocket.
static func track_belt(x: float, track: Material) -> ArrayMesh:
	var path: Array[Vector2] = [Vector2(2.45, 0.03), Vector2(-2.45, 0.03)]
	for degrees in range(235, 85, -15):
		var angle := deg_to_rad(degrees)
		path.append(Vector2(-3.0, 0.66) + Vector2(cos(angle), sin(angle)) * 0.34)
	path.append(Vector2(-1.6, 1.1))
	path.append(Vector2(1.6, 1.1))
	for degrees in range(90, -60, -15):
		var angle := deg_to_rad(degrees)
		path.append(Vector2(3.05, 0.68) + Vector2(cos(angle), sin(angle)) * 0.36)
	path.append(path[0])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travelled := 0.0
	var half := 0.29
	var thick := 0.035
	for index in range(path.size() - 1):
		var a: Vector2 = path[index]
		var b: Vector2 = path[index + 1]
		var step := a.distance_to(b)
		var tangent := (b - a) / step
		# The loop runs clockwise seen from +x, so the outside is to the tangent's left.
		var out := Vector2(-tangent.y, tangent.x)
		var u0 := travelled / TRACK_LINK
		var u1 := (travelled + step) / TRACK_LINK
		travelled += step
		for layer in [1.0, -1.0]:
			var pa: Vector2 = a + out * thick * layer
			var pb: Vector2 = b + out * thick * layer
			var normal: Vector3 = Vector3(0, out.y, out.x) * layer
			var corners := [Vector3(x - half, pa.y, pa.x), Vector3(x + half, pa.y, pa.x), Vector3(x + half, pb.y, pb.x), Vector3(x - half, pb.y, pb.x)]
			var uvs := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(normal)
				surface.set_uv(uvs[corner])
				surface.add_vertex(corners[corner])
	surface.set_material(track)
	return surface.commit()


# --- Carrier ------------------------------------------------------------------

static func build_carrier(root: Node3D) -> Dictionary:
	var parts := {"meshes": [], "wheels": [], "tracks": [], "track_meshes": []}
	var kit := MeshKit.new()
	var paint := material("paint")
	var steel := material("steel")
	var rubber := material("rubber")
	var dark := material("dark")
	# Boat-shaped lower hull flaring out to the sponsons, sloped upper hull.
	kit.wedge(paint, span(-0.95, 0.95, -3.1, 3.35), 0.5, span(-1.42, 1.42, -3.85, 3.8), 1.3, 0.9)
	kit.wedge(paint, span(-1.42, 1.42, -3.85, 3.8), 1.3, span(-1.02, 1.02, -2.3, 3.55), 2.02, 1.0)
	# Trim vane folded on the nose, windscreen armour, side doors, vision blocks.
	kit.box(paint, Vector3(0, 1.32, -3.95), Vector3(2.1, 0.5, 0.05), Basis(Vector3.RIGHT, 0.35), 0.85)
	for side in [-1.0, 1.0]:
		kit.box(material("lens"), Vector3(side * 0.42, 1.75, -2.72), Vector3(0.6, 0.22, 0.04), Basis(Vector3.RIGHT, -0.85))
		kit.box(paint, Vector3(side * 1.3, 1.62, -0.15), Vector3(0.05, 0.55, 0.75), Basis(Vector3.BACK, side * 0.48), 0.8)
		for block in range(3):
			kit.box(material("lens"), Vector3(side * 1.18, 1.82, 0.9 + block * 0.6), Vector3(0.04, 0.12, 0.2), Basis(Vector3.BACK, side * 0.48))
		kit.cylinder(steel, Vector3(side * 0.9, 1.25, -3.75), Basis(Vector3.RIGHT, PI / 2.0), 0.08, 0.08, 0.1, 10)
		# Wheel arches over each axle.
		for z in [-2.55, -1.25, 1.15, 2.45]:
			kit.box(dark, Vector3(side * 1.25, 0.75, z), Vector3(0.36, 0.5, 1.25))
	# Hatches and the engine deck.
	kit.cylinder(paint, Vector3(-0.4, 2.05, -1.9), Basis.IDENTITY, 0.28, 0.27, 0.05, 14, 0.85)
	kit.cylinder(paint, Vector3(0.4, 2.05, -1.9), Basis.IDENTITY, 0.28, 0.27, 0.05, 14, 0.85)
	kit.box(dark, Vector3(0, 2.03, 2.4), Vector3(1.4, 0.02, 1.4))
	for slat in range(6):
		kit.box(steel, Vector3(0, 2.05, 1.85 + slat * 0.22), Vector3(1.4, 0.035, 0.05))
	parts.meshes.append(kit.instance(root, VIEW))
	var tire := carrier_wheel()
	for side in [-1.0, 1.0]:
		for z in [-2.55, -1.25, 1.15, 2.45]:
			add_wheel(parts, root, tire, Vector3(side * 1.25, 0.56, z), side, 0.56)
	# Small conical turret with the heavy machine gun.
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 2.02, -1.0)
	root.add_child(turret)
	parts.turret = turret
	kit.cylinder(paint, Vector3(0, 0.2, 0), Basis.IDENTITY, 0.58, 0.42, 0.4, 16, 1.0)
	kit.cylinder(paint, Vector3(0, 0.43, 0.05), Basis.IDENTITY, 0.42, 0.2, 0.08, 16, 0.9)
	kit.box(material("lens"), Vector3(0.2, 0.36, -0.36), Vector3(0.12, 0.1, 0.06))
	parts.meshes.append(kit.instance(turret, VIEW))
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, 0.22, -0.5)
	turret.add_child(gun)
	parts.gun = gun
	var along := Basis(Vector3.RIGHT, PI / 2.0)
	kit.cylinder(paint, Vector3(0, 0, -0.15), along, 0.11, 0.09, 0.3, 12, 0.9)
	kit.cylinder(steel, Vector3(0, 0, -0.95), along, 0.045, 0.04, 1.4, 10)
	kit.cylinder(steel, Vector3(0.14, 0, -0.5), along, 0.022, 0.022, 0.6, 8)
	parts.meshes.append(kit.instance(gun, VIEW))
	parts.muzzle = Vector3(0, 0, -1.7)
	return parts


static func carrier_wheel() -> ArrayMesh:
	var kit := MeshKit.new()
	var axle := Basis(Vector3.BACK, PI / 2.0)
	kit.cylinder(material("rubber"), Vector3.ZERO, axle, 0.56, 0.56, 0.38, 20)
	kit.cylinder(material("paint"), Vector3(0.18, 0, 0), axle, 0.3, 0.26, 0.05, 16, 0.85)
	kit.cylinder(material("steel"), Vector3(0.21, 0, 0), axle, 0.09, 0.07, 0.06, 10)
	for lug in range(8):
		var angle := TAU * lug / 8.0
		kit.box(material("rubber"), Vector3(0, cos(angle) * 0.56, sin(angle) * 0.56), Vector3(0.36, 0.05, 0.14), Basis(Vector3.RIGHT, angle), 0.8)
	return kit.commit()
