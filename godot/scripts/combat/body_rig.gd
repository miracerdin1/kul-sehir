extends RefCounted
# Layers a weapon pose over the arms and spine of whatever the legs are playing,
# then turns the spine toward the aim direction. The AnimationPlayer must be
# advanced manually so the overlay lands after the leg clip each frame.

const UPPER := ["Spine", "Neck", "Head", "Shoulder", "Arm", "Hand"]
const OVERLAYS := ["AimRifle", "AimPistol", "HoldRifle", "Strike"]

var animation: AnimationPlayer
var skeleton: Skeleton3D
var tracks := {}
var spine: Array[int] = []


func _init(player: AnimationPlayer, model: Node) -> void:
	animation = player
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for name in ["Spine", "Spine1", "Spine2"]:
		var bone := find_bone(name)
		if bone >= 0:
			spine.append(bone)
	for clip in animation.get_animation_list():
		var short := clip.get_slice("/", clip.get_slice_count("/") - 1)
		if short not in OVERLAYS:
			continue
		var source := animation.get_animation(clip)
		var rows: Array = []
		for track in source.get_track_count():
			if source.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var bone_name := String(source.track_get_path(track).get_concatenated_subnames())
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0 and is_upper(bone_name):
				rows.append([track, bone])
		tracks[short] = [source, rows]


func find_bone(suffix: String) -> int:
	for bone in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(bone)
		if name.ends_with(":" + suffix) or name.ends_with("_" + suffix) or name == suffix:
			return bone
	return -1


static func is_upper(bone_name: String) -> bool:
	for key in UPPER:
		if key in bone_name:
			return true
	return false


func has(clip: String) -> bool:
	return tracks.has(clip)


func length(clip: String) -> float:
	return tracks[clip][0].length if tracks.has(clip) else 0.0


# Blends the clip's arm and spine rotations at the given time over the current pose.
func overlay(clip: String, time: float, weight: float) -> void:
	if weight <= 0.0 or not tracks.has(clip):
		return
	var source: Animation = tracks[clip][0]
	for row: Array in tracks[clip][1]:
		var target: Quaternion = source.rotation_track_interpolate(row[0], time)
		var current := skeleton.get_bone_pose_rotation(row[1])
		skeleton.set_bone_pose_rotation(row[1], current.slerp(target, weight))


# Spreads a yaw (radians, positive turns left) and pitch (positive looks up)
# over the three spine bones so the chest and arms follow the camera.
func twist(yaw: float, pitch: float) -> void:
	if spine.is_empty():
		return
	var turn := Quaternion(Vector3.UP, yaw / spine.size()) * Quaternion(Vector3.RIGHT, -pitch / spine.size())
	for bone in spine:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * turn)


func bone_name(suffix: String) -> String:
	var bone := find_bone(suffix)
	return skeleton.get_bone_name(bone) if bone >= 0 else ""
