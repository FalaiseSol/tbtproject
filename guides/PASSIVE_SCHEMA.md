# TBT — Passive Ability Schema (Combat Reference)

This document defines the structured data format for passives in preparation for battle system development. The `"effect"` string in branch_data.gd remains for **display only** — all combat logic lives in the structured fields defined here.

## Design influences

- **Dota 2 DataDriven** — event → modifier → effect chain, data-only, no code per ability
- **Unreal GAS** — tag-based conditions, duration policies, trigger events
- **ModiBuff** — revertible stats, stacking rules, zero-GC modifier pooling
- Key insight: passives are just "on X, if Y, do Z for N duration." Everything maps to that.

---

## Schema

```gdscript
{
    # Required (already in branch_data.gd)
    "type": "passive",
    "name": "Shadow Veil",
    "element": "shadow",
    "effect": "+10% Dodge. On dodge: +5% Crit on next attack.",  # display only

    # --- STRUCTURED COMBAT DATA (to be added) ---

    # Permanent stat bonuses applied when this passive is learned.
    # Applied once at learn time, added to character base stats.
    "stat_bonus": {
        "dodge": 0.10
    },

    # Triggered effects — array because a passive can have multiple triggers.
    # Each trigger is independent.
    "triggers": [
        {
            # When does this fire?
            # Events: "on_dodge", "on_crit", "on_kill", "on_hit_taken",
            #         "on_attack", "on_cast", "on_turn_start", "on_turn_end",
            #         "on_heal", "on_death", "on_buff_applied", "on_debuff_applied"
            "on": "on_dodge",

            # Optional condition before firing (omit = always fires)
            # Types: "always", "hp_below", "hp_above", "has_tag", "missing_tag",
            #        "target_has_debuff", "weapon_type"
            "condition": { "type": "always" },

            # What happens when this fires
            "effect": {
                # Types: "grant_buff", "stat_modify", "apply_debuff",
                #        "deal_damage", "heal", "reduce_cooldown"
                "type": "grant_buff",
                "target": "self",  # "self", "attacker", "target", "all_allies", "all_enemies"

                # Buff definition (used when type = "grant_buff")
                "buff": {
                    "stat": "crit_chance",
                    "value": 0.05,
                    "op": "add",  # "add", "multiply", "set"

                    # Duration types:
                    #   "next_attack"  — consumed on the character's next offensive action
                    #   "next_hit"     — consumed when they take the next hit
                    #   "turns:N"      — lasts N turns (counted at turn_end)
                    #   "permanent"    — until removed explicitly
                    #   "battle"       — until end of battle
                    "duration": "next_attack",

                    # Stacking: "refresh" = reset duration, "stack" = accumulate, "ignore" = no-op if active
                    "stacking": "refresh"
                }
            }
        }
    ]
}
```

---

## All passives mapped

### North

**Cold Skin**
```gdscript
"stat_bonus": { "resistance": 0.10 },
"triggers": [
    {
        "on": "on_hit_taken",
        "condition": { "type": "damage_element", "element": "water" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "resistance", "value": 0.0, "op": "add" }
        # Cold immunity = 100% resistance to water. Handled as: resistance vs water = 1.0 override.
        # Simplest approach: add tag "immune_water" and let damage calc check tags.
    }
]
# Implementation note: "Cold immunity" is best handled as a tag: grant_tag "immune:water"
```

**Frostbitten**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Ice Lance" },
        "effect": {
            "type": "apply_debuff",
            "target": "target",
            "debuff": { "stat": "spd", "value": -3, "op": "add", "duration": "turns:2", "stacking": "refresh" }
        }
    }
]
```

---

### NorthEast

**Iron Body**
```gdscript
"stat_bonus": { "def": 12 },
"triggers": [
    {
        "on": "on_hit_taken",
        "condition": { "type": "damage_type", "value": "physical" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "damage_taken_flat_mult", "value": -0.05, "op": "add", "duration": "permanent" }
        # "damage_taken_flat_mult" = a combat multiplier applied in damage calc. Needs defining in battle system.
    }
]
```

**Conductor**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_element", "value": "thunder" },
        "effect": { "type": "set_flag", "flag": "ignore_resistance_pct", "value": 0.30, "duration": "next_attack" }
    },
    {
        "on": "on_crit",
        "condition": { "type": "skill_element", "value": "thunder" },
        "effect": {
            "type": "apply_debuff",
            "target": "target",
            "debuff": { "id": "stun", "duration": "turns:1", "stacking": "ignore", "chance": 1.0 }
        }
    }
]
```

**Raging Steel**
```gdscript
"stat_bonus": { "str": 5 },
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "and", "conditions": [
            { "type": "skill_element", "value": "metal" },
            { "type": "hp_above", "value": 0.50 }
        ]},
        "effect": { "type": "stat_modify", "target": "self", "stat": "damage_dealt_mult", "value": 0.20, "op": "add", "duration": "next_attack" }
    }
]
```

---

### East

**Bright Eyes**
```gdscript
"stat_bonus": { "precision": 0.10 },
"triggers": [
    {
        "on": "on_crit",
        "condition": { "type": "always" },
        "effect": {
            "type": "apply_debuff",
            "target": "target",
            "debuff": { "stat": "precision", "value": -0.15, "op": "add", "duration": "turns:1", "stacking": "refresh" }
        }
    }
]
```

**Kindle**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Fireball" },
        "effect": {
            "type": "apply_debuff",
            "target": "target",
            "debuff": { "id": "burn", "value": 3, "duration": "turns:3", "stacking": "refresh" }
        }
    }
]
```

**Afterburn**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_debuff_expired",
        "condition": { "type": "debuff_id", "value": "burn" },
        "effect": { "type": "deal_damage", "target": "target", "element": "fire", "value": 6, "formula": "flat" }
    },
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Kindle" },
        "effect": { "type": "modify_debuff", "debuff_id": "burn", "stat": "duration", "value": 1, "op": "add" }
        # Extends burn duration when Kindle is applied
    }
]
```

---

### South

**Shadow Veil**
```gdscript
"stat_bonus": { "dodge": 0.10 },
"triggers": [
    {
        "on": "on_dodge",
        "condition": { "type": "always" },
        "effect": {
            "type": "grant_buff",
            "target": "self",
            "buff": { "stat": "crit_chance", "value": 0.05, "op": "add", "duration": "next_attack", "stacking": "refresh" }
        }
    }
]
```

**Relentless**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "and", "conditions": [
            { "type": "skill_name", "value": "Blood Strike" },
            { "type": "target_has_debuff", "value": "bleed" }
        ]},
        "effect": { "type": "reduce_cooldown", "target": "self", "skill": "Blood Strike", "value": 2 }
    }
]
# HP cost reduction (3 instead of 6): stored as passive stat_bonus: { "blood_strike_hp_cost": -3 }
# Battle system checks passive list for skill-specific cost overrides.
```

---

### SouthEast

**Thick Hide** — no triggers, pure stat bonus
```gdscript
"stat_bonus": { "def": 15 },
"triggers": [
    {
        "on": "on_hit_taken",
        "condition": { "type": "damage_type", "value": "physical" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "damage_taken_flat_mult", "value": -0.08, "op": "add", "duration": "permanent" }
    }
]
```

**Bloodlust**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_kill",
        "condition": { "type": "always" },
        "effect": { "type": "heal", "target": "self", "value": 15, "formula": "flat" }
    },
    {
        "on": "on_kill",
        "condition": { "type": "always" },
        "effect": {
            "type": "grant_buff",
            "target": "self",
            "buff": { "stat": "str", "value": 5, "op": "add", "duration": "battle", "stacking": "stack" }
        }
    }
]
```

**Berserker**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_turn_start",
        "condition": { "type": "hp_below", "value": 0.50 },
        "effect": {
            "type": "grant_buff",
            "target": "self",
            "buff": { "id": "berserker_buff", "stats": { "str_mult": 0.15, "crit_chance": 0.10 }, "duration": "turns:1", "stacking": "refresh" }
        }
    }
    # Rechecked every turn start. If HP climbs back above 50%, buff is not refreshed and expires.
]
```

---

### SouthWest

**Void Walker**
```gdscript
"stat_bonus": { "resistance": 0.15 },
"triggers": [],
# Immunity to Slow and Curse = tags: grant_tag ["immune:slow", "immune:curse"] at learn time
"on_learn_tags": ["immune:slow", "immune:curse"]
```

**Chaos Affinity**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_element", "value": "chaos" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "damage_dealt_mult", "value": 0.15, "op": "add", "duration": "next_attack" }
    },
    {
        "on": "on_crit",
        "condition": { "type": "skill_element", "value": "chaos" },
        "effect": { "type": "reset_cooldown", "target": "self", "skill": "last_cast", "chance": 0.20 }
    }
]
```

**Unraveling**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Void Rift" },
        "effect": {
            "type": "apply_debuff",
            "target": "target",
            "debuff": { "stat": "resistance", "value": -0.10, "op": "add", "duration": "turns:3", "stacking": "stack" }
        }
    }
]
```

---

### West

**Flowing Spirit**
```gdscript
"stat_bonus": { "spr": 10 },
"triggers": [
    {
        "on": "on_heal",
        "condition": { "type": "always" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "heal_mult", "value": 0.10, "op": "add", "duration": "permanent" }
        # heal_mult = battle system multiplier on all outgoing heals
    }
]
```

**Deep Currents**
```gdscript
"stat_bonus": { "spr": 5 },
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_element", "value": "water" },
        "effect": { "type": "restore_resource", "target": "self", "resource": "mana", "value": 2 }
    }
]
```

**Aqua Shield**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_heal",
        "condition": { "type": "target_is", "value": "ally" },
        "effect": {
            "type": "grant_buff",
            "target": "heal_target",
            "buff": { "stat": "resistance", "value": 0.10, "op": "add", "duration": "turns:2", "stacking": "refresh" }
        }
    }
]
```

---

### NorthWest

**Bark Skin**
```gdscript
"stat_bonus": { "def": 12, "block": 0.05 },
"triggers": [
    {
        "on": "on_hit_taken",
        "condition": { "type": "damage_type", "value": "physical" },
        "effect": { "type": "stat_modify", "target": "self", "stat": "damage_taken_flat_mult", "value": -0.05, "op": "add", "duration": "permanent" }
    }
]
```

**Overgrowth**
```gdscript
"stat_bonus": {},
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Vine Whip" },
        "effect": { "type": "modify_debuff", "debuff_id": "root", "stat": "duration", "value": 1, "op": "add" }
    },
    {
        "on": "on_cast",
        "condition": { "type": "skill_name", "value": "Vine Whip" },
        "effect": {
            "type": "apply_debuff",
            "target": "adjacent_enemy",
            "chance": 0.20,
            "debuff": { "id": "root", "duration": "turns:1" }
        }
    }
]
```

**Rooted**
```gdscript
"stat_bonus": { "hp": 15, "resistance": 0.05 },
"triggers": [
    {
        "on": "on_cast",
        "condition": { "type": "skill_element", "value": "stone" },
        "effect": { "type": "set_flag", "flag": "ignore_def_pct", "value": 0.15, "duration": "next_attack" }
    }
]
```

---

## Event reference (complete list for battle system)

| Event | Fires when |
|---|---|
| `on_turn_start` | At the start of this character's turn |
| `on_turn_end` | At the end of this character's turn |
| `on_attack` | This character makes any offensive action |
| `on_cast` | This character uses a skill (with filtering by name/element) |
| `on_hit` | This character's attack lands (not dodged, not missed) |
| `on_crit` | This character lands a critical hit |
| `on_miss` | This character's attack misses |
| `on_kill` | This character's action kills a target |
| `on_hit_taken` | This character is hit (after dodge/block check) |
| `on_dodge` | This character successfully dodges an attack |
| `on_block` | This character successfully blocks an attack |
| `on_parry` | This character successfully parries an attack |
| `on_heal` | This character heals an ally (or self) |
| `on_death` | This character's HP reaches 0 |
| `on_debuff_applied` | A debuff is applied to any target via this character |
| `on_debuff_expired` | A debuff expires on any target (with condition filter) |
| `on_buff_applied` | A buff is applied to this character |

## Condition types

| Type | Checks |
|---|---|
| `always` | No check, always fires |
| `hp_below` | Caster HP% < value |
| `hp_above` | Caster HP% > value |
| `skill_name` | The cast skill's name matches |
| `skill_element` | The cast skill's element matches |
| `damage_type` | physical / elemental |
| `damage_element` | Specific element of incoming hit |
| `target_has_debuff` | Target currently has debuff by id |
| `target_is` | ally / enemy / self |
| `has_tag` | Caster has a gameplay tag |
| `missing_tag` | Caster does not have a tag |
| `and` | All sub-conditions must pass |
| `or` | Any sub-condition must pass |

## Duration types

| Value | Meaning |
|---|---|
| `permanent` | Until battle ends or removed |
| `battle` | Removed at end of battle |
| `turns:N` | N full turns (decremented at turn_end) |
| `next_attack` | Consumed on next offensive action |
| `next_hit` | Consumed on next hit taken |

## Stacking rules

| Rule | Behavior |
|---|---|
| `refresh` | Reset duration, keep single stack |
| `stack` | Accumulate (value multiplies by stack count) |
| `ignore` | Do nothing if already active |
| `replace` | Remove existing, apply fresh |

---

## Implementation notes for future battle system

1. **Event bus** — Central `BattleEvents` singleton emits all events. Passive handlers subscribe on character spawn, unsubscribe on death.
2. **Modifier list** — Each character holds an active `modifiers: Array[Dictionary]` that the damage/heal calc iterates over. Passives with `permanent` duration add to this list once at battle start.
3. **Tag system** — Characters hold a `tags: Array[String]` (e.g. `["immune:slow", "buff.crit_up"]`). Conditions check this array. Tags are the lightest data.
4. **`damage_taken_flat_mult`** — Several passives reduce incoming damage by a flat multiplier (Iron Body, Thick Hide, Bark Skin). This needs a dedicated field in the damage formula: `final_damage = raw * (1 - sum(damage_taken_flat_mult modifiers))`.
5. **`heal_mult`** — Same pattern for outgoing heals (Flowing Spirit).
6. **Proc chains** — Afterburn listens to `on_debuff_expired`. The battle system must fire this event when a debuff timer hits 0. One level of chaining is fine; guard against infinite loops with a `processing_event` lock.
7. **Chance-based effects** — `"chance": 0.20` means `randf() < 0.20` at resolution time. Rolled per trigger fire.
8. **Stat caps** — Dodge and Crit Chance must be clamped in the damage calc (recommended max 75% each). Data stays uncapped; the battle system clamps before rolling. Without this a level 10 full-dodge build hits 100%+ and never gets hit.

---

## Weapon schema

Weapons follow the same logic as passives: `stat_bonus` applied at equip time, optional `triggers` for active effects, `notes` for display only. The `stats` dict in `branch_data.gd` IS the `stat_bonus` — no separate field needed, the battle system reads it directly on equip/unequip.

### Equip/unequip contract

When a weapon is equipped, add all `stats` values to the character's active stat block. When unequipped, subtract them. Negative values (e.g. Shield's `spd: -2`) work naturally with the same math.

### All weapons mapped

**Dagger** `slot: main_hand`
```gdscript
"stats": { "agi": 8, "lck": 3 }
"triggers": [
    {
        "on": "on_attack",
        "condition": { "type": "always" },
        "effect": {
            "type": "grant_buff",
            "target": "self",
            "buff": { "stat": "crit_chance", "value": 0.10, "op": "add", "duration": "next_attack", "stacking": "replace" }
        }
    }
]
# +10% Crit on every attack — buff applied before the roll, consumed after.
# net effect: every attack with a Dagger has +10% crit chance baked in.
```

**Broad Sword** `slot: main_hand`
```gdscript
"stats": { "str": 20 }
"triggers": []
# Pure stat stick. No proc. High STR floor makes it attractive for STR-scaling builds
# regardless of branch. "Slow" is a narrative note — actual SPD penalty not in stats,
# so add "spd: -2" here if you want to enforce it mechanically.
```

**Spear** `slot: main_hand`
```gdscript
"stats": { "str": 5, "agi": 5 }
"triggers": [],
"on_attack_flags": { "ignore_def_pct": 0.50 }
# DEF penetration is a per-attack flag, not a stat modifier.
# Battle system checks weapon.on_attack_flags when resolving physical damage.
# "ignore_def_pct": 0.50 means treat target DEF as 50% of its real value for this hit.
```

**Shield** `slot: off_hand`
```gdscript
"stats": { "def": 10, "block": 0.10, "spd": -2 }
"triggers": [],
"on_equip_tags": ["shield_equipped"]
# The "shield_equipped" tag is what the battle system checks to decide
# whether the Block stat is active. Without it, Block is ignored in damage calc.
# Parry is always active regardless of shield.
```

### Skill flags

Some skills carry boolean flags that modify damage resolution. Checked once per cast, not stored as modifiers.

| Flag | Type | Effect |
|---|---|---|
| `ignore_resistance` | `bool` | Target's Resistance stat is treated as 0 for this hit |
| `ignore_def_pct` | `float` | Target's DEF is multiplied by `(1 - value)` for this hit (Spear: 0.50) |

**Skills with flags:**
- `Void Rift` — `ignore_resistance: true`
- `Chaos Lash` — `ignore_resistance: true` (Chaos design rule: chaos damage is absolute, cannot be mitigated by Resistance)

**Battle system rule:** before applying Resistance reduction in damage calc, check `skill.get("ignore_resistance", false)`. If true, skip the resistance step entirely.

---

### Implementation notes for weapons

- **Equip resolution order:** apply `stats` first, then `on_equip_tags`, then register `triggers`.
- **Dual wield / off-hand:** currently only Shield is off-hand. If future weapons occupy off-hand, the same schema applies — just a different slot string.
- **`on_attack_flags`** (Spear): a separate dict evaluated once per attack during damage resolution, distinct from persistent `modifiers`. Cleaner than a permanent modifier that says "ignore 50% DEF always."
- **Broad Sword SPD penalty:** currently only in `notes`. Add `"spd": -2` to its `stats` dict if you decide to enforce it mechanically — the equip/unequip system handles it automatically then.
