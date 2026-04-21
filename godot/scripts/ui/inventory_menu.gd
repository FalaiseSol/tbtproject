extends CanvasLayer

# Equipment slot node paths
const EQUIP_SLOTS = {
	"main_hand":  "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/WeaponsSection/WeaponRow/MainHandSlot",
	"off_hand":   "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/WeaponsSection/WeaponRow/OffHandSlot",
	"head":       "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/HeadSlot",
	"chest":      "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/ChestSlot",
	"shoulders":  "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/ShouldersSlot",
	"hands":      "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/HandsSlot",
	"legs":       "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/LegsSlot",
	"feet":       "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/ArmorSection/ArmorGrid/FeetSlot",
	"trinket_1":  "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/TrinketSection/TrinketRow/Trinket1Slot",
	"trinket_2":  "Control/Panel/MainMargin/VBoxRoot/ContentRow/EquipPanel/TrinketSection/TrinketRow/Trinket2Slot",
}

const BAG_SIZE = 20

@onready var _root_control    = $Control
@onready var _close_button    = $Control/Panel/MainMargin/VBoxRoot/TitleRow/CloseButton
@onready var _bag_label       = $Control/Panel/MainMargin/VBoxRoot/ContentRow/BagPanel/BagLabel
@onready var _bag_grid        = $Control/Panel/MainMargin/VBoxRoot/ContentRow/BagPanel/BagGrid
@onready var _item_name_label = $Control/Panel/MainMargin/VBoxRoot/ContentRow/InfoPanel/ItemNameLabel
@onready var _item_type_label = $Control/Panel/MainMargin/VBoxRoot/ContentRow/InfoPanel/ItemTypeLabel
@onready var _item_desc_label = $Control/Panel/MainMargin/VBoxRoot/ContentRow/InfoPanel/ItemDescLabel
@onready var _item_action_btn = $Control/Panel/MainMargin/VBoxRoot/ContentRow/InfoPanel/ItemActionButton

# inventory data: array of 20 slots, each null or item dict
var _bag: Array = []
# equipped items: slot_id -> item dict or null
var _equipped: Dictionary = {}
# currently highlighted slot info
var _selected_slot_type: String = ""  # "bag" or "equip"
var _selected_slot_index: int = -1    # bag index or -1
var _selected_equip_slot: String = "" # equip slot id

var _bag_slot_nodes: Array = []
var _equip_slot_nodes: Dictionary = {}
var _initialized: bool = false

func _ready() -> void:
	set_process_mode(PROCESS_MODE_ALWAYS)
	_close_button.pressed.connect(close_menu)

	for i in BAG_SIZE:
		_bag.append(null)

	for slot_id in EQUIP_SLOTS:
		_equipped[slot_id] = null

	_build_bag_grid()
	_wire_equip_slots()
	_clear_info_panel()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	_root_control.visible = !_root_control.visible
	if _root_control.visible:
		if not _initialized:
			_load_from_character()
			_initialized = true
		_refresh_all()

func _load_from_character() -> void:
	var cdata = GameManager.current_character
	if cdata.is_empty():
		return
	var weapon = cdata.get("weapon", {})
	if weapon is Dictionary and not weapon.is_empty():
		var slot_id = weapon.get("slot", "")
		if slot_id != "" and _equipped.has(slot_id):
			_equipped[slot_id] = weapon

func close_menu() -> void:
	_root_control.visible = false

# ── Bag grid ──────────────────────────────────────────────────────────────────

func _build_bag_grid() -> void:
	for child in _bag_grid.get_children():
		child.queue_free()
	_bag_slot_nodes.clear()

	for i in BAG_SIZE:
		var slot = _make_slot_panel()
		_bag_grid.add_child(slot)
		_bag_slot_nodes.append(slot)
		var idx = i
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_bag_slot_clicked(idx)
		)

func _make_slot_panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(64, 64)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.26, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.45, 0.50, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	p.add_theme_stylebox_override("panel", style)
	return p

# ── Equip slot wiring ─────────────────────────────────────────────────────────

func _wire_equip_slots() -> void:
	for slot_id in EQUIP_SLOTS:
		var node = get_node(EQUIP_SLOTS[slot_id])
		_equip_slot_nodes[slot_id] = node
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.22, 0.26, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.45, 0.45, 0.50, 1.0)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		node.add_theme_stylebox_override("panel", style)
		var sid = slot_id
		node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_equip_slot_clicked(sid)
		)

# ── Click handlers ────────────────────────────────────────────────────────────

func _on_bag_slot_clicked(index: int) -> void:
	_selected_slot_type = "bag"
	_selected_slot_index = index
	_selected_equip_slot = ""
	_highlight_bag_slot(index)
	var item = _bag[index]
	if item:
		_show_item_info(item, "bag", index)
	else:
		_clear_info_panel()

func _on_equip_slot_clicked(slot_id: String) -> void:
	_selected_slot_type = "equip"
	_selected_equip_slot = slot_id
	_selected_slot_index = -1
	_highlight_equip_slot(slot_id)
	var item = _equipped[slot_id]
	if item:
		_show_item_info(item, "equip", -1)
	else:
		_clear_info_panel()

# ── Info panel ────────────────────────────────────────────────────────────────

func _show_item_info(item: Dictionary, source: String, bag_index: int) -> void:
	_item_name_label.text = item.get("name", "Unknown")
	_item_type_label.text = _item_type_string(item)
	_item_desc_label.text = _build_item_description(item)
	_item_action_btn.visible = true

	if source == "bag":
		var slot_id = item.get("slot", "")
		if slot_id != "" and _can_equip(item):
			_item_action_btn.text = "Equip"
			_item_action_btn.pressed.connect(func(): _equip_from_bag(bag_index), CONNECT_ONE_SHOT)
		elif item.get("type") == "consumable":
			_item_action_btn.text = "Use"
			_item_action_btn.pressed.connect(func(): _use_consumable(bag_index), CONNECT_ONE_SHOT)
		else:
			_item_action_btn.visible = false
	elif source == "equip":
		_item_action_btn.text = "Unequip"
		_item_action_btn.pressed.connect(func(): _unequip_to_bag(_selected_equip_slot), CONNECT_ONE_SHOT)

func _clear_info_panel() -> void:
	_item_name_label.text = ""
	_item_type_label.text = ""
	_item_desc_label.text = ""
	_item_action_btn.visible = false
	for c in _item_action_btn.pressed.get_connections():
		_item_action_btn.pressed.disconnect(c["callable"])

func _item_type_string(item: Dictionary) -> String:
	match item.get("type", ""):
		"weapon":    return "Weapon  —  " + item.get("slot", "").replace("_", " ").capitalize()
		"armor":     return "Armor  —  " + item.get("slot", "").capitalize()
		"trinket":   return "Trinket  (Lv.%d)" % item.get("level", 1)
		"consumable": return "Consumable"
		_:           return ""

func _build_item_description(item: Dictionary) -> String:
	var lines: Array[String] = []
	var stats: Dictionary = item.get("stats", {})
	for key in stats:
		var val = stats[key]
		if val is float:
			lines.append("+%.0f%% %s" % [val * 100.0, key.capitalize()])
		else:
			lines.append("+%d %s" % [val, key.to_upper()])
	if item.get("notes", "") != "":
		lines.append(item["notes"])
	if item.get("type") == "trinket":
		var ttype = item.get("trinket_type", "")
		var level = item.get("level", 1)
		var bonus = _trinket_stat_value(ttype, level)
		lines.append("%s  +%.1f%%  (Lv.%d/10)" % [ttype.capitalize(), bonus * 100.0, level])
		lines.append("Upgrade with: Spirit")
	return "\n".join(lines)

# ── Trinket values (Resistance / Precision: +0.5% per level) ─────────────────

static func _trinket_stat_value(_trinket_type: String, level: int) -> float:
	return clampf(level * 0.005, 0.005, 0.05)

# ── Equip / Unequip ───────────────────────────────────────────────────────────

func _can_equip(item: Dictionary) -> bool:
	var slot = item.get("slot", "")
	return slot != "" and _equipped.has(slot)

func _equip_from_bag(bag_index: int) -> void:
	var item = _bag[bag_index]
	if item == null:
		return
	var slot_id = item.get("slot", "")
	if slot_id == "" or not _equipped.has(slot_id):
		return
	var currently_equipped = _equipped[slot_id]
	_equipped[slot_id] = item
	_bag[bag_index] = currently_equipped
	_sync_to_game_manager()
	_refresh_all()
	_clear_info_panel()

func _unequip_to_bag(slot_id: String) -> void:
	var item = _equipped[slot_id]
	if item == null:
		return
	var free_index = _bag.find(null)
	if free_index == -1:
		_item_desc_label.text = "[color=red]Bag is full.[/color]"
		return
	_bag[free_index] = item
	_equipped[slot_id] = null
	_sync_to_game_manager()
	_refresh_all()
	_clear_info_panel()

func _sync_to_game_manager() -> void:
	var w = _equipped.get("main_hand", {})
	GameManager.current_character["weapon"] = w if w is Dictionary else {}

func _use_consumable(bag_index: int) -> void:
	var item = _bag[bag_index]
	if item == null:
		return
	_bag[bag_index] = null
	_refresh_all()
	_clear_info_panel()

# ── Refresh display ───────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_bag()
	_refresh_equip_slots()
	_update_bag_label()

func _update_bag_label() -> void:
	var count = _bag.filter(func(x): return x != null).size()
	_bag_label.text = "Bag  (%d / %d)" % [count, BAG_SIZE]

func _refresh_bag() -> void:
	for i in _bag_slot_nodes.size():
		var slot_node = _bag_slot_nodes[i]
		for child in slot_node.get_children():
			child.queue_free()
		var item = _bag[i]
		if item:
			var lbl = Label.new()
			lbl.text = item.get("name", "?")
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot_node.add_child(lbl)

func _refresh_equip_slots() -> void:
	for slot_id in _equip_slot_nodes:
		var node = _equip_slot_nodes[slot_id]
		var lbl = node.get_node_or_null(slot_id.capitalize() + "Label")
		if lbl == null:
			lbl = node.get_child(0) if node.get_child_count() > 0 else null
		var item = _equipped[slot_id]
		if lbl:
			if item:
				lbl.text = item.get("name", "?")
				lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				lbl.text = _default_slot_label(slot_id)
				lbl.modulate = Color(0.5, 0.5, 0.5, 1.0)

func _default_slot_label(slot_id: String) -> String:
	match slot_id:
		"main_hand": return "R. Hand"
		"off_hand":  return "L. Hand"
		"trinket_1": return "Trinket 1"
		"trinket_2": return "Trinket 2"
		_: return slot_id.capitalize()

func _highlight_bag_slot(index: int) -> void:
	for i in _bag_slot_nodes.size():
		_bag_slot_nodes[i].modulate = Color(1.2, 1.0, 0.4) if i == index else Color.WHITE

func _highlight_equip_slot(slot_id: String) -> void:
	for sid in _equip_slot_nodes:
		_equip_slot_nodes[sid].modulate = Color(1.2, 1.0, 0.4) if sid == slot_id else Color.WHITE
