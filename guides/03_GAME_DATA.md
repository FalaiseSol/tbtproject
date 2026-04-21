# Game Data: GameManager, BranchData, and Stats

---

## GameManager (`scripts/game/game_manager.gd`)

Global autoload singleton. Holds all runtime state that needs to survive scene changes.

**Variables:**
| Variable | Type | Purpose |
|---|---|---|
| `current_user_id` | String | Firebase UID of logged-in user |
| `current_username` | String | Display name |
| `current_character_id` | String | Firestore doc ID of selected character (e.g. "slot_0") |
| `current_character` | Dictionary | Full character data loaded from Firestore |
| `battle_party` | Array | Array of `{uid, username, character}` dicts — set before entering battle |
| `is_host` | bool | Whether local player is group host |
| `current_group_id` | String | Firebase group ID if in a group |

**Key functions:**
- `is_logged_in()` → bool
- `has_character()` → bool
- `logout()` — clears all state and calls `Firebase.Auth.logout()`

---

## BranchData (`scripts/game/branch_data.gd`)

Static data file (no instance needed — accessed via `preload`). Contains all game data constants.

### WEAPONS

Array of weapon definitions:
```gdscript
{ "id": "dagger", "name": "Dagger", "slot": "main_hand",
  "stats": { "agi": 8, "lck": 3 }, "notes": "..." }
```

Current weapons: Dagger (main), Broad Sword (main), Spear (main), Shield (off_hand).

Shield is off_hand and not available at character creation (only main_hand weapons shown). Shield enables the Block stat (+10% block, -2 SPD).

### DEBUFFS / BUFFS

Dictionaries keyed by debuff/buff ID. Each entry defines the effect, stat, value, duration, and stacking rules. These are the authoritative definitions — combat code reads from these when applying effects.

**Debuff types:** `stat_mod`, `dot`, `action_loss`, `damage_amp`, `compound`
**Buff stacking:** `refresh`, `stack`, `ignore`, `replace`

### BRANCHES

The core skill tree data. Structure:
```
BRANCHES = {
  "North": [
    [L1 nodes],  # index 0 — 3 options, player picks one at creation
    [L2 nodes],  # index 1
    [L3 nodes],  # index 2
    [L4 nodes],  # index 3
    [L5 stats],  # index 4 — stat nodes only from here
    [L6 stats],  # index 5
    ...
    [L10 stats], # index 9
  ],
  "NorthEast": [...],
  ...8 total branches
}
```

**Node types:**
- `skill` — has `mp_cost`, `cooldown`, `target`, `formula`, `element`, `threat`, optional `applies_debuff`/`applies_buff`
- `passive` — has `effect` (string description), optional `stat_bonus`, trigger conditions
- `stat` — has `stats` dict, appears only at L5–L10

**Elements:** fire, water, plant, thunder, metal, stone, light, shadow, void, chaos, physical

**Targets:** single, all_enemies, self, single_ally, all_allies

**Branches and their themes:**
| Branch | Primary stats | Theme |
|---|---|---|
| North | INT, SPR | Ice/water tank + control |
| NorthEast | STR, DEF | Thunder/metal fighter |
| East | INT, LCK | Fire/light mage |
| SouthEast | STR, DEF | Fire/physical berserker |
| South | AGI, INT | Shadow/bleed rogue |
| SouthWest | INT, LCK | Void/chaos caster |
| West | SPR, INT | Water healer/support |
| NorthWest | DEF, STR | Plant/stone tank |

---

## Character Stats

### Base Stats (set at creation via DEFAULT_STATS)

| Stat | Default | Type | Notes |
|---|---|---|---|
| hp | 100 | flat int | Max HP |
| mana | 50 | flat int | Max MP |
| str | 10 | flat int | Physical damage scaling |
| agi | 10 | flat int | Speed/dagger scaling |
| int | 10 | flat int | Magic damage scaling |
| spr | 10 | flat int | Healing scaling |
| def | 10 | flat int | Damage reduction (flat subtraction) |
| lck | 10 | flat int | Luck (future use) |
| spd | 10 | flat int | ATB fill speed |
| crit_chance | 0.05 | float (0–1) | 5% base |
| crit_damage | 1.0 | float multiplier | Final damage * (1 + crit_damage) |
| precision | 1.0 | float (0–1) | Hit chance |
| dodge | 0.02 | float (0–1) | Dodge chance |
| block | 0.05 | float (0–1) | Block chance (negates all damage) |
| parry | 0.05 | float (0–1) | Parry chance (negates all damage) |
| resistance | 0.10 | float (0–1) | Magic damage reduction % |
| hp_regen | 0 | flat int | HP restored per turn |
| mana_regen | 7 | flat int | MP restored per turn |

### Stat Point Budget (at creation and level-up)

3 points per level-up. Costs from `STAT_COST`:
- HP or Mana: 10 per point
- Flat stats (STR, AGI, INT, SPR, DEF, LCK, SPD): 1 per point
- Crit chance, dodge, parry, block, resistance: varies (see STAT_COST in character_create.gd)

### Combat Formulas

**Hit chance:** `clamp(attacker.precision - target.dodge, 0.05, 1.0)`

**Block/Parry:** checked after hit connects, completely negates damage.

**Base damage:** `randi_range(weapon.min, weapon.max) + stat_bonus - effective_def`
- `effective_def = int(target.def * (1.0 - weapon.def_pierce))`
- Minimum damage: 1

**Crit:** `final_dmg = int(raw_dmg * (1.0 + crit_damage))` if `randf() < crit_chance`

---

## Helper Scripts

### skill_circle.gd (`scripts/ui/skill_circle.gd`)
Small visual component — draws a circle icon for skill cards in CharacterCreate. Has a `set_filled(bool)` method that toggles selected state.

### slice_card.gd (`scripts/ui/slice_card.gd`)
Clickable branch selection card used in CharacterCreate. Emits `slice_selected(branch_name: String)` signal when clicked. Has `deselect()` to reset visual state.
