# Scenes and Scripts

Each scene has one attached script. All scripts extend `Control`. UI is built programmatically in most cases (no reliance on scene-tree nodes beyond anchored containers).

---

## Main (`scenes/Main.tscn` → `scripts/ui/main_menu.gd`)

Entry point of the game. Shows Login and Register buttons.

**On `_ready`:** checks `Firebase.Auth.check_auth_file()`. If a saved auth token exists, it hides the buttons, shows a loading label, and attempts auto-login via `token_refresh_succeeded`. On success, fetches username from Firestore and navigates to CharacterSelect.

**Key functions:**
- `_on_auto_login(auth_result)` — handles token refresh, sets `GameManager.current_user_id` and `current_username`, changes scene
- `_on_auto_login_failed` — restores buttons if token is expired or invalid

---

## Login (`scenes/Login.tscn` → `scripts/ui/login.gd`)

Email/password login form with a "Remember Me" checkbox.

**Remember Me:** saves email to `user://login_prefs.cfg` (a Godot ConfigFile, stored in the OS user data folder). Restores email on next open. If remember_me is checked, also calls `Firebase.Auth.save_auth(auth_result)` to persist the token for auto-login.

**Key functions:**
- `_on_login_pressed()` — validates fields, calls `Firebase.Auth.login_with_email_and_password(email, password)`
- `_on_login_succeeded(auth_result)` — sets GameManager state, fetches username from Firestore, navigates to CharacterSelect
- `_on_login_failed(code, message)` — shows error label

---

## Register (`scenes/Register.tscn` → `scripts/ui/register.gd`)

Registration form: username, email, password, confirm password.

**Username formatting:** `_format_name()` strips non-letter characters and auto-capitalizes each word (runs on both register and character name creation — same logic in `character_create.gd`).

**On success:** writes a `users/{uid}` document to Firestore with `username` and `created_at`, then navigates to CharacterSelect.

**Key functions:**
- `_on_register_pressed()` — validates all fields, calls `Firebase.Auth.signup_with_email_and_password(email, password)`
- `_on_signup_succeeded(auth_result)` — sets GameManager, writes Firestore doc, changes scene
- `_format_name(raw)` — strips non-letters, title-cases each word

---

## CharacterSelect (`scenes/CharacterSelect.tscn` → `scripts/ui/character_select.gd`)

Shows 3 character slot cards. Each slot maps to a Firestore document (`slot_0`, `slot_1`, `slot_2`) under `users/{uid}/characters/`.

**Loading:** loads all 3 slots in parallel using `await` on each Firestore `get_doc` call. Empty slots show a `+` button; filled slots show name, branch, stats, level, generation.

**Deletion:** requires typing `"DELETE"` into a confirmation dialog. Deletes the Firestore document.

**Selection:** clicking "Select" on a filled card sets `GameManager.current_character_id` and `GameManager.current_character`, then navigates to Lobby.

**Key functions:**
- `_load_characters_async()` — fetches all 3 slots from Firestore
- `_build_filled_card(slot, data)` — builds the card UI programmatically
- `_build_empty_card(slot)` — shows + button
- `_on_delete_confirmed()` — deletes the Firestore document after confirmation
- `_on_enter_lobby()` — sets GameManager and changes scene to Lobby

---

## CharacterCreate (`scenes/CharacterCreate.tscn` → `scripts/ui/character_create.gd`)

Full character creation flow: name, weapon, branch, L1 skill/passive, stat allocation.

**Branch (called "slice" in UI constants):** 8 directions (North, NorthEast, East, SouthEast, South, SouthWest, West, NorthWest). Each is displayed as a card built from `slice_card.gd`. Selecting a branch shows its full level tree.

**Weapons:** only `main_hand` weapons from `BranchData.WEAPONS` are shown at creation. Shield (off_hand) is not available at creation (planned for future).

**Stats:** starts from `DEFAULT_STATS`. Player gets 3 points to allocate. Each stat has a cost in `STAT_COST` (e.g. HP costs 10 per point, STR costs 1). Selecting a passive L1 option parses its `effect` string with regex to preview the stat bonuses.

**On confirm:** validates all fields, writes character document to `users/{uid}/characters/slot_{n}` in Firestore, waits 0.5s, returns to CharacterSelect.

**Key constants:**
- `DEFAULT_STATS` — base stats for every new character
- `STAT_COST` — how much each stat increases per point
- `STAT_ROWS` — display order and labels for the stat grid

**Key functions:**
- `_build_weapon_cards()` — builds weapon selection UI from BranchData.WEAPONS
- `_build_l1_cards(nodes)` — builds the clickable L1 skill/passive cards
- `_build_levels_cards(levels)` — builds the read-only preview of levels 2–10
- `_apply_passive_stats(node_data)` — parses passive effect string and applies stat bonuses to preview
- `_on_confirm()` — validates and saves character to Firestore

---

## Lobby (`scenes/Lobby.tscn` → `scripts/ui/lobby.gd`)

Main social hub. Shows online players (left panel) and groups (right panel). Uses Firebase Realtime Database for live updates.

**Heartbeat system:** sends presence every 15 seconds (`HEARTBEAT_INTERVAL`). Prunes players with heartbeat older than 45 seconds (`HEARTBEAT_TIMEOUT`).

**Three Firebase Database references:**
- `_lobby_ref` — listens to `/lobby` for player presence
- `_groups_ref` — listens to `/groups` for group state
- `_invites_ref` — listens to `/invites/{uid}` for incoming invites

**Group rules:**
- Max 4 members
- Only host can start battle, rename group, or toggle open/closed
- Host leaving deletes the group entirely
- Non-host leaving removes only their member entry
- Group auto-deletes from Firebase when members dict is empty

**Context menu (right-click):** on players in player list or member list. Options: Invite (if in a group), Leave Group (if viewing self in group), Inspect (shows character stats in event log).

**Inspect:** fetches the target's first non-empty character slot from Firestore and prints stats to the event log.

**On Start:** packs `GameManager.battle_party` from current group members (or just self if solo), then navigates to BattleSelect.

**Key functions:**
- `_send_heartbeat()` — writes `{uid: {username, heartbeat}}` to `/lobby`
- `_prune_stale_players()` — deletes entries older than 45s
- `_on_create_group_pressed()` — creates group entry in `/groups`
- `_leave_group()` — removes self from group (host deletes entire group)
- `_send_invite(uid, name)` — writes to `/invites/{target_uid}/{group_id}`
- `_on_invite_accepted()` — joins group by writing to `/groups/{id}/members`
- `_cleanup_stale_groups()` — on login, deletes any lingering groups from a previous session where you were host

---

## BattleSelect (`scenes/BattleSelect.tscn` → `scripts/ui/battle_select.gd`)

Encounter selection screen. Not fully documented here — reads from GameManager and navigates to Battle.

---

## Battle (`scenes/Battle.tscn` → `scripts/ui/battle.gd`)

ATB (Active Time Battle) combat loop.

**Combatants:** built from `GameManager.battle_party` (players) + a hardcoded Training Dummy (200 HP, SPD 8, does nothing). Each combatant is a dictionary with id, name, stats, hp, mana, atb, speed, weapon, and a panel_node reference.

**ATB engine:**
- Each alive combatant has an `atb` value (0–100) and a `speed`.
- `_advance_atb()` finds the minimum time for any combatant to reach 100 (`t = (100 - atb) / speed`), advances all combatants by `speed * t`, then animates the ATB bars using Tweens over `ATB_TICK_RATE` seconds (0.6s).
- When a combatant reaches 100, their turn starts.
- Ties are broken by shuffling.

**Combat resolution (`_resolve_attack`):**
1. Precision vs Dodge: `hit_chance = clamp(precision - dodge, 0.05, 1.0)` — miss if `randf() > hit_chance`
2. Block check: if target has block > 0, roll against it
3. Parry check: roll against parry stat
4. Base damage: `randi_range(weapon.min, weapon.max) + stat_bonus - effective_def`
5. Spear pierces 50% of DEF
6. Crit: roll against `crit_chance`, multiply damage by `1.0 + crit_damage`

**Weapon ranges (WEAPON_RANGES):**
- Dagger: 2–3 base, AGI scaling
- Broad Sword: 2–6 base, STR scaling
- Spear: 3–4 base, STR+AGI average, 50% DEF pierce
- Unarmed fallback: 1–2, STR scaling

**Enemy AI:** Training Dummy does nothing on its turn.

**Victory/Defeat:**
- Victory: all enemies dead → shows overlay with Lobby button
- Defeat: all players dead → waits 2s → returns to Lobby

**Key functions:**
- `_build_combatants()` — builds the combatant array from GameManager + dummy
- `_advance_atb()` — main ATB loop, async
- `_start_turn(c)` — sets turn state, enables attack button for local player
- `_resolve_attack(attacker, target)` → Dictionary with outcome (miss/block/parry/hit) and damage
- `_apply_attack_result(...)` — applies damage, logs result, marks dead combatants
- `_end_turn()` — resets ATB to 0, resumes loop

---

## CharacterSheet (`scenes/CharacterSheet.tscn` → `scripts/ui/character_sheet.gd`)

Overlay showing the selected character's full stats and skills. Opened from CharacterSelect.

## InventoryMenu (`scenes/InventoryMenu.tscn` → `scripts/ui/inventory_menu.gd`)

Inventory overlay. Items and trinket system not yet implemented.
