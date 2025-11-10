extends Control

@onready var back_button = $VBoxContainer/BackButton
@onready var up_button = $VBoxContainer/UpContainer/UpButton
@onready var down_button = $VBoxContainer/DownContainer/DownButton
@onready var left_button = $VBoxContainer/LeftContainer/LeftButton
@onready var right_button = $VBoxContainer/RightContainer/RightButton

var waiting_for_input = false
var current_action = ""
var current_button = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	up_button.pressed.connect(_on_up_button_pressed)
	down_button.pressed.connect(_on_down_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	_update_button_texts()

func _update_button_texts():
	# Get current key for each action and update button text
	up_button.text = _get_action_key_name("move_up")
	down_button.text = _get_action_key_name("move_down")
	left_button.text = _get_action_key_name("move_left")
	right_button.text = _get_action_key_name("move_right")

func _get_action_key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	# Prioritize letter keys (using keycode) over arrow keys
	for event in events:
		if event is InputEventKey:
			# Use keycode if available (layout-dependent), otherwise physical_keycode
			var keycode_to_use = event.keycode if event.keycode != 0 else event.physical_keycode
			# Arrow keys are 4194319-4194322, so prioritize keys below that
			if keycode_to_use < 4194319:
				return OS.get_keycode_string(keycode_to_use)
	# If no letter key found, return the first key
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			var keycode_to_use = event.keycode if event.keycode != 0 else event.physical_keycode
			return OS.get_keycode_string(keycode_to_use)
	return "?"

func _on_up_button_pressed():
	_start_input_remap("move_up", up_button)

func _on_down_button_pressed():
	_start_input_remap("move_down", down_button)

func _on_left_button_pressed():
	_start_input_remap("move_left", left_button)

func _on_right_button_pressed():
	_start_input_remap("move_right", right_button)

func _start_input_remap(action: String, button: Button):
	waiting_for_input = true
	current_action = action
	current_button = button
	button.text = "Press a key..."

func _input(event):
	if waiting_for_input and event is InputEventKey and event.pressed:
		# Don't remap if Escape is pressed
		if event.keycode == KEY_ESCAPE:
			waiting_for_input = false
			_update_button_texts()
			return
		
		# Remove old key events from the action
		InputMap.action_erase_events(current_action)
		
		# Add the new key event - use keycode (layout-dependent) for letter keys
		var new_event = InputEventKey.new()
		# Prefer keycode over physical_keycode for layout-dependent detection
		if event.keycode != 0:
			new_event.keycode = event.keycode
		else:
			new_event.physical_keycode = event.physical_keycode
		InputMap.action_add_event(current_action, new_event)
		
		# Also keep arrow keys if they exist
		var arrow_key = _get_arrow_key_for_action(current_action)
		if arrow_key != null:
			InputMap.action_add_event(current_action, arrow_key)
		
		# Update button text - use keycode if available
		var display_keycode = event.keycode if event.keycode != 0 else event.physical_keycode
		current_button.text = OS.get_keycode_string(display_keycode)
		
		waiting_for_input = false
		current_action = ""
		current_button = null
		
		# Consume the event so it doesn't trigger other actions
		get_viewport().set_input_as_handled()

func _get_arrow_key_for_action(action: String) -> InputEventKey:
	# Return the corresponding arrow key for each action
	var arrow_key = InputEventKey.new()
	match action:
		"move_up":
			arrow_key.physical_keycode = KEY_UP
		"move_down":
			arrow_key.physical_keycode = KEY_DOWN
		"move_left":
			arrow_key.physical_keycode = KEY_LEFT
		"move_right":
			arrow_key.physical_keycode = KEY_RIGHT
		_:
			return null
	return arrow_key

func _on_back_pressed():
	# Check if we came from the game using the context node
	var context = get_tree().root.get_node_or_null("OptionsContext")
	var from_game = false
	if context != null:
		from_game = context.get_meta("from_game", false)
		context.set_meta("from_game", false)  # Reset flag
	
	if from_game:
		# We came from the game, go back to it
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	else:
		# We came from main menu
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
