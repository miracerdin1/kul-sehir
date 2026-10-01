extends RefCounted
## Simulation only: seconds passed to advance() are unpaused real seconds.

signal weather_changed(kind: String)
signal day_changed(day: int)

const DAY_DURATION_SECONDS := 1200.0
const PRESETS := {
	"clear": {"label": "Açık", "cloud": 0.05, "fog": 0.003, "rain": 0.0, "snow": 0.0, "wind": 0.15, "cold": 0.0},
	"cloudy": {"label": "Bulutlu", "cloud": 0.65, "fog": 0.009, "rain": 0.0, "snow": 0.0, "wind": 0.35, "cold": -1.5},
	"fog": {"label": "Sisli", "cloud": 0.7, "fog": 0.045, "rain": 0.0, "snow": 0.0, "wind": 0.1, "cold": -1.0},
	"rain": {"label": "Yağmurlu", "cloud": 0.9, "fog": 0.02, "rain": 1.0, "snow": 0.0, "wind": 0.6, "cold": -4.0},
	"snow": {"label": "Kar yağışı", "cloud": 0.8, "fog": 0.022, "rain": 0.0, "snow": 0.65, "wind": 0.4, "cold": -8.0},
	"blizzard": {"label": "Tipi", "cloud": 1.0, "fog": 0.06, "rain": 0.0, "snow": 1.0, "wind": 1.0, "cold": -14.0},
}
const CHANNELS := ["cloud", "fog", "rain", "snow", "wind", "cold"]

var elapsed_days := 16.5 / 24.0
var kind := "cloudy"
var values: Dictionary = PRESETS.cloudy.duplicate()
var weather_remaining := 100.0
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 71026) -> void:
	rng.seed = seed_value


func advance(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	var previous_day := day_number()
	elapsed_days += delta / DAY_DURATION_SECONDS
	if day_number() != previous_day:
		day_changed.emit(day_number())
	weather_remaining -= delta
	while weather_remaining <= 0.0:
		var remaining := weather_remaining
		choose_next_weather()
		weather_remaining += remaining
	var blend := 1.0 - exp(-delta / 12.0)
	for channel: String in CHANNELS:
		values[channel] = lerpf(values[channel], PRESETS[kind][channel], blend)


func set_weather(next: String, immediate: bool = false) -> bool:
	if not PRESETS.has(next):
		return false
	var changed := kind != next
	kind = next
	weather_remaining = rng.randf_range(90.0, 160.0)
	if immediate:
		values = PRESETS[kind].duplicate()
	if changed:
		weather_changed.emit(kind)
	return true


func choose_next_weather() -> void:
	var weights := {"clear": 22, "cloudy": 28, "fog": 12, "rain": 20, "snow": 14, "blizzard": 4}
	weights.erase(kind)
	var total := 0
	for weight: int in weights.values():
		total += weight
	var roll := rng.randi_range(1, total)
	for candidate: String in weights:
		roll -= weights[candidate]
		if roll <= 0:
			set_weather(candidate)
			return


func hour() -> float:
	return fposmod(elapsed_days, 1.0) * 24.0


func day_number() -> int:
	return int(floor(elapsed_days)) + 1


func daylight() -> float:
	return smoothstep(-0.12, 0.3, sin((hour() - 6.0) * TAU / 24.0))


func temperature_celsius() -> float:
	return 3.0 + 6.0 * cos((hour() - 14.0) * TAU / 24.0) + float(values.cold)


func snapshot() -> Dictionary:
	return {
		"day": day_number(), "hour": hour(), "weather": kind,
		"label": PRESETS[kind].label, "daylight": daylight(),
		"temperature_celsius": temperature_celsius(), "rain": values.rain,
		"snow": values.snow, "wind": values.wind,
		"wetness_rate": float(values.rain) * 0.8 + float(values.snow) * 0.15,
	}
