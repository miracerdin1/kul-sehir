extends RefCounted


static func install() -> void:
	var bindings := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE,
		"interact": KEY_E, "inventory": KEY_B,
		"flashlight": KEY_F, "pause_game": KEY_ESCAPE,
		"performance": KEY_F2, "fullscreen": KEY_F11,
	}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
