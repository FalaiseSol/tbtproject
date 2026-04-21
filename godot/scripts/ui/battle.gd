extends Control

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _party_slots:   VBoxContainer  = $MainMargin/VBoxRoot/CombatantsRow/PartyPanel/PartySlots
@onready var _enemy_slots:   VBoxContainer  = $MainMargin/VBoxRoot/CombatantsRow/EnemyPanel/EnemySlots
@onready var _attack_btn:    Button         = $MainMargin/VBoxRoot/BottomSection/ActionRow/ActionButtons/AttackButton
@onready var _target_btns:   VBoxContainer  = $MainMargin/VBoxRoot/BottomSection/ActionRow/TargetButtons
@onready var _log_text:       RichTextLabel  = $MainMargin/VBoxRoot/BottomSection/LogPanel/LogScroll/LogText
@onready var _log_scroll:     ScrollContainer = $MainMargin/VBoxRoot/BottomSection/LogPanel/LogScroll
@onready var _victory_overlay: ColorRect      = $VictoryOverlay
@onready var _lobby_button:    Button         = $VictoryOverlay/VictoryPanel/VictoryMargin/VictoryVBox/LobbyButton

# ── Weapon damage ranges ───────────────────────────────────────────────────────
const WEAPON_RANGES = {
	"dagger":     { "min": 2,  "max": 3,  "stat": "agi",               "def_pierce": 0.0 },
	"broad_sword":{ "min": 2,  "max": 6,  "stat": "str",               "def_pierce": 0.0 },
	"spear":      { "min": 3,  "max": 4,  "stat": "str_agi",           "def_pierce": 0.5 },
}
const UNARMED = { "min": 1, "max": 2, "stat": "str", "def_pierce": 0.0 }

# ── Combatant structure ────────────────────────────────────────────────────────
# { id, name, is_player, uid, stats, hp, max_hp, mana, max_mana,
#   atb, speed, alive, weapon, panel_node }

var _combatants: Array = []
var _turn_state: String = "atb"   # "atb" | "action" | "targeting" | "animating" | "ended"
var _active_idx: int = -1
var _pending_action: String = ""
var _my_uid: String = ""
var _is_my_turn: bool = false

# ── ATB ────────────────────────────────────────────────────────────────────────
const ATB_TICK_RATE: float = 0.6
var _atb_tweens: Dictionary = {}   # combatant id -> Tween

func _ready() -> void:
	_my_uid = GameManager.current_user_id
	_attack_btn.pressed.connect(_on_attack_pressed)
	_build_combatants()
	_build_ui()
	_lobby_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Lobby.tscn"))
	_log("[color=#aaaaaa]Battle started![/color]")
	_advance_atb()

# ── Build combatant list ───────────────────────────────────────────────────────

func _build_combatants() -> void:
	var party = GameManager.battle_party
	if party.is_empty():
		party = [{ "uid": _my_uid, "username": GameManager.current_username, "character": GameManager.current_character.duplicate(true) }]

	for i in party.size():
		var member = party[i]
		var char_data: Dictionary = member.get("character", {})
		if char_data.is_empty():
			char_data = GameManager.current_character.duplicate(true)
		var stats: Dictionary = char_data.get("stats", {})
		var spd = _effective_stat(stats, char_data.get("weapon", {}), "spd")
		var hp  = _effective_stat(stats, char_data.get("weapon", {}), "hp")
		var mp  = _effective_stat(stats, char_data.get("weapon", {}), "mana")
		_combatants.append({
			"id":        "player_%d" % i,
			"name":      member.get("username", "Player"),
			"is_player": true,
			"uid":       member.get("uid", ""),
			"stats":     stats,
			"weapon":    char_data.get("weapon", {}),
			"hp":        hp,
			"max_hp":    hp,
			"mana":      mp,
			"max_mana":  mp,
			"atb":       0.0,
			"speed":     max(spd, 1),
			"alive":     true,
			"panel_node": null,
		})

	_combatants.append({
		"id":        "dummy_0",
		"name":      "Training Dummy",
		"is_player": false,
		"uid":       "",
		"stats":     { "def": 5, "block": 0.10, "parry": 0.0, "dodge": 0.0, "precision": 1.0 },
		"weapon":    {},
		"hp":        200,
		"max_hp":    200,
		"mana":      0,
		"max_mana":  0,
		"atb":       0.0,
		"speed":     8,
		"alive":     true,
		"panel_node": null,
	})

func _effective_stat(stats: Dictionary, weapon: Dictionary, key: String) -> int:
	var base = stats.get(key, 0)
	var w_bonus = weapon.get("stats", {}).get(key, 0) if weapon is Dictionary else 0
	return base + w_bonus

# ── Build UI panels ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	for c in _combatants:
		var panel = _make_combatant_panel(c)
		c["panel_node"] = panel
		if c["is_player"]:
			_party_slots.add_child(panel)
		else:
			_enemy_slots.add_child(panel)

func _make_combatant_panel(c: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("cid", c["id"])

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = c["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.set_meta("role", "name")
	vbox.add_child(name_lbl)

	# HP bar
	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	vbox.add_child(hp_row)
	var hp_key = Label.new()
	hp_key.text = "HP"
	hp_key.add_theme_font_size_override("font_size", 10)
	hp_key.modulate = Color(0.6, 0.6, 0.6)
	hp_key.custom_minimum_size = Vector2(22, 0)
	hp_row.add_child(hp_key)
	var hp_bar = ProgressBar.new()
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.min_value = 0
	hp_bar.max_value = c["max_hp"]
	hp_bar.value = c["hp"]
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.show_percentage = false
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.55, 0.08, 0.08, 1.0)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.set_meta("role", "hp_bar")
	hp_row.add_child(hp_bar)
	var hp_lbl = Label.new()
	hp_lbl.text = "%d/%d" % [c["hp"], c["max_hp"]]
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.custom_minimum_size = Vector2(55, 0)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_lbl.set_meta("role", "hp_lbl")
	hp_row.add_child(hp_lbl)

	# MP bar
	var mp_row = HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 6)
	vbox.add_child(mp_row)
	var mp_key = Label.new()
	mp_key.text = "MP"
	mp_key.add_theme_font_size_override("font_size", 10)
	mp_key.modulate = Color(0.6, 0.6, 0.6)
	mp_key.custom_minimum_size = Vector2(22, 0)
	mp_row.add_child(mp_key)
	var mp_bar = ProgressBar.new()
	mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_bar.min_value = 0
	mp_bar.max_value = max(c["max_mana"], 1)
	mp_bar.value = c["mana"]
	mp_bar.custom_minimum_size = Vector2(0, 10)
	mp_bar.show_percentage = false
	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.1, 0.2, 0.8, 1.0)
	mp_bar.add_theme_stylebox_override("fill", mp_fill)
	mp_bar.set_meta("role", "mp_bar")
	mp_row.add_child(mp_bar)
	var mp_lbl = Label.new()
	mp_lbl.text = "%d/%d" % [c["mana"], c["max_mana"]]
	mp_lbl.add_theme_font_size_override("font_size", 10)
	mp_lbl.custom_minimum_size = Vector2(55, 0)
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.set_meta("role", "mp_lbl")
	mp_row.add_child(mp_lbl)

	# ATB bar
	var atb_row = HBoxContainer.new()
	atb_row.add_theme_constant_override("separation", 6)
	vbox.add_child(atb_row)
	var atb_key = Label.new()
	atb_key.text = "ATB"
	atb_key.add_theme_font_size_override("font_size", 10)
	atb_key.modulate = Color(0.6, 0.6, 0.6)
	atb_key.custom_minimum_size = Vector2(22, 0)
	atb_row.add_child(atb_key)
	var atb_bar = ProgressBar.new()
	atb_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atb_bar.min_value = 0
	atb_bar.max_value = 100
	atb_bar.value = 0
	atb_bar.custom_minimum_size = Vector2(0, 8)
	atb_bar.show_percentage = false
	var atb_fill = StyleBoxFlat.new()
	atb_fill.bg_color = Color(0.3, 0.7, 1.0, 1.0)
	atb_bar.add_theme_stylebox_override("fill", atb_fill)
	atb_bar.set_meta("role", "atb_bar")
	atb_row.add_child(atb_bar)

	return panel

func _get_panel_node(panel: PanelContainer, meta_role: String) -> Node:
	for child in panel.get_child(0).get_child(0).get_children():
		if child.has_meta("role") and child.get_meta("role") == meta_role:
			return child
		for sub in child.get_children():
			if sub.has_meta("role") and sub.get_meta("role") == meta_role:
				return sub
	return null

func _refresh_panel(c: Dictionary) -> void:
	var panel = c["panel_node"] as PanelContainer
	if panel == null:
		return
	var hp_bar = _get_panel_node(panel, "hp_bar") as ProgressBar
	var hp_lbl = _get_panel_node(panel, "hp_lbl") as Label
	var mp_bar = _get_panel_node(panel, "mp_bar") as ProgressBar
	var mp_lbl = _get_panel_node(panel, "mp_lbl") as Label
	if hp_bar:
		hp_bar.value = c["hp"]
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [c["hp"], c["max_hp"]]
	if mp_bar:
		mp_bar.value = c["mana"]
	if mp_lbl:
		mp_lbl.text = "%d/%d" % [c["mana"], c["max_mana"]]
	panel.modulate = Color(0.5, 0.5, 0.5, 1.0) if not c["alive"] else Color.WHITE

# ── ATB engine ─────────────────────────────────────────────────────────────────

func _tween_atb_bar(c: Dictionary, target_value: float) -> void:
	var bar = _get_panel_node(c["panel_node"], "atb_bar") as ProgressBar
	if bar == null:
		return
	var cid = c["id"]
	if _atb_tweens.has(cid) and _atb_tweens[cid]:
		_atb_tweens[cid].kill()
	var tw = create_tween()
	tw.tween_property(bar, "value", target_value, ATB_TICK_RATE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	_atb_tweens[cid] = tw

func _advance_atb() -> void:
	if _turn_state != "atb":
		return

	var alive = _combatants.filter(func(c): return c["alive"])
	if alive.is_empty():
		return

	# Find who reaches 100 first: time = (100 - atb) / speed for each unit
	var min_time = INF
	for c in alive:
		var t = (100.0 - c["atb"]) / float(c["speed"])
		if t < min_time:
			min_time = t

	# Advance everyone by min_time * their speed, animating bars over the tick duration
	for c in alive:
		var new_atb = minf(c["atb"] + c["speed"] * min_time, 100.0)
		c["atb"] = new_atb
		_tween_atb_bar(c, new_atb)

	await get_tree().create_timer(ATB_TICK_RATE).timeout

	# Collect all who hit 100 (ties)
	var ready: Array = alive.filter(func(c): return c["atb"] >= 100.0)
	if ready.size() > 1:
		ready.shuffle()
	if ready.size() > 0:
		_start_turn(ready[0])

func _set_atb_bar_color(c: Dictionary, color: Color) -> void:
	var bar = _get_panel_node(c["panel_node"], "atb_bar") as ProgressBar
	if bar == null:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)

func _start_turn(c: Dictionary) -> void:
	_turn_state = "action"
	_active_idx = _combatants.find(c)
	_set_atb_bar_color(c, Color(1.0, 0.9, 0.2, 1.0))
	_log("[color=#ffffaa]— %s's turn —[/color]" % c["name"])

	if not c["is_player"]:
		_enemy_take_turn(c)
		return

	_is_my_turn = (c["uid"] == _my_uid)
	_attack_btn.disabled = not _is_my_turn
	_clear_target_buttons()
	if not _is_my_turn:
		_log("[color=#888888]Waiting for %s to act...[/color]" % c["name"])

func _end_turn() -> void:
	if _active_idx >= 0:
		var c = _combatants[_active_idx]
		c["atb"] = 0.0
		_set_atb_bar_color(c, Color(0.3, 0.7, 1.0, 1.0))
		_tween_atb_bar(c, 0.0)
		_refresh_panel(c)
	_active_idx = -1
	_is_my_turn = false
	_attack_btn.disabled = true
	_clear_target_buttons()
	_turn_state = "atb"

	if await _check_victory():
		return
	if await _check_defeat():
		return

	await get_tree().create_timer(ATB_TICK_RATE).timeout
	_advance_atb()

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_attack_pressed() -> void:
	if not _is_my_turn or _turn_state != "action":
		return
	_turn_state = "targeting"
	_pending_action = "attack"
	_show_targets()

func _show_targets() -> void:
	_clear_target_buttons()
	var targets = _combatants.filter(func(c): return c["alive"] and not c["is_player"])
	for t in targets:
		var btn = Button.new()
		btn.text = "%s  [HP: %d]" % [t["name"], t["hp"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 32)
		var tid = t["id"]
		btn.pressed.connect(func(): _execute_attack(tid))
		_target_btns.add_child(btn)

func _clear_target_buttons() -> void:
	for child in _target_btns.get_children():
		child.queue_free()

func _execute_attack(target_id: String) -> void:
	_turn_state = "animating"
	_clear_target_buttons()
	_attack_btn.disabled = true

	var attacker = _combatants[_active_idx]
	var target_idx = -1
	for i in _combatants.size():
		if _combatants[i]["id"] == target_id:
			target_idx = i
			break
	if target_idx == -1:
		_end_turn()
		return
	var target = _combatants[target_idx]

	var result = _resolve_attack(attacker, target)
	_apply_attack_result(attacker, target, target_idx, result)
	await get_tree().create_timer(0.4).timeout
	_end_turn()

func _resolve_attack(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var stats = attacker["stats"]
	var weapon = attacker["weapon"]
	var weapon_id = weapon.get("id", "") if weapon is Dictionary else ""
	var wdata = WEAPON_RANGES.get(weapon_id, UNARMED)

	# Precision vs dodge check
	var precision = stats.get("precision", 1.0)
	var dodge     = target["stats"].get("dodge", 0.0)
	var hit_chance = clampf(precision - dodge, 0.05, 1.0)
	if randf() > hit_chance:
		return { "outcome": "miss" }

	# Block check (only if target has shield / block stat > 0)
	var block = target["stats"].get("block", 0.0)
	if block > 0.0 and randf() < block:
		return { "outcome": "block" }

	# Parry check
	var parry = target["stats"].get("parry", 0.0)
	if parry > 0.0 and randf() < parry:
		return { "outcome": "parry" }

	# Base damage
	var base = randi_range(wdata["min"], wdata["max"])
	var stat_bonus: int
	if wdata["stat"] == "str_agi":
		stat_bonus = int(stats.get("str", 0) * 0.5 + stats.get("agi", 0) * 0.5)
	else:
		stat_bonus = stats.get(wdata["stat"], 0)

	var def_val = target["stats"].get("def", 0)
	var pierce  = wdata["def_pierce"]
	var effective_def = int(def_val * (1.0 - pierce))
	var raw_dmg = max(base + stat_bonus - effective_def, 1)

	# Crit check
	var crit_chance = stats.get("crit_chance", 0.05)
	var crit_dmg_mult = 1.0 + stats.get("crit_damage", 1.0)
	var is_crit = randf() < crit_chance
	var final_dmg = int(raw_dmg * crit_dmg_mult) if is_crit else raw_dmg

	return { "outcome": "hit", "damage": final_dmg, "crit": is_crit }

func _apply_attack_result(attacker: Dictionary, target: Dictionary, target_idx: int, result: Dictionary) -> void:
	match result["outcome"]:
		"miss":
			_log("[color=#ff9966]%s attacked %s — [b]Miss![/b][/color]" % [attacker["name"], target["name"]])
		"block":
			_log("[color=#88aaff]%s attacked %s — [b]Blocked![/b][/color]" % [attacker["name"], target["name"]])
		"parry":
			_log("[color=#88aaff]%s attacked %s — [b]Parried![/b][/color]" % [attacker["name"], target["name"]])
		"hit":
			var dmg = result["damage"]
			_combatants[target_idx]["hp"] = max(_combatants[target_idx]["hp"] - dmg, 0)
			_refresh_panel(target)
			if result["crit"]:
				_log("[color=#ffdd44]%s attacked %s — [b]CRIT! %d damage![/b][/color]" % [attacker["name"], target["name"], dmg])
			else:
				_log("%s attacked %s for [b]%d[/b] damage." % [attacker["name"], target["name"], dmg])
			if _combatants[target_idx]["hp"] <= 0:
				_combatants[target_idx]["alive"] = false
				_refresh_panel(_combatants[target_idx])
				_log("[color=#ff4444]%s has been defeated![/color]" % target["name"])

# ── Enemy AI ───────────────────────────────────────────────────────────────────

func _enemy_take_turn(enemy: Dictionary) -> void:
	await get_tree().create_timer(0.8).timeout
	var alive_players = _combatants.filter(func(c): return c["is_player"] and c["alive"])
	if alive_players.is_empty():
		_end_turn()
		return
	# Dummy does nothing
	_log("[color=#888888]%s does nothing.[/color]" % enemy["name"])
	await get_tree().create_timer(0.4).timeout
	_end_turn()

# ── Victory / Defeat ───────────────────────────────────────────────────────────

func _check_victory() -> bool:
	var alive_enemies = _combatants.filter(func(c): return not c["is_player"] and c["alive"])
	if alive_enemies.is_empty():
		_turn_state = "ended"
		_attack_btn.disabled = true
		_log("[color=#44ff88][b]Victory! All enemies defeated.[/b][/color]")
		await get_tree().process_frame
		_victory_overlay.visible = true
		return true
	return false

func _check_defeat() -> bool:
	var alive_players = _combatants.filter(func(c): return c["is_player"] and c["alive"])
	if alive_players.is_empty():
		_turn_state = "ended"
		_log("[color=#ff4444][b]Defeat! All party members have fallen.[/b][/color]")
		_attack_btn.disabled = true
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
		return true
	return false

# ── Log ────────────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	_log_text.append_text(msg + "\n")
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)
