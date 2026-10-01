extends SceneTree

const WeatherState = preload("res://scripts/world/weather_state.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func check_simulation() -> void:
	var state := WeatherState.new()
	state.elapsed_days = 0.999
	state.advance(2.0)
	check(state.day_number() == 2 and state.hour() < 0.1, "Midnight increments day and wraps clock")
	var before := state.elapsed_days
	state.advance(0.0)
	state.advance(-1.0)
	state.advance(NAN)
	check(state.elapsed_days == before, "Invalid time steps do not advance simulation")
	state.elapsed_days = 0.5
	check(state.daylight() > 0.99, "Noon has daylight")
	var daytime_temperature := state.temperature_celsius()
	state.elapsed_days = 0.0
	check(state.daylight() == 0.0, "Midnight has no sunlight")
	check(state.temperature_celsius() < daytime_temperature, "Night is colder")
	check(not state.set_weather("unknown") and state.kind == "cloudy", "Unknown weather is rejected without mutation")
	state.set_weather("clear", true)
	state.set_weather("rain")
	state.advance(1.0)
	check(state.values.rain > 0.0 and state.values.rain < 1.0, "Weather interpolates gradually")
	state.set_weather("rain", true)
	check(state.snapshot().wetness_rate > 0.0, "Rain exposes wetness to survival systems")
	state.set_weather("blizzard", true)
	check(state.values.snow == 1.0 and state.temperature_celsius() < -10.0, "Blizzard is snowy and cold")
	for kind: String in state.PRESETS:
		state.set_weather(kind, true)
		state.weather_remaining = 0.01
		state.advance(0.02)
		check(state.kind != kind and state.weather_remaining > 0.0, "Automatic transition from " + kind)


func run() -> void:
	check_simulation()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_meta("qa_runner", self)
	await frames(8)
	var climate = game.street.climate
	var before: float = climate.state.elapsed_days
	await frames(8)
	check(climate.state.elapsed_days == before, "Menu freezes world time")
	game.start_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(10)
	check(climate.state.elapsed_days > before and climate.status_layer.visible, "Gameplay advances clock and shows weather")
	game.pause_game()
	before = climate.state.elapsed_days
	await frames(10)
	check(climate.state.elapsed_days == before and climate.precipitation.rain.speed_scale == 0.0, "Pause freezes time and particles")
	game.start_game()
	game.street.set_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = Vector3(0, 2, 15)
	climate.state.set_weather("rain", true)
	climate.precipitation.update_weather(1.0, camera, climate.state.values, true, false)
	check(not climate.precipitation.sheltered and climate.precipitation.rain.emitting, "Rain emits outside")
	climate.precipitation.update_weather(1.0, camera, climate.state.values, true, true)
	check(is_equal_approx(climate.precipitation.rain.amount_ratio, 0.5), "Low quality halves particle density")
	var roof := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	collision.shape = box
	roof.add_child(collision)
	game.add_child(roof)
	roof.global_position = camera.global_position + Vector3.UP * 3
	await frames(3)
	climate.precipitation.update_weather(1.0, camera, climate.state.values, true, false)
	check(climate.precipitation.sheltered and not climate.precipitation.rain.visible, "Roof suppresses local precipitation")
	roof.queue_free()
	camera.queue_free()
	climate.state.elapsed_days = 0.0
	climate.update_lighting()
	check(climate.sun.light_energy == 0 and climate.moon.light_energy > 0, "Night switches to moon lighting")
	check(climate.get_environment_state().has("temperature_celsius"), "Street exposes climate integration contract")
	game.street.set_process(true)
	if "--capture-weather" in OS.get_cmdline_user_args():
		await capture(game)
	print("WEATHER CHECKS: ", checks, " / FAILURES: ", failures)
	game.ambient.stop()
	game.remove_meta("qa_runner")
	game.queue_free()
	await frames(8)
	quit(1 if failures else 0)


func capture(game: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute("res://qa-output")
	for scenario in [{"kind": "clear", "hour": 12.0}, {"kind": "rain", "hour": 16.5}, {"kind": "blizzard", "hour": 13.0}, {"kind": "clear", "hour": 0.0}]:
		var climate = game.street.climate
		climate.state.set_weather(scenario.kind, true)
		climate.state.elapsed_days = scenario.hour / 24.0
		await create_timer(5.0).timeout
		await RenderingServer.frame_post_draw
		var path := "res://qa-output/weather-%s-%s.png" % [scenario.kind, scenario.hour]
		check(root.get_texture().get_image().save_png(path) == OK, "Capture " + path)

