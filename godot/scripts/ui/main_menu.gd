extends Control

const OPTIONS_SCENE = preload("res://scenes/Options.tscn")
const GAME_SCENE = preload("res://scenes/Game.tscn")

@onready var register_button = $CenterContainer/RegisterButton
@onready var login_button = $CenterContainer/LoginButton
@onready var options_button = $CenterContainer/OptionsButton
@onready var exit_button = $ExitButton

func _ready():
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_register_pressed():
	print("Register button pressed")
	# TODO: Open register screen

func _on_login_pressed():
	# For now, go directly to game scene
	# TODO: Add login screen later
	get_tree().change_scene_to_packed(GAME_SCENE)

func _on_options_pressed():
	get_tree().change_scene_to_packed(OPTIONS_SCENE)

func _on_exit_pressed():
	get_tree().quit()
