extends RefCounted
# Static architectural detail joins the block's existing material batches.


static func add(batch, materials: Dictionary, origin: Vector3, middle: Vector2, size: Vector2, floor_height: float, shade: float) -> void:
	var low := middle - size / 2.0
	var high := middle + size / 2.0
	var height := floor_height * 2.0
	# Floor string course and projecting cornice leave entrances clear.
	for level in [Vector2(floor_height, 0.16), Vector2(height, 0.2)]:
		for z in [low.y, high.y]:
			batch.add(materials.trim, Vector3(middle.x, level.x, z) - origin, Vector3(size.x + 0.45, level.y, 0.58), 0.0, shade)
		for x in [low.x, high.x]:
			batch.add(materials.trim, Vector3(x, level.x, middle.y) - origin, Vector3(0.58, level.y, size.y + 0.45), 0.0, shade)
	# Alternating corner stones give the walls thickness and scale.
	for x in [low.x, high.x]:
		for z in [low.y, high.y]:
			for row in range(12):
				var width := 0.5 if row % 2 == 0 else 0.36
				batch.add(materials.trim, Vector3(x, 0.3 + row * 0.51, z) - origin, Vector3(width, 0.28, width), 0.0, shade * 0.86)
	add_roof(batch, materials, origin, middle, size, height, shade)


static func add_roof(batch, materials: Dictionary, origin: Vector3, middle: Vector2, size: Vector2, height: float, shade: float) -> void:
	var half_span := size.x / 2.0 + 0.48
	var rise := minf(2.2, size.x * 0.22)
	var slope := atan2(rise, half_span)
	var slope_length := Vector2(half_span, rise).length()
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, -side * slope)
		var at := Vector3(middle.x + side * half_span / 2.0, height + rise / 2.0 + 0.18, middle.y) - origin
		batch.add_basis(materials.roof, at, Vector3(slope_length, 0.16, size.y + 0.95), basis, shade)
		# Narrow standing seams and eaves, all batched.
		for rib in range(int(size.y / 0.65) + 1):
			var seam := at + Vector3(0, 0.09, -size.y / 2.0 + rib * 0.65)
			batch.add_basis(materials.metal, seam, Vector3(slope_length, 0.035, 0.025), basis, shade)
		batch.add(materials.metal, Vector3(middle.x + side * half_span, height + 0.12, middle.y) - origin, Vector3(0.14, 0.16, size.y + 1.0), 0.0, shade)
	batch.add(materials.roof, Vector3(middle.x, height + rise + 0.23, middle.y) - origin, Vector3(0.24, 0.16, size.y + 1.05), 0.0, shade)
	for side in [-1.0, 1.0]:
		var z: float = middle.y + side * size.y / 2.0
		var a := Vector3(middle.x - size.x / 2.0, height, z) - origin
		var b := Vector3(middle.x, height + rise + 0.12, z) - origin
		var c := Vector3(middle.x + size.x / 2.0, height, z) - origin
		batch.add_triangle(materials.plaster, a, b, c, shade)
		batch.add_triangle(materials.plaster, c, b, a, shade)
	# Brick chimney, cap and dark opening.
	var chimney := Vector3(middle.x + size.x * 0.22, height + rise * 0.75 + 0.55, middle.y + size.y * 0.25) - origin
	batch.add(materials.brick, chimney, Vector3(0.65, 1.55, 0.75), 0.0, shade)
	batch.add(materials.trim, chimney + Vector3(0, 0.8, 0), Vector3(0.85, 0.14, 0.95), 0.0, shade)
	batch.add(materials.dark, chimney + Vector3(0, 0.88, 0), Vector3(0.5, 0.015, 0.6))
	for side in [-1.0, 1.0]:
		batch.add(materials.metal, Vector3(middle.x + side * (size.x / 2.0 + 0.25), height / 2.0, middle.y + size.y / 2.0 - 0.35) - origin, Vector3(0.075, height, 0.075), 0.0, shade)


static func floorboards(batch, material: Material, origin: Vector3, area: Rect2, height: float) -> void:
	var count := maxi(1, ceili(area.size.y / 0.24))
	var width := area.size.y / count
	for index in range(count):
		var at := Vector3(area.get_center().x, height + 0.008, area.position.y + width * (index + 0.5)) - origin
		batch.add(material, at, Vector3(area.size.x, 0.016, maxf(0.01, width - 0.008)), 0.0, 0.83 + (index % 5) * 0.045)


static func interior(batch, materials: Dictionary, origin: Vector3, middle: Vector2, size: Vector2, stairwell: Rect2, floor_height: float) -> void:
	# Low shelves against a clear wall leave the entrance and stair route free.
	for level in range(2):
		var base := level * floor_height if level > 0 else 0.06
		for side in [-1.0, 1.0]:
			var center := middle + Vector2(0, side * (size.y / 2.0 - 0.6))
			var footprint := Rect2(center - Vector2(1.1, 0.35), Vector2(2.2, 0.7))
			if footprint.intersects(stairwell.grow(0.5)):
				continue
			var at := Vector3(center.x, base, center.y) - origin
			for height in [0.18, 0.65, 1.15]:
				batch.add(materials.wood, at + Vector3(0, height, 0), Vector3(2.0, 0.065, 0.42))
			for edge in [-0.97, 0.97]:
				batch.add(materials.wood, at + Vector3(edge, 0.65, 0), Vector3(0.06, 1.2, 0.42))
			for item in range(5):
				batch.add(materials.brick if item % 2 else materials.sand, at + Vector3(-0.7 + item * 0.26, 0.85, 0), Vector3(0.18, 0.32, 0.23), 0.0, 0.7 + item * 0.07)
			break
		# Worn inset rug gives the empty room a readable living area.
		var rug := Rect2(middle - Vector2(1.4, 1.1), Vector2(2.8, 2.2))
		if not rug.intersects(stairwell):
			batch.add(materials.rug, Vector3(middle.x, base + 0.029, middle.y) - origin, Vector3(2.8, 0.012, 2.2))
			for edge in [-1.0, 1.0]:
				batch.add(materials.sand, Vector3(middle.x + edge * 1.23, base + 0.037, middle.y) - origin, Vector3(0.08, 0.005, 2.0))
