extends CanvasLayer

# Stat display order and labels
const STAT_ROWS = [
	["hp",          "HP",          false],
	["mana",        "Mana",        false],
	["str",         "STR",         false],
	["agi",         "AGI",         false],
	["int",         "INT",         false],
	["spr",         "SPR",         false],
	["def",         "DEF",         false],
	["lck",         "LCK",         false],
	["spd",         "SPD",         false],
	["hp_regen",    "HP Regen",    false],
	["mana_regen",  "MP Regen",    false],
	["precision",   "Precision",   true],
	["dodge",       "Dodge",       true],
	["block",       "Block",       true],
	["parry",       "Parry",       true],
	["crit_chance", "Crit",        true],
	["crit_damage", "Crit DMG",    true],
	["resistance",  "Resistance",  true],
]

# DEFAULT_STATS duplicated here so the sheet can compute base vs bonuses
const BASE_STATS = {
	"hp": 100, "mana": 50,
	"str": 10, "agi": 10, "int": 10,
	"spr": 10, "def": 10, "lck": 10, "spd": 10,
	"hp_regen": 0, "mana_regen": 7,
	"crit_chance": 0.05, "crit_damage": 1.0,
	"precision": 1.0, "dodge": 0.02,
	"block": 0.05, "parry": 0.05,
	"resistance": 0.10,
}

@onready var _root_control  = $Control
@onready var _close_button  = $Control/Panel/MainMargin/VBoxRoot/TitleRow/CloseButton
@onready var _char_name_lbl = $Control/Panel/MainMargin/VBoxRoot/TitleRow/CharNameLabel
@onready var _branch_lbl    = $Control/Panel/MainMargin/VBoxRoot/SubTitleRow/BranchLabel
@onready var _level_lbl     = $Control/Panel/MainMargin/VBoxRoot/SubTitleRow/LevelLabel
@onready var _stats_grid    = $Control/Panel/MainMargin/VBoxRoot/ContentRow/StatsPanel/StatsGrid
@onready var _skills_vbox   = $Control/Panel/MainMargin/VBoxRoot/ContentRow/SkillsPanel/SkillsScroll/SkillsVBox

func _ready() -> void:
	set_process_mode(PROCESS_MODE_ALWAYS)
	_close_button.pressed.connect(close_sheet)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character_sheet"):
		toggle_sheet()
		get_viewport().set_input_as_handled()

func toggle_sheet() -> void:
	_root_control.visible = !_root_control.visible
	if _root_control.visible:
		_populate()

func close_sheet() -> void:
	_root_control.visible = false

# ── Populate ──────────────────────────────────────────────────────────────────

func _populate() -> void:
	var cdata = GameManager.current_character
	if cdata.is_empty():
		return

	_char_name_lbl.text = cdata.get("name", "Unknown")
	_branch_lbl.text = cdata.get("branch", "?") + " Branch"
	_level_lbl.text = "Lv.%d  |  Gen.%d" % [cdata.get("level", 1), cdata.get("generation", 1)]

	var stored_stats: Dictionary = cdata.get("stats", {})
	var weapon_raw = cdata.get("weapon", {})
	var weapon: Dictionary = weapon_raw if weapon_raw is Dictionary else {}
	var skills: Array = cdata.get("skills", [])

	var weapon_stats = weapon.get("stats", {})
	var passive_stats = _collect_passive_stats(skills)

	_build_stats_grid(stored_stats, weapon_stats, passive_stats)
	_build_skills_list(skills, weapon)

# ── Passive stat collection (L4+ stat-type nodes and passive effects) ─────────

func _collect_passive_stats(skills: Array) -> Dictionary:
	var result: Dictionary = {}
	var stat_map = {
		"hp": "hp", "health": "hp", "mana": "mana", "mp": "mana",
		"str": "str", "strength": "str", "agi": "agi", "agility": "agi",
		"int": "int", "intelligence": "int", "spr": "spr", "spirit": "spr",
		"def": "def", "defense": "def", "lck": "lck", "luck": "lck",
		"spd": "spd", "speed": "spd",
		"crit chance": "crit_chance", "crit_chance": "crit_chance",
		"crit damage": "crit_damage", "crit_damage": "crit_damage",
		"precision": "precision", "dodge": "dodge", "evasion": "dodge",
		"block": "block", "parry": "parry", "resistance": "resistance",
		"hp regen": "hp_regen", "hp_regen": "hp_regen",
		"mana regen": "mana_regen", "mp regen": "mana_regen",
	}
	var regex_pct = RegEx.new()
	regex_pct.compile(r"\+(\d+)%\s+([A-Za-z ]+?)(?:[.,]|$)")
	var regex_flat = RegEx.new()
	regex_flat.compile(r"\+(\d+)\s+([A-Za-z ]+?)(?:[.,]|$)")

	for node in skills:
		# stat-type nodes (come from L4+ branch picks)
		if node.get("type") == "stat":
			for skey in node.get("stats", {}):
				result[skey] = result.get(skey, 0) + node["stats"][skey]
		# passive-type nodes with stat_bonus
		elif node.get("type") == "passive":
			for skey in node.get("stat_bonus", {}):
				result[skey] = result.get(skey, 0) + node["stat_bonus"][skey]
			# also parse free-text effect string for passives without stat_bonus
			var effect = node.get("effect", "")
			for m in regex_pct.search_all(effect):
				var val = float(m.get_string(1)) / 100.0
				var raw = m.get_string(2).strip_edges().to_lower()
				if stat_map.has(raw):
					result[stat_map[raw]] = result.get(stat_map[raw], 0.0) + val
			for m in regex_flat.search_all(effect):
				var val = int(m.get_string(1))
				var raw = m.get_string(2).strip_edges().to_lower()
				if stat_map.has(raw):
					result[stat_map[raw]] = result.get(stat_map[raw], 0) + val
	return result

# ── Stats grid ────────────────────────────────────────────────────────────────

func _build_stats_grid(stored: Dictionary, weapon: Dictionary, passives: Dictionary) -> void:
	for child in _stats_grid.get_children():
		child.queue_free()

	# Header row
	for header in ["Stat", "Base", "Pts", "Items", "Passives", "Total"]:
		var lbl = Label.new()
		lbl.text = header
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color(0.55, 0.55, 0.55)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_grid.add_child(lbl)

	for row in STAT_ROWS:
		var key: String = row[0]
		var label: String = row[1]
		var is_pct: bool = row[2]

		var base = BASE_STATS.get(key, 0)
		var total_stored = stored.get(key, base)
		var item_bonus = weapon.get(key, 0)
		var passive_bonus = passives.get(key, 0)
		# points = stored - base - passives already baked in at creation
		# stored already includes base + point spending + L1 passive at creation
		# so: pts_bonus = stored - base - passive_bonus (passive was baked in at creation too)
		var pts_bonus = total_stored - base - passive_bonus
		# total = stored (already has pts+passives baked) + items + any new passives from skills array
		var total = total_stored + item_bonus

		var name_lbl = Label.new()
		name_lbl.text = label
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.modulate = Color(0.75, 0.75, 0.75)
		_stats_grid.add_child(name_lbl)

		_add_stat_cell(base, is_pct, Color(0.7, 0.7, 0.7))
		_add_stat_cell(pts_bonus, is_pct, Color(0.4, 0.8, 1.0) if _nonzero(pts_bonus) else Color(0.4, 0.4, 0.4))
		_add_stat_cell(item_bonus, is_pct, Color(0.4, 1.0, 0.6) if _nonzero(item_bonus) else Color(0.4, 0.4, 0.4))
		_add_stat_cell(passive_bonus, is_pct, Color(0.9, 0.6, 1.0) if _nonzero(passive_bonus) else Color(0.4, 0.4, 0.4))

		var total_lbl = Label.new()
		total_lbl.text = _fmt(total, is_pct)
		total_lbl.add_theme_font_size_override("font_size", 11)
		total_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_grid.add_child(total_lbl)

func _add_stat_cell(value, is_pct: bool, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = _fmt(value, is_pct) if _nonzero(value) else "—"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_grid.add_child(lbl)

func _fmt(value, is_pct: bool) -> String:
	if is_pct:
		return "%.1f%%" % (value * 100.0)
	elif value is float:
		return "%.1f" % value
	else:
		return str(value)

func _nonzero(value) -> bool:
	if value is float:
		return abs(value) > 0.0001
	return value != 0

# ── Skills list ───────────────────────────────────────────────────────────────

func _build_skills_list(skills: Array, weapon: Dictionary) -> void:
	for child in _skills_vbox.get_children():
		child.queue_free()

	# Weapon
	if not weapon.is_empty():
		_add_section_header("Weapon")
		var w_lbl = Label.new()
		var parts: Array = []
		for skey in weapon.get("stats", {}):
			var sv = weapon["stats"][skey]
			parts.append("+%d %s" % [sv, skey.to_upper()])
		w_lbl.text = "%s  —  %s" % [weapon.get("name", "?"), "  /  ".join(parts)]
		w_lbl.add_theme_font_size_override("font_size", 12)
		w_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skills_vbox.add_child(w_lbl)
		if weapon.get("notes", "") != "":
			var note = Label.new()
			note.text = weapon["notes"]
			note.add_theme_font_size_override("font_size", 10)
			note.modulate = Color(0.6, 0.6, 0.6)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_skills_vbox.add_child(note)

	# Skills and passives
	var skill_nodes: Array = skills.filter(func(n): return n.get("type") == "skill")
	var passive_nodes: Array = skills.filter(func(n): return n.get("type") == "passive")
	var stat_nodes: Array = skills.filter(func(n): return n.get("type") == "stat")

	if skill_nodes.size() > 0:
		_add_section_header("Skills")
		for node in skill_nodes:
			_add_skill_entry(node)

	if passive_nodes.size() > 0:
		_add_section_header("Passives")
		for node in passive_nodes:
			_add_passive_entry(node)

	if stat_nodes.size() > 0:
		_add_section_header("Stat Nodes")
		for node in stat_nodes:
			var parts: Array = []
			for skey in node.get("stats", {}):
				var val = node["stats"][skey]
				parts.append("+%.0f%% %s" % [val * 100.0, skey] if val is float else "+%d %s" % [val, skey.to_upper()])
			var lbl = Label.new()
			lbl.text = "  /  ".join(parts)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.modulate = Color(0.53, 0.87, 0.67)
			_skills_vbox.add_child(lbl)

func _add_section_header(title: String) -> void:
	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.15)
	_skills_vbox.add_child(sep)
	var lbl = Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.5, 0.5, 0.5)
	_skills_vbox.add_child(lbl)

func _add_skill_entry(node: Dictionary) -> void:
	var name_lbl = Label.new()
	name_lbl.text = node.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.87, 0.53))
	_skills_vbox.add_child(name_lbl)

	var parts: Array = []
	if node.get("mp_cost", 0) > 0:
		parts.append("%d MP" % node["mp_cost"])
	if node.get("cooldown", 0) > 0:
		parts.append("CD: %d" % node["cooldown"])
	if node.get("formula", "") != "":
		parts.append(node["formula"])
	if node.get("notes", "") != "":
		parts.append(node["notes"])

	if parts.size() > 0:
		var desc = Label.new()
		desc.text = "  /  ".join(parts)
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = Color(0.65, 0.65, 0.65)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skills_vbox.add_child(desc)

func _add_passive_entry(node: Dictionary) -> void:
	var name_lbl = Label.new()
	name_lbl.text = node.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.73, 0.53, 1.0))
	_skills_vbox.add_child(name_lbl)

	var effect = node.get("effect", "")
	if effect != "":
		var desc = Label.new()
		desc.text = effect
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = Color(0.65, 0.65, 0.65)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skills_vbox.add_child(desc)
