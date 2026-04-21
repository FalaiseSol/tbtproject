extends Control

const LOGIN_SCENE = preload("res://scenes/Login.tscn")
const LOBBY_SCENE = preload("res://scenes/Lobby.tscn")
const MAIN_SCENE = preload("res://scenes/Main.tscn")

@onready var username_input = $VBoxContainer/UsernameInput
@onready var email_input = $VBoxContainer/EmailInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var confirm_input = $VBoxContainer/ConfirmInput
@onready var register_button = $VBoxContainer/RegisterButton
@onready var login_link = $VBoxContainer/LoginLink
@onready var back_button = $VBoxContainer/BackButton
@onready var error_label = $VBoxContainer/ErrorLabel

func _ready() -> void:
	error_label.visible = false
	register_button.pressed.connect(_on_register_pressed)
	login_link.pressed.connect(func(): get_tree().change_scene_to_packed(LOGIN_SCENE))
	back_button.pressed.connect(func(): get_tree().change_scene_to_packed(MAIN_SCENE))
	Firebase.Auth.signup_succeeded.connect(_on_signup_succeeded)
	Firebase.Auth.signup_failed.connect(_on_signup_failed)

func _on_register_pressed() -> void:
	var username = _format_name(username_input.text.strip_edges())
	var email = email_input.text.strip_edges()
	var password = password_input.text
	var confirm = confirm_input.text

	if username == "" or email == "" or password == "" or confirm == "":
		_show_error("Please fill in all fields.")
		return
	if username.length() < 3:
		_show_error("Username must be at least 3 characters.")
		return
	if password != confirm:
		_show_error("Passwords do not match.")
		return
	if password.length() < 6:
		_show_error("Password must be at least 6 characters.")
		return

	register_button.disabled = true
	error_label.visible = false
	Firebase.Auth.signup_with_email_and_password(email, password)

func _on_signup_succeeded(auth_result: Dictionary) -> void:
	var uid = auth_result.get("localid", "")
	var username = username_input.text.strip_edges()
	GameManager.current_user_id = uid
	GameManager.current_username = username
	# Save username to Firestore — set_doc is void, fire and forget
	Firebase.Firestore.collection("users").set_doc(uid, {
		"username": username,
		"created_at": Time.get_unix_time_from_system()
	})
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_signup_failed(_error_code: int, message: String) -> void:
	register_button.disabled = false
	_show_error("Registration failed: " + message)

func _format_name(raw: String) -> String:
	var filtered := ""
	for ch in raw:
		if ch.to_upper() != ch.to_lower() or ch == " ":
			filtered += ch
	var formatted := ""
	var capitalize_next := true
	for ch in filtered:
		if ch == " ":
			formatted += ch
			capitalize_next = true
		elif capitalize_next:
			formatted += ch.to_upper()
			capitalize_next = false
		else:
			formatted += ch.to_lower()
	return formatted

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true
