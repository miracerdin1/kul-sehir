extends RefCounted
# Shared by the survivor and the soldiers: layers the weapon pose over the legs,
# turns the chest toward the target and keeps the gun in the right hand.

const BodyRig = preload("res://scripts/combat/body_rig.gd")
const GunModel = preload("res://scripts/combat/gun_model.gd")
const Weapons = preload("res://scripts/combat/weapons.gd")
const STRIKE_TIME := 0.35
const MAX_TWIST := 1.25

var rig: BodyRig
var visual: Node3D
var weapon := ""
var gun: Node3D
var aim_weight := 0.0
var hold_weight := 0.0
var pose_time := 0.0
var strike_time := 0.0
var hand := -1
var finger := -1


func _init(animation: AnimationPlayer, model: Node3D, visual_root: Node3D) -> void:
	visual = visual_root
	if model.find_children("*", "Skeleton3D", true, false).is_empty():
		return
	rig = BodyRig.new(animation, model)
	hand = rig.find_bone("RightHand")
	finger = rig.find_bone("RightHandMiddle1")


func set_weapon(kind: String) -> void:
	if kind == weapon:
		return
	weapon = kind
	if gun:
		gun.queue_free()
		gun = null
	if kind != "fists" and kind != "":
		gun = GunModel.build(kind)
		gun.top_level = true
		visual.add_child(gun)


func strike() -> void:
	strike_time = STRIKE_TIME


func muzzle_position() -> Vector3:
	if gun and gun.has_node("Muzzle"):
		return gun.get_node("Muzzle").global_position
	return visual.global_position + Vector3(0, 1.4, 0)


# Call right after the AnimationPlayer has advanced for this frame.
# aim_target is the world point the weapon should point at.
func update(delta: float, aiming: bool, aim_target: Vector3) -> void:
	if rig == null:
		return
	pose_time += delta
	var aim_pose: String = Weapons.DATA.get(weapon, {}).get("pose", "")
	var hold_pose := "HoldRifle" if weapon in ["rifle", "shotgun"] else ""
	aim_weight = move_toward(aim_weight, 1.0 if aiming and aim_pose != "" else 0.0, delta * 7.0)
	hold_weight = move_toward(hold_weight, 1.0 if hold_pose != "" and not aiming else 0.0, delta * 7.0)
	if hold_weight > 0.0:
		rig.overlay(hold_pose, fmod(pose_time, rig.length(hold_pose)), hold_weight)
	var chest := visual.global_position + Vector3(0, 1.4, 0)
	var to_target := aim_target - chest
	if aim_weight > 0.0:
		rig.overlay(aim_pose, fmod(pose_time, rig.length(aim_pose)), aim_weight)
		var flat := Vector2(to_target.x, to_target.z)
		var facing := visual.global_rotation.y
		var yaw := clampf(wrapf(atan2(to_target.x, to_target.z) - facing, -PI, PI), -MAX_TWIST, MAX_TWIST)
		var pitch := atan2(to_target.y, maxf(flat.length(), 0.01))
		rig.twist(yaw * aim_weight, clampf(pitch, -0.9, 0.9) * aim_weight)
	if strike_time > 0.0:
		strike_time = maxf(0.0, strike_time - delta)
		rig.overlay("Strike", (1.0 - strike_time / STRIKE_TIME) * rig.length("Strike"), 1.0)
	place_gun(aim_target)


func place_gun(aim_target: Vector3) -> void:
	if gun == null or hand < 0:
		return
	var skeleton := rig.skeleton
	var grip := skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
	var front := visual.global_basis.z.normalized()
	var forward: Vector3
	if aim_weight > 0.5:
		forward = aim_target - grip
	elif weapon == "knife":
		forward = skeleton.global_transform * skeleton.get_bone_global_pose(finger).origin - grip if finger >= 0 else front
	elif hold_weight > 0.5:
		forward = front + Vector3.DOWN * 0.35
	else:
		forward = front * 0.35 + Vector3.DOWN
	if forward.length() < 0.001:
		forward = front
	forward = forward.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else front
	gun.global_transform = Transform3D(Basis.looking_at(forward, up), grip)
