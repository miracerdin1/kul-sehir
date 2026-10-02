extends RefCounted
# Boot steps on gritty concrete (six takes) and kit rattle, synthesized by
# tools/make_sounds.py. Shared by the survivor and the soldiers.

const STEPS := 6

static var steps: Array[AudioStream] = []
static var rattle: AudioStream
static var last := -1


static func step() -> AudioStream:
	if steps.is_empty():
		for index in range(STEPS):
			steps.append(load("res://assets/audio/footstep_%d.ogg" % (index + 1)))
	# Never the same take twice in a row.
	var pick := randi() % STEPS
	if pick == last:
		pick = (pick + 1) % STEPS
	last = pick
	return steps[pick]


static func gear() -> AudioStream:
	if rattle == null:
		rattle = load("res://assets/audio/gear_rattle.ogg")
	return rattle


# Plays one footfall on a player: louder and a touch brighter the faster the gait.
static func play(player: AudioStreamPlayer3D, gait: String, louder := 0.0) -> void:
	player.stream = step()
	player.volume_db = {"sneak": -24.0, "walk": -15.0, "run": -9.0, "sprint": -6.0}[gait] + louder
	player.pitch_scale = randf_range(0.92, 1.06) * (1.06 if gait == "sprint" else 1.0)
	player.play()
