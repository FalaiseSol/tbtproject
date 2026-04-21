extends Control

@onready var player_list: ItemList = $MarginContainer/VBoxMain/HSplitContainer/LeftPanel/PlayerList
@onready var welcome_label: Label = $MarginContainer/VBoxMain/HSplitContainer/LeftPanel/WelcomeLabel
@onready var start_solo_button: Button = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupListView/StartSoloButton
@onready var logout_button: Button = $MarginContainer/VBoxMain/HSplitContainer/LeftPanel/LogoutButton
@onready var loading_label: Label = $MarginContainer/VBoxMain/HSplitContainer/LeftPanel/LoadingLabel

@onready var group_list_view: VBoxContainer = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupListView
@onready var group_list: ItemList = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupListView/GroupList
@onready var create_group_button: Button = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupListView/CreateGroupButton

@onready var group_detail_view: VBoxContainer = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView
@onready var back_button: Button = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView/TopBar/BackButton
@onready var group_name_edit: LineEdit = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView/TopBar/GroupNameEdit
@onready var member_list: ItemList = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView/MemberList
@onready var open_toggle_button: Button = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView/OpenToggleButton
@onready var start_button: Button = $MarginContainer/VBoxMain/HSplitContainer/RightPanel/GroupDetailView/StartButton

@onready var context_menu: PopupMenu = $ContextMenu
@onready var invite_popup: AcceptDialog = $InvitePopup
@onready var log_text: RichTextLabel = $MarginContainer/VBoxMain/EventLogPanel/VBox/ScrollContainer/LogText

var _lobby_ref: FirebaseDatabaseReference
var _groups_ref: FirebaseDatabaseReference
var _invites_ref: FirebaseDatabaseReference

const HEARTBEAT_INTERVAL = 15.0
const HEARTBEAT_TIMEOUT  = 45.0

var _online_players: Dictionary = {}   # uid -> { username, heartbeat }
var _heartbeat_timer: float = 0.0
var _prune_timer: float = 0.0
var _groups: Dictionary = {}           # groupId -> { host, name, members: {uid: username} }

var _context_target_uid: String = ""
var _context_target_name: String = ""
var _viewing_group_id: String = ""
var _my_group_id: String = ""
var _pending_invite: Dictionary = {}   # { group_id, from_name }

func _ready() -> void:
	if not GameManager.has_character():
		get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
		return
	welcome_label.text = "Welcome, %s" % GameManager.current_username
	start_solo_button.pressed.connect(_on_start_pressed)
	_refresh_solo_button()
	logout_button.pressed.connect(_on_logout_pressed)
	logout_button.text = "⏻  Logout"
	var logout_normal = StyleBoxFlat.new()
	logout_normal.bg_color = Color(0.55, 0.1, 0.1, 1.0)
	logout_normal.corner_radius_top_left = 4
	logout_normal.corner_radius_top_right = 4
	logout_normal.corner_radius_bottom_left = 4
	logout_normal.corner_radius_bottom_right = 4
	var logout_hover = StyleBoxFlat.new()
	logout_hover.bg_color = Color(0.72, 0.15, 0.15, 1.0)
	logout_hover.corner_radius_top_left = 4
	logout_hover.corner_radius_top_right = 4
	logout_hover.corner_radius_bottom_left = 4
	logout_hover.corner_radius_bottom_right = 4
	var logout_pressed = StyleBoxFlat.new()
	logout_pressed.bg_color = Color(0.4, 0.07, 0.07, 1.0)
	logout_pressed.corner_radius_top_left = 4
	logout_pressed.corner_radius_top_right = 4
	logout_pressed.corner_radius_bottom_left = 4
	logout_pressed.corner_radius_bottom_right = 4
	logout_button.add_theme_stylebox_override("normal", logout_normal)
	logout_button.add_theme_stylebox_override("hover", logout_hover)
	logout_button.add_theme_stylebox_override("pressed", logout_pressed)
	create_group_button.pressed.connect(_on_create_group_pressed)
	back_button.pressed.connect(_show_group_list)
	group_name_edit.text_submitted.connect(_on_group_name_submitted)
	group_list.item_activated.connect(_on_group_item_activated)
	group_list.item_clicked.connect(_on_group_item_clicked)
	open_toggle_button.pressed.connect(_on_open_toggle_pressed)
	player_list.item_clicked.connect(_on_player_item_clicked)
	member_list.item_clicked.connect(_on_member_item_clicked)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	invite_popup.confirmed.connect(_on_invite_accepted)
	invite_popup.canceled.connect(_on_invite_declined)
	start_button.pressed.connect(_on_start_pressed)

	_lobby_ref = Firebase.Database.get_database_reference("lobby")
	_lobby_ref.new_data_update.connect(_on_lobby_update)
	_lobby_ref.patch_data_update.connect(_on_lobby_patch)
	_lobby_ref.delete_data_update.connect(_on_lobby_delete)

	_groups_ref = Firebase.Database.get_database_reference("groups")
	_groups_ref.new_data_update.connect(_on_groups_update)
	_groups_ref.patch_data_update.connect(_on_groups_patch)
	_groups_ref.delete_data_update.connect(_on_groups_delete)

	_invites_ref = Firebase.Database.get_database_reference("invites/" + GameManager.current_user_id)
	_invites_ref.new_data_update.connect(_on_invite_received)
	_invites_ref.patch_data_update.connect(_on_invite_received)

	_invites_ref.delete("/")
	_send_heartbeat()
	_log("Joined lobby as %s." % GameManager.current_username)
	_cleanup_stale_groups()

func _process(delta: float) -> void:
	_heartbeat_timer += delta
	_prune_timer += delta
	if _heartbeat_timer >= HEARTBEAT_INTERVAL:
		_heartbeat_timer = 0.0
		_send_heartbeat()
	if _prune_timer >= HEARTBEAT_TIMEOUT:
		_prune_timer = 0.0
		_prune_stale_players()

func _send_heartbeat() -> void:
	var now = Time.get_unix_time_from_system()
	_lobby_ref.update("/", { GameManager.current_user_id: { "username": GameManager.current_username, "heartbeat": now } })

func _prune_stale_players() -> void:
	var now = Time.get_unix_time_from_system()
	for uid in _online_players.keys():
		if uid == GameManager.current_user_id:
			continue
		var hb = _online_players[uid].get("heartbeat", 0)
		if now - hb > HEARTBEAT_TIMEOUT:
			_lobby_ref.delete(uid)

# ── Logging ──────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	var time = Time.get_time_string_from_system()
	log_text.append_text("[%s] %s\n" % [time, msg])

# ── Lobby (players online) ────────────────────────────────────────────────────

func _on_lobby_update(resource: FirebaseResource) -> void:
	if resource.data is Dictionary:
		_online_players[resource.key] = resource.data
	elif resource.data != null:
		_online_players[resource.key] = { "username": str(resource.data), "heartbeat": 0 }
	_refresh_player_list()

func _on_lobby_patch(resource: FirebaseResource) -> void:
	if resource.data is Dictionary:
		for key in resource.data.keys():
			if resource.data[key] == null:
				_online_players.erase(key)
			elif resource.data[key] is Dictionary:
				if not _online_players.has(key):
					_online_players[key] = {}
				_online_players[key].merge(resource.data[key], true)
			else:
				_online_players[key] = { "username": str(resource.data[key]), "heartbeat": 0 }
	_refresh_player_list()

func _on_lobby_delete(resource: FirebaseResource) -> void:
	_online_players.erase(resource.key)
	_refresh_player_list()

func _refresh_player_list() -> void:
	player_list.clear()
	for uid in _online_players.keys():
		var uname = _online_players[uid].get("username", "Unknown")
		player_list.add_item(uname)
		player_list.set_item_metadata(player_list.item_count - 1, uid)

# ── Groups ────────────────────────────────────────────────────────────────────

func _on_groups_update(resource: FirebaseResource) -> void:
	var group_id = resource.key
	if resource.data == null:
		_handle_group_deleted(group_id)
		return
	if resource.data is Dictionary:
		if not _groups.has(group_id):
			_groups[group_id] = { "host": "", "name": "", "members": {}, "open": true }
			_log("Group \"%s\" was created." % resource.data.get("name", group_id))
		_merge_group(group_id, resource.data)
	_refresh_group_list()
	if _viewing_group_id == group_id:
		_refresh_member_list()

func _on_groups_patch(resource: FirebaseResource) -> void:
	var group_id = resource.key
	if resource.data is Dictionary:
		if not _groups.has(group_id):
			_groups[group_id] = { "host": "", "name": "", "members": {}, "open": true }
		_merge_group(group_id, resource.data)
	_refresh_group_list()
	if _viewing_group_id == group_id:
		_refresh_member_list()

func _on_groups_delete(resource: FirebaseResource) -> void:
	_handle_group_deleted(resource.key)

func _merge_group(group_id: String, data: Dictionary) -> void:
	var g = _groups[group_id]
	if data.has("host"):
		g["host"] = data["host"]
	if data.has("open"):
		g["open"] = data["open"]
	if data.has("name"):
		var old_name = g["name"]
		g["name"] = data["name"]
		if old_name != "" and old_name != data["name"]:
			_log("Group renamed to \"%s\"." % data["name"])
	if data.has("members") and data["members"] is Dictionary:
		for uid in data["members"].keys():
			var val = data["members"][uid]
			if val == null:
				if g["members"].has(uid):
					_log("%s left the group." % g["members"][uid])
					g["members"].erase(uid)
			else:
				if not g["members"].has(uid):
					_log("%s joined the group." % val)
				g["members"][uid] = val
	if g["members"].is_empty():
		_groups_ref.delete(group_id)

func _handle_group_deleted(group_id: String) -> void:
	if not _groups.has(group_id):
		return
	var group_name = _groups[group_id].get("name", group_id)
	_log("Group \"%s\" was disbanded." % group_name)
	_groups.erase(group_id)
	if _my_group_id == group_id:
		_my_group_id = ""
		_refresh_solo_button()
	if _viewing_group_id == group_id:
		_viewing_group_id = ""
		_show_group_list()
	_refresh_group_list()

func _refresh_group_list() -> void:
	group_list.clear()
	for gid in _groups.keys():
		var g = _groups[gid]
		var member_count = g["members"].size()
		var label = "%s (%d/4)" % [g.get("name", "..."), member_count]
		group_list.add_item(label)
		group_list.set_item_metadata(group_list.item_count - 1, gid)

func _refresh_member_list() -> void:
	member_list.clear()
	if not _groups.has(_viewing_group_id):
		return
	var g = _groups[_viewing_group_id]
	for uid in g["members"].keys():
		var uname = g["members"][uid]
		var display = uname
		if uid == g["host"]:
			display += " (host)"
		member_list.add_item(display)
		member_list.set_item_metadata(member_list.item_count - 1, uid)

# ── Stale cleanup ─────────────────────────────────────────────────────────────

func _cleanup_stale_groups() -> void:
	var stale_groups: Array = []
	await get_tree().create_timer(1.0).timeout
	for gid in _groups.keys():
		if gid == _my_group_id:
			continue
		var g = _groups[gid]
		if g.get("host", "") == GameManager.current_user_id:
			stale_groups.append(gid)
	for gid in stale_groups:
		_groups_ref.delete(gid)
		_log("Cleaned up stale group from previous session.")

# ── Group actions ─────────────────────────────────────────────────────────────

func _on_create_group_pressed() -> void:
	if _my_group_id != "":
		_log("You are already in a group.")
		return
	var group_id = "g_" + GameManager.current_user_id.substr(0, 8) + "_" + str(Time.get_ticks_msec())
	var group_data = {
		"host": GameManager.current_user_id,
		"name": GameManager.current_username + "'s group",
		"members": { GameManager.current_user_id: GameManager.current_username },
		"open": true
	}
	_groups_ref.update(group_id, group_data)
	_my_group_id = group_id
	_refresh_solo_button()
	_log("You created a group.")

func _on_group_item_activated(index: int) -> void:
	var gid = group_list.get_item_metadata(index)
	_viewing_group_id = gid
	_show_group_detail(gid)

func _show_group_list() -> void:
	group_detail_view.visible = false
	group_list_view.visible = true
	_viewing_group_id = ""

func _show_group_detail(group_id: String) -> void:
	if not _groups.has(group_id):
		return
	group_list_view.visible = false
	group_detail_view.visible = true
	var g = _groups[group_id]
	group_name_edit.text = g.get("name", "")
	var is_host = g.get("host", "") == GameManager.current_user_id
	group_name_edit.editable = is_host
	start_button.disabled = not is_host
	open_toggle_button.visible = is_host
	open_toggle_button.text = "Open: ON" if g.get("open", true) else "Open: OFF"
	_refresh_member_list()

func _on_group_name_submitted(new_name: String) -> void:
	if _viewing_group_id == "":
		return
	if not _groups.has(_viewing_group_id):
		return
	if _groups[_viewing_group_id].get("host", "") != GameManager.current_user_id:
		return
	_groups_ref.update(_viewing_group_id, { "name": new_name })
	_log("You renamed the group to \"%s\"." % new_name)

func _on_open_toggle_pressed() -> void:
	if _viewing_group_id == "" or not _groups.has(_viewing_group_id):
		return
	var g = _groups[_viewing_group_id]
	if g.get("host", "") != GameManager.current_user_id:
		return
	var new_open = not g.get("open", true)
	_groups_ref.update(_viewing_group_id, { "open": new_open })
	g["open"] = new_open
	open_toggle_button.text = "Open: ON" if new_open else "Open: OFF"
	_log("Group is now %s." % ("open" if new_open else "closed"))

func _on_group_item_clicked(index: int, _pos: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_RIGHT:
		return
	var gid = group_list.get_item_metadata(index)
	if not _groups.has(gid):
		return
	var g = _groups[gid]
	if g.get("host", "") == GameManager.current_user_id:
		return
	if not g.get("open", true):
		_log("That group is closed.")
		return
	if _my_group_id != "":
		_log("You are already in a group.")
		return
	if g.get("members", {}).size() >= 4:
		_log("That group is full.")
		return
	if g.get("members", {}).has(GameManager.current_user_id):
		_log("You are already in that group.")
		return
	_groups_ref.update(gid + "/members", { GameManager.current_user_id: GameManager.current_username })
	_my_group_id = gid
	_refresh_solo_button()
	_log("You joined \"%s\"." % g.get("name", gid))

# ── Context menu ──────────────────────────────────────────────────────────────

func _on_player_item_clicked(index: int, _pos: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_RIGHT:
		return
	var uid = player_list.get_item_metadata(index)
	if uid == GameManager.current_user_id:
		if _my_group_id == "":
			return
		_show_context_menu_for(uid, GameManager.current_username, true)
		return
	var uname = _online_players.get(uid, {}).get("username", "Unknown")
	_show_context_menu_for(uid, uname, false)

func _on_member_item_clicked(index: int, _pos: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_RIGHT:
		return
	var uid = member_list.get_item_metadata(index)
	var is_self = uid == GameManager.current_user_id
	var uname = ""
	if _groups.has(_viewing_group_id):
		uname = str(_groups[_viewing_group_id]["members"].get(uid, "Unknown"))
	_show_context_menu_for(uid, uname, is_self)

func _show_context_menu_for(uid: String, uname: String, is_self: bool) -> void:
	_context_target_uid = uid
	_context_target_name = uname
	context_menu.clear()
	if is_self:
		if _my_group_id != "":
			context_menu.add_item("Leave Group", 1)
	else:
		if _my_group_id != "":
			context_menu.add_item("Invite", 0)
	context_menu.add_item("Inspect", 2)
	context_menu.popup(Rect2i(get_global_mouse_position(), Vector2i(140, 40)))

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 0:
		_send_invite(_context_target_uid, _context_target_name)
	elif id == 1:
		_leave_group()
	elif id == 2:
		_inspect_player(_context_target_uid, _context_target_name)

func _inspect_player(uid: String, uname: String) -> void:
	# Try to find their active character across slots
	var char_data = null
	for slot in ["slot_0", "slot_1", "slot_2"]:
		var d = await Firebase.Firestore.collection("users/%s/characters" % uid).get_doc(slot)
		if d and d.get_value("name") != null:
			char_data = d
			break
	if char_data == null:
		_log("%s has no character." % uname)
		return
	var char_name = char_data.get_value("name")
	var slice = char_data.get_value("branch")
	var level = char_data.get_value("level")
	var generation = char_data.get_value("generation")
	var stats = char_data.get_value("stats")
	var info = "[b]%s[/b] — %s Branch | Lv.%d | Gen.%d" % [char_name, slice, level, generation]
	if stats is Dictionary:
		info += "\nHP:%d  MP:%d  STR:%d  AGI:%d  INT:%d  SPR:%d  DEF:%d  LCK:%d  SPD:%d" % [
			stats.get("hp", 0), stats.get("mana", 0),
			stats.get("str", 0), stats.get("agi", 0), stats.get("int", 0),
			stats.get("spr", 0), stats.get("def", 0), stats.get("lck", 0), stats.get("spd", 0)
		]
		info += "\nCrit:%.1f%%  CritDmg:%.1f%%  Prec:%.1f%%  Dodge:%.1f%%  Block:%.1f%%  Parry:%.1f%%  Res:%.1f%%  HPReg:%d  MPReg:%d" % [
			stats.get("crit_chance", 0.0) * 100, stats.get("crit_damage", 0.0) * 100,
			stats.get("precision", 0.0) * 100, stats.get("dodge", 0.0) * 100,
			stats.get("block", 0.0) * 100, stats.get("parry", 0.0) * 100,
			stats.get("resistance", 0.0) * 100,
			stats.get("hp_regen", 0), stats.get("mana_regen", 0)
		]
	info += "\nTrinkets: None"
	_log("Inspecting %s: %s" % [uname, info])

# ── Invite ────────────────────────────────────────────────────────────────────

func _send_invite(target_uid: String, target_name: String) -> void:
	if _my_group_id == "":
		_log("You must be in a group to invite someone.")
		return
	var g = _groups.get(_my_group_id, {})
	if g.get("members", {}).size() >= 4:
		_log("Your group is full (4/4).")
		return
	if g.get("members", {}).has(target_uid):
		_log("%s is already in your group." % target_name)
		return
	var invite_data = {
		"from_name": GameManager.current_username,
		"group_id": _my_group_id
	}
	var target_invites_ref = Firebase.Database.get_database_reference("invites/" + target_uid)
	target_invites_ref.update("/", { _my_group_id: invite_data })
	_log("Invite sent to %s." % target_name)

func _on_invite_received(resource: FirebaseResource) -> void:
	if resource.data == null or not resource.data is Dictionary:
		return
	for group_id in resource.data.keys():
		var invite = resource.data[group_id]
		if invite == null:
			continue
		_pending_invite = { "group_id": group_id, "from_name": invite.get("from_name", "Someone") }
		_log("%s invited you to their group." % _pending_invite["from_name"])
		invite_popup.dialog_text = "%s invited you to their group. Accept?" % _pending_invite["from_name"]
		invite_popup.popup_centered()
		return

func _on_invite_accepted() -> void:
	if _pending_invite.is_empty():
		return
	var group_id = _pending_invite["group_id"]
	if not _groups.has(group_id):
		_log("That group no longer exists.")
		_clear_invite(group_id)
		return
	if _groups[group_id]["members"].size() >= 4:
		_log("That group is now full.")
		_clear_invite(group_id)
		return
	_groups_ref.update(group_id + "/members", { GameManager.current_user_id: GameManager.current_username })
	_my_group_id = group_id
	_refresh_solo_button()
	_log("You joined %s's group." % _pending_invite["from_name"])
	_clear_invite(group_id)

func _on_invite_declined() -> void:
	if _pending_invite.is_empty():
		return
	_log("You declined the invite from %s." % _pending_invite["from_name"])
	_clear_invite(_pending_invite["group_id"])

func _clear_invite(group_id: String) -> void:
	_invites_ref.delete(GameManager.current_user_id + "/" + group_id)
	_pending_invite = {}

# ── Leave group ───────────────────────────────────────────────────────────────

func _leave_group() -> void:
	if _my_group_id == "":
		return
	var g = _groups.get(_my_group_id, {})
	var is_host = g.get("host", "") == GameManager.current_user_id
	if is_host:
		_groups_ref.delete(_my_group_id)
		_log("You disbanded your group.")
	else:
		_groups_ref.delete(_my_group_id + "/members/" + GameManager.current_user_id)
		_log("You left the group.")
	if _viewing_group_id == _my_group_id:
		_show_group_list()
	_my_group_id = ""
	_refresh_solo_button()

# ── Start / Battle Select ─────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if _my_group_id != "":
		var g = _groups.get(_my_group_id, {})
		if g.get("host", "") != GameManager.current_user_id:
			_log("Only the group host can start the battle.")
			return
	GameManager.is_host = true
	GameManager.current_group_id = _my_group_id
	GameManager.battle_party = []
	if _my_group_id != "" and _groups.has(_my_group_id):
		var g = _groups[_my_group_id]
		for uid in g["members"].keys():
			GameManager.battle_party.append({
				"uid": uid,
				"username": g["members"][uid],
				"character": {}
			})
	else:
		GameManager.battle_party = [{
			"uid": GameManager.current_user_id,
			"username": GameManager.current_username,
			"character": GameManager.current_character.duplicate(true)
		}]
	get_tree().change_scene_to_file("res://scenes/BattleSelect.tscn")

# ── Solo / group start toggle ─────────────────────────────────────────────────

func _refresh_solo_button() -> void:
	var in_group = _my_group_id != ""
	start_solo_button.visible = not in_group

# ── Logout ────────────────────────────────────────────────────────────────────

func _on_logout_pressed() -> void:
	logout_button.disabled = true
	loading_label.visible = true
	if _my_group_id != "":
		_leave_group()
	_invites_ref.delete("/")
	_lobby_ref.delete(GameManager.current_user_id)
	_lobby_ref.new_data_update.disconnect(_on_lobby_update)
	_lobby_ref.patch_data_update.disconnect(_on_lobby_patch)
	_lobby_ref.delete_data_update.disconnect(_on_lobby_delete)
	_groups_ref.new_data_update.disconnect(_on_groups_update)
	_groups_ref.patch_data_update.disconnect(_on_groups_patch)
	_groups_ref.delete_data_update.disconnect(_on_groups_delete)
	await get_tree().create_timer(0.3).timeout
	GameManager.logout()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
