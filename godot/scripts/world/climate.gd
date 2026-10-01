extends Node3D

const WeatherState = preload("res://scripts/world/weather_state.gd")
const Precipitation = preload("res://scripts/world/precipitation.gd")

var state := WeatherState.new()
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var precipitation: Node3D
var status_layer: CanvasLayer
var status: Label


func _ready() -> void:
	name = "Climate"
	create_lighting()
	precipitation = Precipitation.new()
	add_child(precipitation)
	create_status()
	update_lighting()


func create_lighting() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_curve = 0.22
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.3
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("9db6df")
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.shadow_enabled = false
	add_child(moon)


func create_status() -> void:
	status_layer = CanvasLayer.new()
	status_layer.layer = 6
	add_child(status_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_layer.add_child(root)
	status = Label.new()
	status.position = Vector2(32, 119)
	status.add_theme_font_override("font", load("res://assets/fonts/BarlowCondensed-Regular.ttf"))
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("d8d5c8"))
	status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status.add_theme_constant_override("shadow_offset_y", 2)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	status_layer.hide()


func tick(delta: float, camera: Camera3D, active: bool, low_quality: bool) -> void:
	status_layer.visible = active
	precipitation.update_weather(delta, camera, state.values, active, low_quality)
	if not active:
		return
	state.advance(delta)
	update_lighting()
	var minutes := int(state.hour() * 60.0)
	status.text = "GÜN %d  /  %02d:%02d\n%s  ·  %.0f °C" % [state.day_number(), minutes / 60, minutes % 60, state.PRESETS[state.kind].label, state.temperature_celsius()]


func update_lighting() -> void:
	var day := state.daylight()
	var cloud := float(state.values.cloud)
	var solar_angle := (state.hour() - 6.0) * TAU / 24.0
	var dusk := (1.0 - smoothstep(0.0, 0.45, absf(sin(solar_angle)))) * day
	var horizon := Color("a7b6bc").lerp(Color("879095"), cloud)
	horizon = horizon.lerp(Color("cc986f"), dusk * (1.0 - cloud * 0.75))
	horizon = Color("101a2c").lerp(horizon, day)
	sky_material.sky_top_color = Color("050d1e").lerp(Color("496a85").lerp(Color("727d87"), cloud), day)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_bottom_color = Color("080d16").lerp(Color("364047"), day)
	sky_material.ground_horizon_color = horizon
	sun.rotation = Vector3(-solar_angle, deg_to_rad(-32.0), 0.0)
	sun.light_energy = day * 1.6 * (1.0 - cloud * 0.65)
	sun.light_color = Color("f0dfc3").lerp(Color("ffa16b"), dusk)
	sun.shadow_enabled = day > 0.02
	moon.rotation = Vector3(-solar_angle + PI, deg_to_rad(-32.0), 0.0)
	moon.light_energy = (1.0 - day) * 0.22 * (1.0 - cloud * 0.5)
	environment.ambient_light_color = Color("738eae").lerp(Color("bcc8d0"), day)
	environment.ambient_light_energy = lerpf(0.1, 0.58, day) * (1.0 - cloud * 0.2)
	environment.fog_light_color = horizon
	environment.fog_density = float(state.values.fog)


func get_environment_state() -> Dictionary:
	return state.snapshot()
