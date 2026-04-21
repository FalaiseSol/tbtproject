extends Node

var current_user_id: String = ""
var current_username: String = ""
var current_character_id: String = ""
var current_character: Dictionary = {}
var battle_party: Array = []   # Array of { uid, username, character }
var is_host: bool = false
var current_group_id: String = ""

func is_logged_in() -> bool:
	return current_user_id != ""

func has_character() -> bool:
	return current_character_id != ""

func logout() -> void:
	current_user_id = ""
	current_username = ""
	current_character_id = ""
	current_character = {}
	battle_party = []
	is_host = false
	current_group_id = ""
	Firebase.Auth.logout()
