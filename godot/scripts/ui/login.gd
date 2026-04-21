extends Control

const LOBBY_SCENE = preload("res://scenes/Lobby.tscn")
const REGISTER_SCENE = preload("res://scenes/Register.tscn")
const MAIN_SCENE = preload("res://scenes/Main.tscn")

@onready var email_input = $VBoxContainer/EmailInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var remember_me: CheckBox = $VBoxContainer/RememberMe
@onready var login_button = $VBoxContainer/LoginButton
@onready var loading_label: Label = $VBoxContainer/LoadingLabel
@onready var register_link = $VBoxContainer/RegisterLink
@onready var back_button = $VBoxContainer/BackButton
@onready var error_label = $VBoxContainer/ErrorLabel

const PREFS_PATH = "user://login_prefs.cfg"

func _ready() -> void:
	error_label.visible = false
	login_button.pressed.connect(_on_login_pressed)
	register_link.pressed.connect(func(): get_tree().change_scene_to_packed(REGISTER_SCENE))
	back_button.pressed.connect(func(): get_tree().change_scene_to_packed(MAIN_SCENE))
	Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	Firebase.Auth.login_failed.connect(_on_login_failed)
	_load_prefs()

func _load_prefs() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(PREFS_PATH) != OK:
		return
	var remembered = cfg.get_value("login", "remember_me", false)
	remember_me.button_pressed = remembered
	if remembered:
		email_input.text = cfg.get_value("login", "email", "")

func _on_login_pressed() -> void:
	var email = email_input.text.strip_edges()
	var password = password_input.text
	if email == "" or password == "":
		_show_error("Please fill in all fields.")
		return
	login_button.disabled = true
	loading_label.visible = true
	error_label.visible = false
	Firebase.Auth.login_with_email_and_password(email, password)

func _on_login_succeeded(auth_result: Dictionary) -> void:
	var uid = auth_result.get("localid", "")
	GameManager.current_user_id = uid
	var cfg = ConfigFile.new()
	if remember_me.button_pressed:
		Firebase.Auth.save_auth(auth_result)
		cfg.set_value("login", "remember_me", true)
		cfg.set_value("login", "email", email_input.text.strip_edges())
	else:
		cfg.set_value("login", "remember_me", false)
		cfg.set_value("login", "email", "")
	cfg.save(PREFS_PATH)
	var doc = await Firebase.Firestore.collection("users").get_doc(uid)
	var username = doc.get_value("username") if doc else null
	GameManager.current_username = username if username else "Unknown"
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_login_failed(_error_code: int, message: String) -> void:
	login_button.disabled = false
	loading_label.visible = false
	_show_error("Login failed: " + message)

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true
