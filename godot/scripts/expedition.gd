extends Node3D

const Street = preload("res://scripts/street.gd")
const Survivor = preload("res://scripts/survivor.gd")
const Hud = preload("res://scripts/hud.gd")
const InputBindings = preload("res://scripts/input_bindings.gd")
const CombatDirector = preload("res://scripts/combat/combat_director.gd")
const PICKUP_TIME := 1.3

var street: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var inventory: Array[String] = []
var started := false
var completed := false
var paused := true
var low_quality := false
var focused_pickup := -1
var can_use_stove := false
var ambient: AudioStreamPlayer
var director: Node3D
var combat_interaction := {}
var dead := false


func _ready() -> void:
	InputBindings.install()
	street = Street.new()
	add_child(street)
	player = Survivor.new()
	add_child(player)
	player.position = Vector3(0, 0.1, 15)
	player.visual.rotation.y = PI
	hud = Hud.new()
	add_child(hud)
	hud.start_requested.connect(start_game)
	hud.exit_requested.connect(func(): get_tree().quit())
	hud.quality_requested.connect(toggle_quality)
	director = CombatDirector.new()
	add_child(director)
	director.setup(self)
	director.player_died.connect(on_player_died)
	create_audio()
	hud.show_menu(false)
	if "--smoke-test" in OS.get_cmdline_user_args() or "--capture-qa" in OS.get_cmdline_user_args():
		var qa = load("res://tests/prototype_qa.gd").new()
		set_meta("qa_runner", qa)
		qa.run.call_deferred(self)


func create_audio() -> void:
	ambient = AudioStreamPlayer.new()
	var sound: AudioStreamWAV = load("res://assets/audio/wind.wav")
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = int(sound.get_length() * sound.mix_rate)
	ambient.stream = sound
	ambient.volume_db = -12.0
	add_child(ambient)
	ambient.play()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_WINDOW_FOCUS_OUT or not started or paused:
		return
	if has_meta("qa_runner"):
		return
	pause_game()


func start_game() -> void:
	var first_start := not started
	started = true
	paused = false
	player.active = true
	player.animation.active = true
	hud.show_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if first_start:
		hud.notify("Yakıt kaldırımda, erzak depoda. Metal parça bariyerlerin yakınında.")
		if not has_meta("qa_runner"):
			director.start()


func on_player_died(_cause: String) -> void:
	dead = true
	paused = true
	hud.prompt.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("performance"):
		hud.performance.visible = not hud.performance.visible
	if not started or dead:
		return
	if event.is_action_pressed("pause_game"):
		if hud.inventory_panel.visible:
			close_inventory()
			return
		if paused:
			start_game()
			return
		pause_game()
		return
	if event.is_action_pressed("inventory") and not hud.menu.visible:
		if hud.inventory_panel.visible:
			close_inventory()
			return
		paused = true
		player.active = false
		player.animation.active = false
		hud.show_inventory(inventory + director.combat.summary())
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not paused and event.is_action_pressed("interact"):
		interact()


func pause_game() -> void:
	paused = true
	player.active = false
	player.animation.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu(true)


func close_inventory() -> void:
	hud.inventory_panel.hide()
	paused = false
	player.active = true
	player.animation.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_quality() -> void:
	low_quality = not low_quality
	get_viewport().scaling_3d_scale = 0.8 if low_quality else 1.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low_quality else Viewport.MSAA_2X
	street.sun.directional_shadow_max_distance = 32.0 if low_quality else 55.0
	hud.quality_button.text = "GÖRÜNTÜ  /  PERFORMANS" if low_quality else "GÖRÜNTÜ  /  DENGELİ"


func _process(delta: float) -> void:
	if paused:
		return
	find_interaction()
	var near_fire := player.position.distance_to(street.stove_position) < 3.2
	player.warmth = clampf(player.warmth + (2.8 if near_fire else -0.12) * delta, 0.0, 100.0)
	hud.update_status(player.stamina, player.warmth, inventory.size(), completed)


func find_interaction() -> void:
	focused_pickup = -1
	can_use_stove = false
	var nearest := 2.1
	for index in range(street.pickups.size()):
		var item: Dictionary = street.pickups[index]
		if item.collected:
			continue
		var distance: float = player.position.distance_to(item.node.global_position)
		if distance >= nearest or not has_line_of_sight(item.node.global_position):
			continue
		nearest = distance
		focused_pickup = index
	if focused_pickup >= 0:
		hud.prompt.text = "[ E ]   " + street.pickups[focused_pickup].label + " al"
		combat_interaction = {}
		return
	combat_interaction = director.nearest_interaction(player.position)
	if not combat_interaction.is_empty() and has_line_of_sight(combat_interaction.node.global_position + Vector3(0, 0.3, 0), combat_interaction.node):
		hud.prompt.text = "[ E ]   " + combat_interaction.label
		return
	combat_interaction = {}
	can_use_stove = player.position.distance_to(street.stove_position) < 2.2 and has_line_of_sight(street.stove_position + Vector3(0, 1.2, 0))
	hud.prompt.text = "[ E ]   " + ("Hazırlığı tamamla" if inventory.size() == 3 and not completed else "Sobanın yanında ısın") if can_use_stove else ""


func has_line_of_sight(target: Vector3, ignore: Node = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.position + Vector3(0, 1.35, 0), target + Vector3(0, 0.2, 0))
	query.exclude = [player.get_rid()] if not ignore is CollisionObject3D else [player.get_rid(), ignore.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# The survivor turns to the item, kneels, and the item leaves the ground when the
# hand reaches it, halfway through the clip.
func pick_up(node: Node3D, take := true) -> void:
	var to_item := node.global_position - player.global_position
	player.visual.rotation.y = atan2(to_item.x, to_item.z)
	player.play_action("PickUp", PICKUP_TIME)
	if not take:
		return
	await get_tree().create_timer(PICKUP_TIME * 0.5).timeout
	node.hide()


func interact() -> void:
	find_interaction()
	if focused_pickup >= 0:
		if player.busy():
			return
		var item: Dictionary = street.pickups[focused_pickup]
		item.collected = true
		inventory.append(item.label)
		hud.notify(item.label + " çantaya eklendi.")
		pick_up(item.node)
		find_interaction()
		return
	if not combat_interaction.is_empty():
		if player.busy():
			return
		var target: Dictionary = combat_interaction
		director.use(target)
		var taken: bool = target.has("pickup") and target.pickup.taken
		if taken or target.has("body"):
			pick_up(target.node, taken)
		find_interaction()
		return
	if not can_use_stove:
		return
	player.warmth = minf(100.0, player.warmth + 15.0)
	if inventory.size() == 3 and not completed:
		completed = true
		hud.notify("İlk gece için hazırsın. Sokakta keşfe devam edebilirsin.")
		return
	hud.notify("Ateşin sıcaklığı ellerine geri dönüyor.")
