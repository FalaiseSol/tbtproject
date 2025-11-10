extends CanvasLayer

@onready var control = $Control
@onready var exit_button = $Control/ExitButton
@onready var main_menu_button = $Control/CenterContainer/MainMenuButton
@onready var options_button = $Control/CenterContainer/OptionsButton
@onready var overlay = $Control/Overlay

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	options_button.pressed.connect(_on_options_pressed)
	# Make sure this node processes input even when paused
	set_process_mode(PROCESS_MODE_ALWAYS)
	# Hide by default
	control.visible = false

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu():
	control.visible = !control.visible
	get_tree().paused = control.visible

func _on_exit_pressed():
	close_menu()

func _on_main_menu_pressed():
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_options_pressed():
	# Mark that we're coming from the game
	# Set a flag that Options can check
	if not get_tree().root.has_node("OptionsContext"):
		var context = Node.new()
		context.name = "OptionsContext"
		get_tree().root.add_child(context)
	get_tree().root.get_node("OptionsContext").set_meta("from_game", true)
	# Unpause and change to Options scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Options.tscn")

func close_menu():
	control.visible = false
	get_tree().paused = false

