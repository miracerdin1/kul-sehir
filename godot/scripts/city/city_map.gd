extends CanvasLayer
# Full-screen city map on M (the HTML's big map): roads, building shells, the
# warm stove and where the survivor stands and looks.

const CityBuilder = preload("res://scripts/city/city_builder.gd")

var city: Node3D
var player: Node3D
var stove: Vector3
var canvas: Control
var font: Font


func setup(city_node: Node3D, survivor: Node3D, stove_position: Vector3) -> void:
	city = city_node
	player = survivor
	stove = stove_position


func _ready() -> void:
	layer = 7
	font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(draw_map)
	add_child(canvas)
	hide()


func toggle(force = null) -> void:
	visible = (not visible) if force == null else force


func _process(_delta: float) -> void:
	if visible:
		canvas.queue_redraw()


func draw_map() -> void:
	var screen := canvas.size
	var extent := Vector2(CityBuilder.BOUND.x + 4.0, CityBuilder.BOUND.y + 4.0)
	var zoom := minf(screen.x * 0.84 / (extent.x * 2.0), screen.y * 0.84 / (extent.y * 2.0))
	var origin := screen / 2.0
	var to_screen := func(x: float, z: float) -> Vector2: return origin + Vector2(x, z) * zoom
	canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.55))
	canvas.draw_rect(Rect2(to_screen.call(-extent.x, -extent.y), extent * 2.0 * zoom), Color("202326"))
	var road := Color("3c3f41")
	for x in CityBuilder.ROADS_X:
		canvas.draw_rect(Rect2(to_screen.call(x - CityBuilder.ROAD_HALF, -CityBuilder.BOUND.y), Vector2(CityBuilder.ROAD_HALF * 2.0, CityBuilder.BOUND.y * 2.0) * zoom), road)
	for z in CityBuilder.ROADS_Z:
		canvas.draw_rect(Rect2(to_screen.call(-CityBuilder.BOUND.x, z - CityBuilder.ROAD_HALF), Vector2(CityBuilder.BOUND.x * 2.0, CityBuilder.ROAD_HALF * 2.0) * zoom), road)
	var wall := Color("8a857a")
	for building: Rect2 in city.buildings:
		canvas.draw_rect(Rect2(to_screen.call(building.position.x, building.position.y), building.size * zoom), Color("4b4943"))
		canvas.draw_rect(Rect2(to_screen.call(building.position.x, building.position.y), building.size * zoom), wall, false, 1.5)
	# The first street's two building rows (street.gd).
	for side in [-1.0, 1.0]:
		var left := 7.0 if side > 0.0 else -14.0
		canvas.draw_rect(Rect2(to_screen.call(left, -27.3), Vector2(7.0, 54.6) * zoom), Color("4b4943"))
		canvas.draw_rect(Rect2(to_screen.call(left, -27.3), Vector2(7.0, 54.6) * zoom), wall, false, 1.5)
	canvas.draw_circle(to_screen.call(stove.x, stove.z), 5.0, Color("ff8a35"))
	var at: Vector2 = to_screen.call(player.global_position.x, player.global_position.z)
	var camera := player.get_viewport().get_camera_3d()
	var look := Vector3.FORWARD if camera == null else -camera.global_basis.z
	var forward := Vector2(look.x, look.z).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.UP
	var side_vector := Vector2(-forward.y, forward.x)
	canvas.draw_colored_polygon(PackedVector2Array([at + forward * 12.0, at - forward * 7.0 + side_vector * 7.0, at - forward * 7.0 - side_vector * 7.0]), Color("e8e2cf"))
	var title_at: Vector2 = to_screen.call(-extent.x, -extent.y) + Vector2(0, -14)
	canvas.draw_string(font, title_at, "KÜL ŞEHİR  ·  HARİTA   [ M ] kapat", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d8d5c8"))
	canvas.draw_string(font, title_at + Vector2(0, extent.y * 2.0 * zoom + 34), "● ateş   ▲ sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b5b0a2"))
