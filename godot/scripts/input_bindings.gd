extends RefCounted


static func install() -> void:
	var bindings := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "walk": [KEY_ALT], "jump": [KEY_SPACE],
		"crouch": [KEY_C, KEY_CTRL], "prone": [KEY_Z],
		"interact": [KEY_E], "inventory": [KEY_B], "map": [KEY_M],
		"flashlight": [KEY_F], "pause_game": [KEY_ESCAPE],
		"performance": [KEY_F2], "fullscreen": [KEY_F11],
		"weapon_5": [KEY_5], "place_mine": [KEY_G],
		"reload": [KEY_R], "bandage": [KEY_H],
		"weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3], "weapon_4": [KEY_4],
	}
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
	for action: String in mouse:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var button := InputEventMouseButton.new()
		button.button_index = mouse[action]
		InputMap.action_add_event(action, button)
