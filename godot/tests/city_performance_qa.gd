extends RefCounted
# City frame-rate check for the target PC (MX450, 1280x720, 30 FPS goal). Runs the
# real renderer: stands at a few city viewpoints with soldiers about, measures
# both quality presets with vsync off, and writes qa-output/city_performance.txt.
#   Godot --path godot -- --city-performance   (add --quick for a short smoke run)

const TARGET_FPS := 30.0
const WARM_FRAMES := 90
const MEASURE_FRAMES := 240
# Name, where the survivor stands, yaw (0 looks along -z), pitch.
const VIEWS := [
	["Ilk sokak", Vector3(0, 0.2, 15), 0.0, -0.05],
	["Kavsak", Vector3(44, 0.2, 33), 0.8, -0.02],
	["Ana yol", Vector3(0, 0.2, 40), PI, 0.0],
	["Blok ici", Vector3(-30, 0.2, -50), -0.6, -0.05],
	["Kenar", Vector3(85, 0.2, -70), 2.4, 0.02],
]

var lines: Array[String] = []
var warm := WARM_FRAMES
var measured := MEASURE_FRAMES


func run(game: Node3D) -> void:
	game.set_meta("qa_runner", self)
	if "--quick" in OS.get_cmdline_user_args():
		warm = 3
		measured = 5
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(game, 30)
	game.start_game()
	game.director.start()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.hp = 1.0e9
	lines.append("Kul Sehir sehir performansi  ·  %s  ·  %s" % [RenderingServer.get_video_adapter_name(), Time.get_datetime_string_from_system()])
	lines.append("Cozunurluk %s, hedef %d FPS, vsync kapali" % [str(game.get_viewport().get_visible_rect().size), TARGET_FPS])
	var worst := INF
	for low in [false, true]:
		if game.low_quality != low:
			game.toggle_quality()
		lines.append("")
		lines.append("Ayar: " + ("PERFORMANS" if low else "DENGELI"))
		for view: Array in VIEWS:
			var result := await measure(game, view)
			lines.append("  %-10s  ort %6.1f FPS   en kotu %6.1f FPS   %5d cizim" % [view[0], result.average, result.low, result.draws])
			if not low:
				worst = minf(worst, result.average)
	lines.append("")
	lines.append("SONUC: " + ("GECTI" if worst >= TARGET_FPS else "HEDEFIN ALTINDA") + " (dengeli ayarda en dusuk ortalama %.1f FPS)" % worst)
	var report := "\n".join(lines)
	print(report)
	var file := FileAccess.open("res://qa-output/city_performance.txt", FileAccess.WRITE)
	if file:
		file.store_string(report + "\n")
	game.get_tree().quit(0 if worst >= TARGET_FPS else 1)


func measure(game: Node3D, view: Array) -> Dictionary:
	var player = game.player
	player.position = view[1]
	player.velocity = Vector3.ZERO
	player.yaw = view[2]
	player.pitch = view[3]
	player.hp = 1.0e9
	await frames(game, warm)
	var times: Array[float] = []
	var draws := 0
	var last := Time.get_ticks_usec()
	for index in range(measured):
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000000.0)
		last = now
		draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var total := 0.0
	for time in times:
		total += time
	times.sort()
	# 1% low: the frame time only the slowest 1% of frames exceed.
	var slow := times[int(times.size() * 0.99)]
	return {"average": times.size() / total, "low": 1.0 / slow, "draws": draws}


func frames(game: Node, count: int) -> void:
	for index in range(count):
		await game.get_tree().process_frame
