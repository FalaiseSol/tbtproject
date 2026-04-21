extends Control

const LOGIN_SCENE = preload("res://scenes/Login.tscn")
const REGISTER_SCENE = preload("res://scenes/Register.tscn")

@onready var login_button = $CenterContainer/LoginButton
@onready var register_button = $CenterContainer/RegisterButton
@onready var exit_button = $ExitButton
@onready var loading_label: Label = $LoadingLabel

func _ready() -> void:
	login_button.pressed.connect(func(): get_tree().change_scene_to_packed(LOGIN_SCENE))
	register_button.pressed.connect(func(): get_tree().change_scene_to_packed(REGISTER_SCENE))
	exit_button.pressed.connect(func(): get_tree().quit())

	if Firebase.Auth.check_auth_file():
		loading_label.visible = true
		login_button.visible = false
		register_button.visible = false
		Firebase.Auth.token_refresh_succeeded.connect(_on_auto_login, CONNECT_ONE_SHOT)
		Firebase.Auth.login_failed.connect(_on_auto_login_failed, CONNECT_ONE_SHOT)

func _restore_buttons() -> void:
	loading_label.visible = false
	login_button.visible = true
	register_button.visible = true

func _on_auto_login(auth_result: Dictionary) -> void:
	var uid = auth_result.get("localid", "")
	if uid == "":
		_restore_buttons()
		return
	GameManager.current_user_id = uid
	var doc = await Firebase.Firestore.collection("users").get_doc(uid)
	var username = doc.get_value("username") if doc else null
	GameManager.current_username = username if username else "Unknown"
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_auto_login_failed(_code, _message) -> void:
	_restore_buttons()
