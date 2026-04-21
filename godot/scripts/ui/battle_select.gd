extends Control

@onready var _select_dummy_btn: Button = $MarginContainer/VBox/BattleList/DummyCard/DummyMargin/DummyHBox/SelectDummyButton
@onready var _confirm_btn: Button      = $MarginContainer/VBox/BottomRow/ConfirmButton
@onready var _back_btn: Button         = $MarginContainer/VBox/BottomRow/BackButton
@onready var _ready_panel: PanelContainer = $MarginContainer/VBox/ReadyPanel
@onready var _ready_label: Label          = $MarginContainer/VBox/ReadyPanel/ReadyMargin/ReadyVBox/ReadyLabel
@onready var _ready_list: VBoxContainer   = $MarginContainer/VBox/ReadyPanel/ReadyMargin/ReadyVBox/ReadyList

var _selected_battle: String = ""
var _ready_ref: FirebaseDatabaseReference
var _ready_states: Dictionary = {}   # uid -> bool

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_confirm_btn.pressed.connect(_on_confirm)
	_select_dummy_btn.pressed.connect(func(): _select_battle("dummy"))

	var group_id = GameManager.current_group_id
	if group_id != "":
		_ready_ref = Firebase.Database.get_database_reference("ready/" + group_id)
		_ready_ref.new_data_update.connect(_on_ready_update)
		_ready_ref.patch_data_update.connect(_on_ready_update)
		_ready_ref.delete_data_update.connect(_on_ready_delete)
		_ready_ref.delete("/")

func _select_battle(battle_id: String) -> void:
	_selected_battle = battle_id
	_select_dummy_btn.modulate = Color(0.4, 1.0, 0.5) if battle_id == "dummy" else Color.WHITE
	_confirm_btn.disabled = false

func _on_confirm() -> void:
	if _selected_battle == "":
		return
	var group_id = GameManager.current_group_id
	if group_id == "":
		_launch_battle()
		return
	if _ready_ref == null:
		_launch_battle()
		return
	_confirm_btn.disabled = true
	_ready_panel.visible = true
	_ready_ref.update("/", { GameManager.current_user_id: { "ready": true }, "_battle": _selected_battle })

func _on_ready_update(resource) -> void:
	if resource.data == null or resource.key == "_battle":
		return
	if resource.data is Dictionary:
		for key in resource.data:
			if key == "_battle":
				continue
			var val = resource.data[key]
			_ready_states[key] = val.get("ready", false) if val is Dictionary else bool(val)
	else:
		_ready_states[resource.key] = resource.data.get("ready", false) if resource.data is Dictionary else false
	_refresh_ready_list()
	_check_all_ready()

func _on_ready_delete(resource) -> void:
	_ready_states.erase(resource.key)
	_refresh_ready_list()

func _refresh_ready_list() -> void:
	for child in _ready_list.get_children():
		child.queue_free()
	for member in GameManager.battle_party:
		var uid = member["uid"]
		var uname = member["username"]
		var is_ready = _ready_states.get(uid, false)
		var lbl = Label.new()
		lbl.text = "%s  —  %s" % [uname, "Ready" if is_ready else "..."]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.4, 1.0, 0.5) if is_ready else Color(0.7, 0.7, 0.7)
		_ready_list.add_child(lbl)
	var count = _ready_states.values().filter(func(v): return v == true).size()
	_ready_label.text = "Waiting for players...  (%d / %d)" % [count, GameManager.battle_party.size()]

func _check_all_ready() -> void:
	if GameManager.battle_party.is_empty():
		return
	for member in GameManager.battle_party:
		if not _ready_states.get(member["uid"], false):
			return
	_launch_battle()

func _launch_battle() -> void:
	if _ready_ref:
		_ready_ref.delete("/")
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func _on_back() -> void:
	if _ready_ref:
		_ready_ref.delete(GameManager.current_user_id)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
