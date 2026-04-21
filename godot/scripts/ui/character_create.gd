extends Control

const SELECT_SCENE = "res://scenes/CharacterSelect.tscn"

@onready var name_input: LineEdit = $MarginContainer/VBox/TopBar/NameBlock/NameRow/NameInput
@onready var weapon_cards_row: HBoxContainer = $MarginContainer/VBox/TopBar/WeaponBlock/WeaponMargin/WeaponVBox/WeaponCardsRow
@onready var weapon_info_label: Label = $MarginContainer/VBox/TopBar/WeaponBlock/WeaponMargin/WeaponVBox/WeaponInfoLabel
@onready var slice_row: HBoxContainer = $MarginContainer/VBox/ContentRow/LeftCol/SliceScroll/SliceRow
@onready var branch_detail_panel: PanelContainer = $MarginContainer/VBox/ContentRow/LeftCol/BranchDetailPanel
@onready var branch_title: Label = $MarginContainer/VBox/ContentRow/LeftCol/BranchDetailPanel/BranchDetailScroll/BranchDetailMargin/BranchDetailVBox/BranchTitle
@onready var l1_cards_row: HBoxContainer = $MarginContainer/VBox/ContentRow/LeftCol/BranchDetailPanel/BranchDetailScroll/BranchDetailMargin/BranchDetailVBox/L1CardsRow
@onready var levels_vbox: VBoxContainer = $MarginContainer/VBox/ContentRow/LeftCol/BranchDetailPanel/BranchDetailScroll/BranchDetailMargin/BranchDetailVBox/LevelsVBox
@onready var soul_info: Label = $MarginContainer/VBox/ContentRow/SoulColumn/SoulSection/SoulMargin/SoulVBox/SoulInfo
@onready var points_label: Label = $MarginContainer/VBox/ContentRow/SoulColumn/BaseStatsSection/StatsMargin/BaseStatsVBox/StatsHeaderRow/PointsLabel
@onready var stats_grid: VBoxContainer = $MarginContainer/VBox/ContentRow/SoulColumn/BaseStatsSection/StatsMargin/BaseStatsVBox/StatsScroll/StatsGrid
@onready var error_label: Label = $MarginContainer/VBox/BottomBar/ErrorLabel
@onready var confirm_button: Button = $MarginContainer/VBox/BottomBar/ConfirmButton
@onready var cancel_button: Button = $MarginContainer/VBox/BottomBar/CancelButton

var _selected_branch: String = ""
var _slice_cards: Array = []
var _target_slot: int = 0
var _current_stats: Dictionary = {}
var _selected_l1: Dictionary = {}
var _l1_cards: Array = []
var _stat_points_remaining: int = 3
var _stat_spent: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _selected_weapon: Dictionary = {}
var _weapon_cards: Array = []

const SLICES = [
	{ "name": "North",     "color": Color(0.4, 0.7, 1.0) },
	{ "name": "NorthEast", "color": Color(0.6, 0.9, 0.5) },
	{ "name": "East",      "color": Color(1.0, 0.8, 0.3) },
	{ "name": "SouthEast", "color": Color(1.0, 0.5, 0.2) },
	{ "name": "South",     "color": Color(0.9, 0.3, 0.3) },
	{ "name": "SouthWest", "color": Color(0.7, 0.3, 0.9) },
	{ "name": "West",      "color": Color(0.3, 0.5, 1.0) },
	{ "name": "NorthWest", "color": Color(0.3, 0.9, 0.8) },
]

const ELEMENT_COLORS = {
	"fire":    Color(1.0, 0.40, 0.10),
	"water":   Color(0.30, 0.60, 1.0),
	"plant":   Color(0.30, 0.80, 0.30),
	"thunder": Color(1.0, 0.90, 0.10),
	"metal":   Color(0.70, 0.82, 0.90),
	"stone":   Color(0.65, 0.52, 0.35),
	"light":   Color(1.0, 0.97, 0.55),
	"shadow":  Color(0.55, 0.20, 0.75),
	"void":     Color(0.30, 0.10, 0.55),
	"chaos":    Color(0.92, 0.10, 0.50),
	"physical": Color(0.75, 0.65, 0.55),
}

const DEFAULT_STATS = {
	"hp": 100, "mana": 50,
	"str": 10, "agi": 10, "int": 10,
	"spr": 10, "def": 10, "lck": 10, "spd": 10,
	"crit_chance": 0.05, "crit_damage": 1.0,
	"precision": 1.0, "dodge": 0.02,
	"block": 0.05, "parry": 0.05,
	"resistance": 0.10,
	"hp_regen": 0, "mana_regen": 7,
}

# How much each stat increases per point spent. Flat = integer, pct = float.
const STAT_COST = {
	"hp": 10, "mana": 10,
	"str": 1, "agi": 1, "int": 1, "spr": 1, "def": 1, "lck": 1, "spd": 1,
	"crit_chance": 0.01, "crit_damage": 0.10,
	"precision": 0.05, "dodge": 0.01,
	"block": 0.02, "parry": 0.01,
	"resistance": 0.02,
	"hp_regen": 1, "mana_regen": 3,
}

# Display order and labels for the stats grid
const STAT_ROWS = [
	["hp", "HP"], ["mana", "Mana"],
	["str", "STR"], ["agi", "AGI"],
	["int", "INT"], ["spr", "SPR"],
	["def", "DEF"], ["lck", "LCK"],
	["spd", "SPD"], ["", ""],
	["precision", "Precision"], ["dodge", "Dodge"],
	["block", "Block"], ["parry", "Parry"],
	["crit_chance", "Crit"], ["crit_damage", "Crit DMG"],
	["resistance", "Resistance"],
	["hp_regen", "HP Regen"], ["mana_regen", "MP Regen"],
]

func _ready() -> void:
	_target_slot = GameManager.current_character.get("target_slot", 0)
	GameManager.current_character = {}

	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(func(): get_tree().change_scene_to_file(SELECT_SCENE))

	name_input.text_changed.connect(_on_name_changed)

	soul_info.text = "Soul inheritance requires your\nprevious character to have\nreached level 3."
	soul_info.modulate = Color(0.45, 0.45, 0.45, 1.0)

	_current_stats = DEFAULT_STATS.duplicate()
	for key in DEFAULT_STATS:
		_stat_spent[key] = 0
	_build_stats_grid()
	_refresh_points_label()
	_build_weapon_cards()

	for slice_data in SLICES:
		var card = preload("res://scripts/ui/slice_card.gd").new(
			slice_data["name"], slice_data["color"], ""
		)
		card.slice_selected.connect(_on_branch_selected)
		slice_row.add_child(card)
		_slice_cards.append(card)

# ── Name formatting ───────────────────────────────────────────────────────────

func _on_name_changed(new_text: String) -> void:
	var filtered := ""
	for ch in new_text:
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
	if formatted != new_text:
		var caret = name_input.caret_column
		name_input.text = formatted
		name_input.caret_column = mini(caret, formatted.length())

# ── Weapon selection ───────────────────────────────────────────────────────────

func _build_weapon_cards() -> void:
	var branch_data = preload("res://scripts/game/branch_data.gd")
	var main_hand_weapons: Array = []
	for w in branch_data.WEAPONS:
		if w["slot"] == "main_hand":
			main_hand_weapons.append(w)

	for w in main_hand_weapons:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		margin.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = w["name"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var stats_parts: Array = []
		for skey in w.get("stats", {}):
			var sv = w["stats"][skey]
			stats_parts.append("+%d %s" % [sv, skey.to_upper()])
		if stats_parts.size() > 0:
			var stats_lbl = Label.new()
			stats_lbl.text = "  /  ".join(stats_parts)
			stats_lbl.add_theme_font_size_override("font_size", 11)
			stats_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
			stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(stats_lbl)

		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_select_weapon(w, card)
		)
		card.set_meta("weapon_id", w["id"])
		weapon_cards_row.add_child(card)
		_weapon_cards.append(card)

func _select_weapon(weapon: Dictionary, selected_card: PanelContainer) -> void:
	_selected_weapon = weapon
	for card in _weapon_cards:
		var is_sel = card.get_meta("weapon_id") == weapon["id"]
		card.modulate = Color.WHITE if is_sel else Color(0.65, 0.65, 0.65, 1.0)
	var desc = weapon.get("notes", "")
	var parts: Array = []
	for skey in weapon.get("stats", {}):
		var sv = weapon["stats"][skey]
		parts.append("+%d %s" % [sv, skey.to_upper()])
	weapon_info_label.text = (("  /  ".join(parts) + "  —  ") if parts.size() > 0 else "") + desc
	weapon_info_label.modulate = Color(0.85, 0.85, 0.85, 1.0)

# ── Stats grid ────────────────────────────────────────────────────────────────

func _build_stats_grid() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	_stat_value_labels.clear()

	for row in STAT_ROWS:
		var key: String = row[0]
		var label_text: String = row[1]

		if key == "":
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 3)
			stats_grid.add_child(spacer)
			continue

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		stats_grid.add_child(hbox)

		# Fixed-width name label so all rows align regardless of text length
		var name_lbl = Label.new()
		name_lbl.text = label_text
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.modulate = Color(0.80, 0.80, 0.80, 1.0)
		name_lbl.custom_minimum_size = Vector2(78, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hbox.add_child(name_lbl)

		# Spacer pushes buttons right
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.flat = false
		minus_btn.custom_minimum_size = Vector2(26, 22)
		minus_btn.add_theme_font_size_override("font_size", 14)
		minus_btn.modulate = Color(1.0, 0.6, 0.6, 1.0)
		minus_btn.pressed.connect(_on_stat_minus.bind(key))
		hbox.add_child(minus_btn)

		var val_lbl = Label.new()
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.custom_minimum_size = Vector2(58, 0)
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(val_lbl)
		_stat_value_labels[key] = val_lbl

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.flat = false
		plus_btn.custom_minimum_size = Vector2(26, 22)
		plus_btn.add_theme_font_size_override("font_size", 14)
		plus_btn.modulate = Color(0.6, 1.0, 0.7, 1.0)
		plus_btn.pressed.connect(_on_stat_plus.bind(key))
		hbox.add_child(plus_btn)

		var right_pad = Control.new()
		right_pad.custom_minimum_size = Vector2(14, 0)
		hbox.add_child(right_pad)

		_refresh_stat_label(key)

func _refresh_stat_label(key: String) -> void:
	if not _stat_value_labels.has(key):
		return
	var val = _current_stats[key]
	var spent = _stat_spent[key]
	var lbl = _stat_value_labels[key]
	var text: String
	if val is float:
		text = "%.0f%%" % (val * 100.0)
	else:
		text = str(val)
	if spent > 0:
		lbl.modulate = Color(0.4, 1.0, 0.5, 1.0)
	else:
		lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lbl.text = text

func _refresh_points_label() -> void:
	if _stat_points_remaining > 0:
		points_label.text = "%d pts left" % _stat_points_remaining
		points_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
	else:
		points_label.text = "Done"
		points_label.modulate = Color(0.4, 1.0, 0.5, 1.0)

func _on_stat_plus(key: String) -> void:
	if _stat_points_remaining <= 0:
		return
	var gain = STAT_COST[key]
	_current_stats[key] += gain
	_stat_spent[key] += 1
	_stat_points_remaining -= 1
	_refresh_stat_label(key)
	_refresh_points_label()

func _on_stat_minus(key: String) -> void:
	if _stat_spent[key] <= 0:
		return
	var gain = STAT_COST[key]
	_current_stats[key] -= gain
	_stat_spent[key] -= 1
	_stat_points_remaining += 1
	_refresh_stat_label(key)
	_refresh_points_label()

# ── Branch selection ──────────────────────────────────────────────────────────

func _on_branch_selected(p_name: String) -> void:
	_selected_branch = p_name
	_selected_l1 = {}
	# Reset to default + any already-spent stat points
	_recompute_stats_from_spent()
	for card in _slice_cards:
		if card.slice_name != p_name:
			card.deselect()
	_show_branch_detail(p_name)

func _show_branch_detail(branch_name: String) -> void:
	var branch_data = preload("res://scripts/game/branch_data.gd")
	if not branch_data.BRANCHES.has(branch_name):
		return
	var levels = branch_data.BRANCHES[branch_name]
	branch_title.text = branch_name + " Branch"
	_build_l1_cards(levels[0])
	_build_levels_cards(levels)
	branch_detail_panel.visible = true

# ── Stat recompute (base + spent + passive) ───────────────────────────────────

func _recompute_stats_from_spent() -> void:
	_current_stats = DEFAULT_STATS.duplicate()
	for key in _stat_spent:
		if _stat_spent[key] > 0:
			_current_stats[key] += STAT_COST[key] * _stat_spent[key]
	if not _selected_l1.is_empty() and _selected_l1.get("type") == "passive":
		_apply_passive_stats(_selected_l1)
	for key in _stat_value_labels:
		_refresh_stat_label(key)

# ── L1 skill cards ────────────────────────────────────────────────────────────

func _build_l1_cards(l1_nodes: Array) -> void:
	for c in _l1_cards:
		c.queue_free()
	_l1_cards.clear()
	for node_data in l1_nodes:
		var card = _make_skill_card(node_data)
		l1_cards_row.add_child(card)
		_l1_cards.append(card)

func _make_skill_card(node_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var circle = preload("res://scripts/ui/skill_circle.gd").new()
	vbox.add_child(circle)

	var elem: String = node_data.get("element", "")
	if elem != "" and ELEMENT_COLORS.has(elem):
		var elem_row = HBoxContainer.new()
		elem_row.add_theme_constant_override("separation", 4)
		elem_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(elem_row)
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = ELEMENT_COLORS[elem]
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elem_row.add_child(dot)
		var elem_lbl = Label.new()
		elem_lbl.text = elem.capitalize()
		elem_lbl.add_theme_font_size_override("font_size", 10)
		elem_lbl.add_theme_color_override("font_color", ELEMENT_COLORS[elem])
		elem_row.add_child(elem_lbl)

	var name_label = Label.new()
	name_label.text = node_data.get("name", "")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	var node_type = node_data.get("type", "")
	var type_color := Color(1.0, 0.87, 0.53, 0.75) if node_type == "skill" else Color(0.73, 0.53, 1.0, 0.75)
	var type_lbl = Label.new()
	type_lbl.text = node_type.to_upper()
	type_lbl.add_theme_font_size_override("font_size", 9)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", type_color)
	vbox.add_child(type_lbl)

	var desc_label = Label.new()
	desc_label.text = _build_node_description(node_data)
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	vbox.add_child(desc_label)

	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_l1(node_data, card)
	)
	card.set_meta("circle", circle)
	return card

func _select_l1(node_data: Dictionary, selected_card: PanelContainer) -> void:
	_selected_l1 = node_data
	for card in _l1_cards:
		var circle = card.get_meta("circle")
		var is_sel = (card == selected_card)
		circle.set_filled(is_sel)
		card.modulate = Color.WHITE if is_sel else Color(0.65, 0.65, 0.65, 1.0)
	_recompute_stats_from_spent()

func _apply_passive_stats(node_data: Dictionary) -> void:
	var effect = node_data.get("effect", "")
	var stat_map = {
		"hp": "hp", "health": "hp", "mana": "mana", "mp": "mana",
		"str": "str", "strength": "str",
		"agi": "agi", "agility": "agi",
		"int": "int", "intelligence": "int",
		"spr": "spr", "spirit": "spr",
		"def": "def", "defense": "def",
		"lck": "lck", "luck": "lck",
		"spd": "spd", "speed": "spd",
		"crit chance": "crit_chance", "crit_chance": "crit_chance",
		"crit damage": "crit_damage", "crit_damage": "crit_damage",
		"precision": "precision",
		"dodge": "dodge", "evasion": "dodge",
		"block": "block", "parry": "parry",
		"resistance": "resistance",
		"hp regen": "hp_regen", "hp_regen": "hp_regen",
		"mana regen": "mana_regen", "mp regen": "mana_regen",
	}
	var regex_pct = RegEx.new()
	regex_pct.compile(r"\+(\d+)%\s+([A-Za-z ]+?)(?:[.,]|$)")
	var regex_flat = RegEx.new()
	regex_flat.compile(r"\+(\d+)\s+([A-Za-z ]+?)(?:[.,]|$)")
	for m in regex_pct.search_all(effect):
		var pct_val = float(m.get_string(1)) / 100.0
		var raw = m.get_string(2).strip_edges().to_lower()
		if stat_map.has(raw):
			_current_stats[stat_map[raw]] += pct_val
	for m in regex_flat.search_all(effect):
		var flat_val = int(m.get_string(1))
		var raw = m.get_string(2).strip_edges().to_lower()
		if stat_map.has(raw):
			_current_stats[stat_map[raw]] += flat_val

# ── Levels 2-10 cards ────────────────────────────────────────────────────────

func _build_levels_cards(levels: Array) -> void:
	for child in levels_vbox.get_children():
		child.queue_free()

	for i in range(1, levels.size()):
		var level_nodes = levels[i]
		var level_num = i + 1

		# Level header label
		var header = Label.new()
		header.text = "Level %d" % level_num
		header.add_theme_font_size_override("font_size", 12)
		header.modulate = Color(0.6, 0.6, 0.6, 1.0)
		levels_vbox.add_child(header)

		# Row of node cards (same style as L1 but non-interactive, dimmed)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		levels_vbox.add_child(row)

		for node_data in level_nodes:
			var card = _make_display_card(node_data)
			row.add_child(card)

func _make_display_card(node_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.modulate = Color(0.75, 0.75, 0.75, 1.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var node_type = node_data.get("type", "")
	var name_color := Color(1.0, 0.87, 0.53, 1.0) if node_type == "skill" else (
		Color(0.73, 0.53, 1.0, 1.0) if node_type == "passive" else Color(0.53, 0.87, 0.67, 1.0)
	)

	var node_name: String
	if node_data.has("name"):
		node_name = node_data["name"]
	else:
		var parts: Array = []
		for sname in node_data.get("stats", {}):
			var val = node_data["stats"][sname]
			parts.append("+%.0f%% %s" % [val * 100.0, sname] if val is float else "+%d %s" % [val, sname])
		node_name = "  /  ".join(parts)

	var name_label = Label.new()
	name_label.text = node_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	var type_lbl = Label.new()
	type_lbl.add_theme_font_size_override("font_size", 9)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match node_type:
		"skill":
			type_lbl.text = "SKILL"
			type_lbl.add_theme_color_override("font_color", Color(1.0, 0.87, 0.53, 0.75))
		"passive":
			type_lbl.text = "PASSIVE"
			type_lbl.add_theme_color_override("font_color", Color(0.73, 0.53, 1.0, 0.75))
		"stat":
			type_lbl.text = "STAT"
			type_lbl.add_theme_color_override("font_color", Color(0.53, 0.87, 0.67, 0.75))
	vbox.add_child(type_lbl)

	if node_data.get("type") != "stat":
		var elem: String = node_data.get("element", "")
		if elem != "" and ELEMENT_COLORS.has(elem):
			var elem_row = HBoxContainer.new()
			elem_row.add_theme_constant_override("separation", 4)
			elem_row.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_child(elem_row)
			var dot = ColorRect.new()
			dot.custom_minimum_size = Vector2(7, 7)
			dot.color = ELEMENT_COLORS[elem]
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			elem_row.add_child(dot)
			var elem_lbl = Label.new()
			elem_lbl.text = elem.capitalize()
			elem_lbl.add_theme_font_size_override("font_size", 10)
			elem_lbl.add_theme_color_override("font_color", ELEMENT_COLORS[elem])
			elem_row.add_child(elem_lbl)

		var desc_label = Label.new()
		desc_label.text = _build_node_description(node_data)
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
		vbox.add_child(desc_label)

	return card

# ── Node description ──────────────────────────────────────────────────────────

func _build_node_description(node: Dictionary) -> String:
	var lines: Array = []
	match node.get("type", ""):
		"skill":
			if node.get("formula", "") != "":
				lines.append(node["formula"])
			var costs: Array = []
			if node.get("mp_cost", 0) > 0:
				costs.append("%d MP" % node["mp_cost"])
			if node.get("cooldown", 0) > 0:
				costs.append("CD: %d" % node["cooldown"])
			if costs.size() > 0:
				lines.append("  /  ".join(costs))
			if node.get("threat", 0) > 0:
				lines.append("Threat +%d%%" % node["threat"])
			if node.get("notes", "") != "":
				lines.append(node["notes"])
		"passive":
			lines.append(node.get("effect", ""))
		"stat":
			var parts: Array = []
			for sname in node.get("stats", {}):
				var val = node["stats"][sname]
				parts.append("+%.0f%% %s" % [val * 100.0, sname] if val is float else "+%d %s" % [val, sname])
			lines.append("  /  ".join(parts))
	return "\n".join(lines)

# ── Confirm ───────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	error_label.visible = false
	var char_name = name_input.text.strip_edges()
	if char_name.length() < 2:
		_show_error("Name must be at least 2 characters.")
		return
	if _selected_branch == "":
		_show_error("Please select a starting branch.")
		return
	if _selected_l1.is_empty():
		_show_error("Please choose a starting skill or passive.")
		return
	if _stat_points_remaining > 0:
		_show_error("Spend all %d stat points before creating." % _stat_points_remaining)
		return
	if _selected_weapon.is_empty():
		_show_error("Please select a starting weapon.")
		return

	confirm_button.disabled = true

	var uid = GameManager.current_user_id
	var slot_id = "slot_%d" % _target_slot
	var now = Time.get_unix_time_from_system()

	var char_data = {
		"name": char_name,
		"branch": _selected_branch,
		"generation": 1,
		"level": 1,
		"created_at": now,
		"stats": _current_stats,
		"skills": [_selected_l1],
		"weapon": _selected_weapon,
	}

	Firebase.Firestore.collection("users/%s/characters" % uid).set_doc(slot_id, char_data)
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(SELECT_SCENE)

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true
	confirm_button.disabled = false
