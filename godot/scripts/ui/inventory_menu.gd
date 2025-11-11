extends CanvasLayer

@onready var control = $Control
@onready var exit_button = $Control/ExitButton

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)
	# Make sure this node processes input even when paused
	set_process_mode(PROCESS_MODE_ALWAYS)
	# Hide by default
	control.visible = false

func _input(event):
	if event.is_action_pressed("inventory"):  # I key
		toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu():
	control.visible = !control.visible
	get_tree().paused = control.visible

func _on_exit_pressed():
	close_menu()

func close_menu():
	control.visible = false
	get_tree().paused = false

