extends Control

const LOBBY_SCENE = "res://scenes/Lobby.tscn"
const CREATE_SCENE = "res://scenes/CharacterCreate.tscn"
const MAX_SLOTS = 3

@onready var cards: Array = [
	$MarginContainer/VBox/CardsRow/Card0,
	$MarginContainer/VBox/CardsRow/Card1,
	$MarginContainer/VBox/CardsRow/Card2,
]
@onready var card_contents: Array = [
	$MarginContainer/VBox/CardsRow/Card0/CardContent0,
	$MarginContainer/VBox/CardsRow/Card1/CardContent1,
	$MarginContainer/VBox/CardsRow/Card2/CardContent2,
]
@onready var enter_lobby_button: Button = $MarginContainer/VBox/EnterLobbyButton
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmDialog
@onready var delete_input: LineEdit = $DeleteConfirmDialog/VBox/DeleteInput

var _characters: Array = []   # [{id, data}, ...]
var _selected_slot: int = -1
var _deleting_slot: int = -1

const SLICE_COLORS = {
	"North":     Color(0.4, 0.7, 1.0),
	"NorthEast": Color(0.6, 0.9, 0.5),
	"East":      Color(1.0, 0.8, 0.3),
	"SouthEast": Color(1.0, 0.5, 0.2),
	"South":     Color(0.9, 0.3, 0.3),
	"SouthWest": Color(0.7, 0.3, 0.9),
	"West":      Color(0.3, 0.5, 1.0),
	"NorthWest": Color(0.3, 0.9, 0.8),
}

func _ready() -> void:
	enter_lobby_button.pressed.connect(_on_enter_lobby)
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	delete_dialog.canceled.connect(func(): _deleting_slot = -1)
	_load_characters()

func _load_characters() -> void:
	await _load_characters_async()

func _load_characters_async() -> void:
	_characters = []
	for i in MAX_SLOTS:
		_set_card_loading(i)

	var col = Firebase.Firestore.collection("users/%s/characters" % GameManager.current_user_id)

	for i in range(3):
		var doc = await col.get_doc("slot_%d" % i)
		if doc and doc.get_value("name") != null:
			_characters.resize(max(_characters.size(), i + 1))
			_characters[i] = { "id": "slot_%d" % i, "data": _doc_to_dict(doc) }
			_build_filled_card(i, _characters[i]["data"])
		else:
			if _characters.size() <= i:
				_characters.resize(i + 1)
			_characters[i] = null
			_build_empty_card(i)

func _doc_to_dict(doc) -> Dictionary:
	return {
		"name": doc.get_value("name"),
		"branch": doc.get_value("branch"),
		"generation": doc.get_value("generation"),
		"level": doc.get_value("level"),
		"created_at": doc.get_value("created_at"),
		"stats": doc.get_value("stats"),
		"skills": doc.get_value("skills") if doc.get_value("skills") != null else [],
		"weapon": doc.get_value("weapon") if doc.get_value("weapon") != null else {},
	}

func _set_card_loading(slot: int) -> void:
	_clear_card(slot)
	var label = Label.new()
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_contents[slot].add_child(label)

func _build_empty_card(slot: int) -> void:
	_clear_card(slot)
	var btn = Button.new()
	btn.text = "+"
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.flat = false
	btn.pressed.connect(func(): _on_create_pressed(slot))
	card_contents[slot].add_child(btn)
func _build_filled_card(slot: int, data: Dictionary) -> void:
	_clear_card(slot)
	var content = card_contents[slot]

	# Slice color bar
	var color_bar = ColorRect.new()
	color_bar.color = SLICE_COLORS.get(data.get("branch", ""), Color(0.5, 0.5, 0.5))
	color_bar.custom_minimum_size = Vector2(0, 8)
	content.add_child(color_bar)

	# Delete button
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	del_btn.flat = true
	del_btn.pressed.connect(func(): _on_delete_pressed(slot))
	top_row.add_child(del_btn)
	content.add_child(top_row)

	# Name
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(name_label)

	# Slice
	var slice_label = Label.new()
	slice_label.text = data.get("branch", "?") + " Branch"
	slice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slice_label.modulate = SLICE_COLORS.get(data.get("branch", ""), Color.WHITE)
	content.add_child(slice_label)

	# Stats grid
	var stats = data.get("stats", {})
	if stats is Dictionary and not stats.is_empty():
		var sep = HSeparator.new()
		sep.modulate = Color(1, 1, 1, 0.15)
		content.add_child(sep)

		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 2)
		content.add_child(grid)

		var flat_rows = [
			["HP", "hp"], ["Mana", "mana"],
			["STR", "str"], ["AGI", "agi"],
			["INT", "int"], ["SPR", "spr"],
			["DEF", "def"], ["LCK", "lck"], ["SPD", "spd"],
		]
		var pct_rows = [
			["Crit", "crit_chance"], ["CritDMG", "crit_damage"],
			["Prec", "precision"], ["Dodge", "dodge"],
			["Block", "block"], ["Parry", "parry"],
			["Resist", "resistance"],
		]
		for row in flat_rows:
			if not stats.has(row[1]):
				continue
			var k = Label.new()
			k.text = row[0]
			k.add_theme_font_size_override("font_size", 10)
			k.modulate = Color(0.6, 0.6, 0.6)
			grid.add_child(k)
			var v = Label.new()
			v.text = str(stats[row[1]])
			v.add_theme_font_size_override("font_size", 10)
			grid.add_child(v)
		for row in pct_rows:
			if not stats.has(row[1]):
				continue
			var val = stats[row[1]]
			if val == 0.0:
				continue
			var k = Label.new()
			k.text = row[0]
			k.add_theme_font_size_override("font_size", 10)
			k.modulate = Color(0.6, 0.6, 0.6)
			grid.add_child(k)
			var v = Label.new()
			v.text = "%.0f%%" % (val * 100.0)
			v.add_theme_font_size_override("font_size", 10)
			grid.add_child(v)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var level_label = Label.new()
	level_label.text = "Level %d" % data.get("level", 1)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(level_label)

	var gen_label = Label.new()
	gen_label.text = "Generation %d" % data.get("generation", 1)
	gen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gen_label.modulate = Color(0.7, 0.7, 0.7)
	content.add_child(gen_label)

	# Click to select
	var select_btn = Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(func(): _on_slot_selected(slot))
	content.add_child(select_btn)

func _clear_card(slot: int) -> void:
	for child in card_contents[slot].get_children():
		child.queue_free()
	cards[slot].position.y = 0

func _on_slot_selected(slot: int) -> void:
	_selected_slot = slot
	enter_lobby_button.disabled = false
	for i in MAX_SLOTS:
		cards[i].modulate = Color(0.7, 0.7, 0.7)
	cards[slot].modulate = Color.WHITE

func _on_create_pressed(slot: int) -> void:
	GameManager.current_character = { "target_slot": slot }
	get_tree().change_scene_to_file(CREATE_SCENE)

func _on_delete_pressed(slot: int) -> void:
	_deleting_slot = slot
	delete_input.text = ""
	delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if delete_input.text != "DELETE":
		delete_input.placeholder_text = "Must type DELETE exactly"
		_deleting_slot = -1
		return
	if _deleting_slot < 0:
		return
	var slot_id = "slot_%d" % _deleting_slot
	var col = Firebase.Firestore.collection("users/%s/characters" % GameManager.current_user_id)
	var doc = await col.get_doc(slot_id)
	if doc != null:
		await col.delete(doc)
	if _selected_slot == _deleting_slot:
		_selected_slot = -1
		enter_lobby_button.disabled = true
	_characters[_deleting_slot] = null
	_build_empty_card(_deleting_slot)
	_deleting_slot = -1

func _on_enter_lobby() -> void:
	if _selected_slot < 0 or _characters[_selected_slot] == null:
		return
	var char_data = _characters[_selected_slot]
	GameManager.current_character_id = char_data["id"]
	GameManager.current_character = char_data["data"]
	get_tree().change_scene_to_file(LOBBY_SCENE)
