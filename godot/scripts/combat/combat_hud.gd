extends CanvasLayer
# Combat overlay: crosshair, weapon and ammo, health, hit marker, damage flash
# and the death screen. Sits above the main HUD and follows its look.

const Weapons = preload("res://scripts/combat/weapons.gd")
const INK := Color("eee9dd")
const MUTED := Color("adb8b8")
const RED := Color("c4553f")

var director: Node
var root: Control
var crosshair: Control
var ticks: Array[ColorRect] = []
var weapon_label: Label
var hints: Label
var health_bar: ProgressBar
var health_label: Label
var marker: Label
var marker_time := 0.0
var damage: ColorRect
var damage_time := 0.0
var death_panel: Control
var death_text: Label


func setup(combat_director: Node) -> void:
	director = combat_director


func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/BarlowCondensed-Regular.ttf")
	theme.default_font_size = 20
	root.theme = theme
	add_child(root)
	damage = ColorRect.new()
	damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage.color = Color(0.55, 0.05, 0.03, 0.0)
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage)
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	for index in 4:
		var tick := ColorRect.new()
		tick.color = Color(0.94, 0.91, 0.85, 0.8)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(tick)
		ticks.append(tick)
	marker = text(root, "✕", 30, INK)
	marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	marker.offset_left = -20
	marker.offset_right = 20
	marker.offset_top = -22
	marker.offset_bottom = 22
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.modulate.a = 0.0
	weapon_label = text(root, "", 30, INK)
	anchor_bottom_right(weapon_label, 78)
	hints = text(root, "SOL TIK  Ateş     SAĞ TIK  Nişan     R  Doldur     1-4  Silah     H  Sargı     M  Harita", 15, MUTED)
	anchor_bottom_right(hints, 40)
	health_label = text(root, "SAĞLIK", 15, MUTED)
	anchor_bottom_right(health_label, 150)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.max_value = 100.0
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	health_bar.offset_left = -292
	health_bar.offset_right = -32
	health_bar.offset_top = -122
	health_bar.offset_bottom = -114
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.06, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	health_bar.add_theme_stylebox_override("background", background)
	health_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(health_bar)
	create_death_panel()


func text(parent: Control, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func anchor_bottom_right(label: Label, from_bottom: float) -> void:
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -700
	label.offset_right = -32
	label.offset_top = -from_bottom - 34
	label.offset_bottom = -from_bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func create_death_panel() -> void:
	death_panel = ColorRect.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.color = Color(0.03, 0.03, 0.04, 0.78)
	root.add_child(death_panel)
	var title := text(death_panel, "ÖLDÜN", 72, RED)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = -150
	title.offset_bottom = -60
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text = text(death_panel, "", 24, INK)
	death_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_text.offset_left = -400
	death_text.offset_right = 400
	death_text.offset_top = -50
	death_text.offset_bottom = 30
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := Button.new()
	again.text = "YENİDEN BAŞLA"
	again.add_theme_font_size_override("font_size", 24)
	again.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	again.offset_left = -130
	again.offset_right = 130
	again.offset_top = 60
	again.offset_bottom = 112
	again.pressed.connect(func(): get_tree().reload_current_scene())
	death_panel.add_child(again)
	death_panel.hide()


func show_hit(head: bool, killed: bool) -> void:
	marker.add_theme_color_override("font_color", RED if killed or head else INK)
	marker_time = 0.18 if not killed else 0.35


func show_damage(_from: Vector3) -> void:
	damage_time = minf(1.0, damage_time + 0.5)


func show_death(cause: String, kills: int) -> void:
	death_text.text = "Ölüm nedeni: %s\nEtkisiz bırakılan asker: %d" % [cause, kills]
	death_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not director:
		return
	var game: Node = director.game
	var player: CharacterBody3D = director.player
	var combat: Node = director.combat
	var playing: bool = game.started and not game.paused and player.alive
	root.visible = game.started
	for control in [weapon_label, hints, health_bar, health_label]:
		control.visible = playing
	var gun: Dictionary = combat.data()
	weapon_label.text = gun.name
	if not gun.get("melee", false):
		weapon_label.text += "   %d / %d" % [combat.magazine[combat.weapon], combat.ammo[gun.ammo]]
		if combat.reload_left > 0.0:
			weapon_label.text += "   DOLDURULUYOR"
	if combat.bandages > 0:
		weapon_label.text += "   ·   SARGI %d" % combat.bandages
	health_bar.value = player.hp
	health_label.text = "SAĞLIK" + ("   KANAMA" if player.bleeding else "")
	health_label.add_theme_color_override("font_color", RED if player.bleeding else MUTED)
	var armed: bool = Weapons.is_gun(combat.weapon)
	crosshair.visible = playing and armed
	var gap := 6.0 + (10.0 if not player.aim_mode() else 0.0) + (8.0 if Vector2(player.velocity.x, player.velocity.z).length() > 0.3 else 0.0)
	var sizes := [Vector2(2, 8), Vector2(2, 8), Vector2(8, 2), Vector2(8, 2)]
	var offsets := [Vector2(-1, -gap - 8), Vector2(-1, gap), Vector2(-gap - 8, -1), Vector2(gap, -1)]
	for index in 4:
		ticks[index].size = sizes[index]
		ticks[index].position = offsets[index]
	marker_time = maxf(0.0, marker_time - delta)
	marker.modulate.a = minf(1.0, marker_time * 6.0)
	damage_time = maxf(0.0, damage_time - delta * 1.2)
	var low := clampf((30.0 - player.hp) / 30.0, 0.0, 1.0) * (0.35 + 0.15 * sin(Time.get_ticks_msec() / 200.0)) if player.alive else 0.0
	damage.color.a = maxf(damage_time * 0.45, low * 0.5)
