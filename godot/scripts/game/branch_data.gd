extends Node

# Node types: "skill", "passive", "stat"
# Skills: { type, name, mp_cost, cooldown, target, formula, threat, element, notes }
# Passives: { type, name, effect, element? }  — element optional, only when thematically elemental
# Stats: { type, stats: { stat_name: value, ... } }
# target: "single", "all_enemies", "self", "single_ally", "all_allies"
# element: "fire","water","plant","thunder","metal","stone","light","shadow","void","chaos","physical"
# formula: string description e.g. "10 + 50% STR"
#
# Level structure (MVP): L1 Skills only | L2-3 Skills+Passives | L4 Skills+Passives (incl. chaos) | L5-10 Stats only
# MP cost scale: small ~12-15 | medium ~25-35 | big/powerful ~45-65
# Stat node budget (3 points per level-up):
#   HP or Mana = 10 per point | small flat stat (STR/AGI/etc) = 1 per point
#   common % stat (crit_chance/dodge/parry/block) = varies per stat (see character_create.gd STAT_COST)
#   niche % stat (crit_damage/resistance) = 0.20 solo or 0.15 in combo — worth the investment

# ── DEBUFFS ───────────────────────────────────────────────────────────────────
# Each debuff: { id, name, type, stat, value, op, duration_type, default_duration, tick_element?, tick_value?, notes }
# type: "stat_mod" | "dot" | "action_loss" | "damage_amp" | "compound" (stat_mod + dot)
# op: "add" (flat delta) | "multiply" (% of current)
# duration_type: "turns" | "hits" (consumed after N hits taken)
const DEBUFFS = {
	"bleed": {
		"id": "bleed", "name": "Bleed", "type": "dot",
		"tick_element": "physical", "tick_value": 3,
		"default_duration": 3, "duration_type": "turns",
		"notes": "Physical DoT. Stacks by default — each application is independent."
	},
	"burn": {
		"id": "burn", "name": "Burn", "type": "dot",
		"tick_element": "fire", "tick_value": 3,
		"default_duration": 3, "duration_type": "turns",
		"notes": "Fire DoT. Refreshes on reapply unless Afterburn passive extends it."
	},
	"poison": {
		"id": "poison", "name": "Poison", "type": "dot",
		"tick_element": "plant", "tick_value": 4,
		"default_duration": 4, "duration_type": "turns",
		"notes": "Plant DoT. Applied by Spore Cloud."
	},
	"slow": {
		"id": "slow", "name": "Slow", "type": "stat_mod",
		"stat": "spd", "value": -3, "op": "add",
		"default_duration": 2, "duration_type": "turns",
		"notes": "SPD penalty. Value varies by source — default -3."
	},
	"curse": {
		"id": "curse", "name": "Curse", "type": "stat_mod",
		"stat": "damage_dealt_mult", "value": -0.15, "op": "add",
		"default_duration": 3, "duration_type": "turns",
		"notes": "Target deals 15% less damage. Applied by Shadow Collapse."
	},
	"blind": {
		"id": "blind", "name": "Blind", "type": "stat_mod",
		"stat": "precision", "value": -0.15, "op": "add",
		"default_duration": 1, "duration_type": "turns",
		"notes": "Precision penalty. Value varies by source — default -15%."
	},
	"stun": {
		"id": "stun", "name": "Stun", "type": "action_loss",
		"actions_lost": 1,
		"default_duration": 1, "duration_type": "turns",
		"notes": "Target loses 1 action. Applied by Conductor thunder crit."
	},
	"root": {
		"id": "root", "name": "Root", "type": "action_loss",
		"actions_lost": 1,
		"default_duration": 1, "duration_type": "turns",
		"notes": "Target loses 1 action (movement-type lock). Applied by Vine Whip, Petrify."
	},
	"freeze": {
		"id": "freeze", "name": "Freeze", "type": "action_loss",
		"actions_lost": 1,
		"default_duration": 1, "duration_type": "turns",
		"notes": "Target loses 1 action. Applied by Avalanche."
	},
	"petrify": {
		"id": "petrify", "name": "Petrify", "type": "stat_mod",
		"stat": "spd", "value": -3, "op": "add",
		"default_duration": 2, "duration_type": "turns",
		"notes": "SPD penalty. Applied by Stone Blood passive proc."
	},
	"def_break": {
		"id": "def_break", "name": "DEF Break", "type": "stat_mod",
		"stat": "def", "value": -8, "op": "add",
		"default_duration": 3, "duration_type": "turns",
		"notes": "DEF reduction. Applied by Dark Pulse curse variant and Chaos Quake."
	},
	"damage_amp": {
		"id": "damage_amp", "name": "Damage Amp", "type": "damage_amp",
		"value": 0.20, "op": "multiply",
		"default_duration": 3, "duration_type": "turns",
		"notes": "Target takes X% more damage from all sources. Value varies by source."
	},
	"magnetized": {
		"id": "magnetized", "name": "Magnetized", "type": "stat_mod",
		"stat": "def", "value": -5, "op": "add",
		"default_duration": 3, "duration_type": "turns",
		"notes": "DEF reduction. Applied by Magnetize."
	},
}

# ── BUFFS ──────────────────────────────────────────────────────────────────────
# Each buff: { id, name, stat, value, op, duration_type, default_duration, stacking, notes }
# stacking: "refresh" | "stack" | "ignore"
const BUFFS = {
	"war_cry_str": {
		"id": "war_cry_str", "name": "War Cry", "stat": "str", "value": 0.15, "op": "multiply",
		"default_duration": 2, "duration_type": "turns", "stacking": "refresh",
		"notes": "+15% STR for 2 turns. Applied by War Cry."
	},
	"shadow_veil_crit": {
		"id": "shadow_veil_crit", "name": "Veil Crit", "stat": "crit_chance", "value": 0.05, "op": "add",
		"default_duration": 1, "duration_type": "hits", "stacking": "refresh",
		"notes": "+5% Crit on next attack. Granted on dodge by Shadow Veil passive."
	},
	"storm_forged_agi": {
		"id": "storm_forged_agi", "name": "Storm Forged", "stat": "agi", "value": 3, "op": "add",
		"default_duration": 3, "duration_type": "turns", "stacking": "stack", "max_stacks": 3,
		"notes": "+3 AGI per thunder crit, up to 3 stacks. Applied by Storm Forged passive."
	},
	"bloodlust_str": {
		"id": "bloodlust_str", "name": "Bloodlust", "stat": "str", "value": 5, "op": "add",
		"default_duration": -1, "duration_type": "battle", "stacking": "stack",
		"notes": "+5 STR on kill, lasts rest of battle. Applied by Bloodlust passive."
	},
	"berserker": {
		"id": "berserker", "name": "Berserker",
		"stats": { "str": 0.15, "crit_chance": 0.10 }, "op": "multiply",
		"default_duration": 1, "duration_type": "turns", "stacking": "refresh",
		"notes": "+15% STR and +10% Crit when HP < 50%. Rechecked each turn start."
	},
	"undying_rage": {
		"id": "undying_rage", "name": "Undying Rage",
		"stats": { "str": 0.20, "crit_chance": 0.10 }, "op": "multiply",
		"default_duration": 3, "duration_type": "turns", "stacking": "ignore", "once_per_battle": true,
		"notes": "+20% STR and +10% Crit when HP < 25%. Once per battle."
	},
	"glacial_shell": {
		"id": "glacial_shell", "name": "Glacial Shell", "stat": "damage_taken_flat_mult", "value": -0.25, "op": "add",
		"default_duration": 2, "duration_type": "turns", "stacking": "refresh",
		"notes": "Reduce incoming damage by 25% for 2 turns. Applied by Glacial Shell skill."
	},
	"thorn_wall": {
		"id": "thorn_wall", "name": "Thorn Wall", "stat": "reflect_dmg", "value": 4, "op": "add",
		"reflect_element": "plant",
		"default_duration": 3, "duration_type": "turns", "stacking": "refresh",
		"notes": "Reflect 4 plant dmg to attackers. Applied by Thorn Wall skill."
	},
	"aqua_shield_resist": {
		"id": "aqua_shield_resist", "name": "Aqua Shield", "stat": "resistance", "value": 0.10, "op": "add",
		"default_duration": 2, "duration_type": "turns", "stacking": "refresh",
		"notes": "+10% Resistance for 2 turns. Granted to healed ally by Aqua Shield passive."
	},
	"dagger_crit": {
		"id": "dagger_crit", "name": "Dagger Edge", "stat": "crit_chance", "value": 0.10, "op": "add",
		"default_duration": 1, "duration_type": "hits", "stacking": "replace",
		"notes": "+10% Crit on next attack. Applied every attack by Dagger weapon."
	},
}

const WEAPONS = [
	{ "id": "dagger",      "name": "Dagger",       "slot": "main_hand", "stats": { "agi": 8, "lck": 3 }, "notes": "High AGI. +10% Crit Chance on attacks." },
	{ "id": "broad_sword", "name": "Broad Sword", "slot": "main_hand", "stats": { "str": 20 },           "notes": "Slow, very high physical damage." },
	{ "id": "spear",       "name": "Spear",        "slot": "main_hand", "stats": { "str": 5, "agi": 5 }, "notes": "Ignore 50% DEF on basic attack and physical skills." },
	{ "id": "shield",      "name": "Shield",       "slot": "off_hand",  "stats": { "def": 10, "block": 0.10, "spd": -2 }, "notes": "Enables Block stat. +10% Block. -2 SPD." },
]

const BRANCHES = {

# ── NORTH ─────────────────────────────────────────────────────────────────────
"North": [
# L1 — Skills only
[
	{ "type": "skill", "name": "Ice Lance",     "mp_cost": 15, "cooldown": 0, "target": "single",      "formula": "8 + 40% INT",  "element": "water",    "threat": 0,  "notes": "Basic ice projectile." },
	{ "type": "skill", "name": "Frost Taunt",   "mp_cost": 12, "cooldown": 2, "target": "self",        "formula": "",             "element": "physical", "threat": 50, "threat_self": 50, "notes": "Taunt +50%. Draw enemy attention." },
	{ "type": "skill", "name": "Frozen Strike", "mp_cost": 10, "cooldown": 0, "target": "single",      "formula": "6 + 60% STR",  "element": "physical", "threat": 10, "notes": "Physical hit. Minor threat." },
],
# L2 — Skills + Passives
[
	{ "type": "skill",   "name": "Blizzard",  "mp_cost": 30, "cooldown": 3, "target": "all_enemies", "formula": "6 + 30% INT", "element": "water", "threat": 5, "applies_debuff": [], "notes": "Hits all enemies." },
	{ "type": "passive", "name": "Cold Skin", "element": "water",  "effect": "+10% Resistance to Water damage. Cold immunity.", "stat_bonus": { "resistance": 0.10 }, "on_learn_tags": ["immune:water"] },
	{ "type": "passive", "name": "Endurance", "effect": "+20 HP. MP costs of physical skills reduced by 3.", "stat_bonus": { "hp": 20 }, "mp_cost_reduction": { "skill_tag": "physical", "value": 3 } },
],
# L3 — Skills + Passives
[
	{ "type": "skill",   "name": "Glacial Shell", "mp_cost": 25, "cooldown": 3, "target": "self",   "formula": "",             "element": "water", "threat": 0, "applies_buff": ["glacial_shell"], "notes": "Reduce incoming damage by 25% for 2 turns." },
	{ "type": "passive", "name": "Frostbitten",   "element": "water",   "effect": "Ice Lance slows target: -3 SPD for 2 turns.", "on_skill": "Ice Lance", "applies_debuff": [{ "id": "slow", "value": -3, "duration": 2 }] },
	{ "type": "skill",   "name": "Shatter",       "mp_cost": 45, "cooldown": 3, "target": "single", "formula": "18 + 55% INT", "element": "water", "threat": 0, "bonus_if": { "target_hit_by": "Frozen Strike", "last_turns": 1, "dmg_mult": 0.30 }, "notes": "High damage. +30% if target hit by Frozen Strike last turn." },
],
# L4 — Skill/Passive choice
[
	{ "type": "skill",   "name": "Avalanche",     "mp_cost": 40, "cooldown": 4, "target": "all_enemies", "formula": "10 + 45% INT", "element": "water",    "threat": 0, "applies_debuff": [{ "id": "freeze", "duration": 1 }], "notes": "Ice AoE. Freeze: target loses 1 action." },
	{ "type": "passive", "name": "Arctic Soul",   "element": "water", "effect": "+10% Resistance to all elements. Cold aura: enemies take 1 water dmg at turn start." },
	{ "type": "skill",   "name": "Null Lance",    "mp_cost": 35, "cooldown": 3, "target": "single",      "formula": "14 + 55% INT", "element": "chaos",    "threat": 0, "ignore_resistance": true, "notes": "Cannot be resisted." },
],
# L5-10 — Stats only (3 points each; HP/Mana=10pp, flat=1pp, %=0.05pp)
[{ "type": "stat", "stats": { "mana": 10, "int": 1, "spr": 1 } },{ "type": "stat", "stats": { "hp": 10, "spr": 2 } },           { "type": "stat", "stats": { "int": 3 } }],
[{ "type": "stat", "stats": { "hp": 10, "int": 2 } },             { "type": "stat", "stats": { "dodge": 0.05, "int": 1 } },      { "type": "stat", "stats": { "int": 2, "spr": 2 } }],
[{ "type": "stat", "stats": { "int": 3 } },                       { "type": "stat", "stats": { "mana": 10, "int": 2 } },         { "type": "stat", "stats": { "resistance": 0.15, "int": 1 } }],
[{ "type": "stat", "stats": { "hp": 20, "int": 1 } },             { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "spr": 2, "def": 1 } }],
[{ "type": "stat", "stats": { "crit_chance": 0.05, "int": 1 } },  { "type": "stat", "stats": { "hp": 10, "mana": 10 } },        { "type": "stat", "stats": { "int": 2, "lck": 1 } }],
[{ "type": "stat", "stats": { "hp": 20, "spr": 1 } },             { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "mana": 20, "spr": 1 } }],
],

# ── NORTHEAST ─────────────────────────────────────────────────────────────────
"NorthEast": [
# L1
[
	{ "type": "skill", "name": "Thunder Jab", "mp_cost": 15, "cooldown": 0, "target": "single",      "formula": "7 + 50% AGI",  "element": "thunder",  "threat": 0,  "notes": "Fast thunder strike." },
	{ "type": "skill", "name": "Metal Crush", "mp_cost": 12, "cooldown": 1, "target": "single",      "formula": "10 + 70% STR", "element": "metal",    "threat": 15, "notes": "Ignores DEF." },
	{ "type": "skill", "name": "War Cry",     "mp_cost": 12, "cooldown": 3, "target": "self",        "formula": "",             "element": "physical", "threat": 40, "threat_self": 40, "applies_buff": ["war_cry_str"], "notes": "Taunt +40%. +15% STR for 2 turns." },
],
# L2
[
	{ "type": "skill",   "name": "Chain Lightning", "mp_cost": 30, "cooldown": 3, "target": "all_enemies", "formula": "5 + 25% INT", "element": "thunder", "threat": 10, "notes": "Bounces to all enemies." },
	{ "type": "passive", "name": "Iron Body",        "element": "metal",   "effect": "+12 DEF. Physical hits taken reduced by 5%.", "stat_bonus": { "def": 12 }, "damage_taken_reduction": { "type": "physical", "value": 0.05 } },
	{ "type": "passive", "name": "Conductor",        "element": "thunder", "effect": "Thunder skills ignore 30% Resistance. Thunder crits stun for 1 turn.", "on_element": "thunder", "ignore_resistance_pct": 0.30, "on_crit": true, "applies_debuff": [{ "id": "stun", "duration": 1 }] },
],
# L3
[
	{ "type": "skill",   "name": "Overcharge",   "mp_cost": 50, "cooldown": 4, "target": "single",      "formula": "22 + 65% INT", "element": "thunder", "threat": 0,  "notes": "High single-target thunder." },
	{ "type": "passive", "name": "Raging Steel", "element": "metal",   "effect": "Metal skills deal +20% damage when HP > 50%. +5 STR permanently.", "stat_bonus": { "str": 5 }, "on_element": "metal", "condition": { "hp_above": 0.50 }, "damage_dealt_bonus": 0.20 },
	{ "type": "skill",   "name": "Ground Slam",  "mp_cost": 18, "cooldown": 2, "target": "all_enemies", "formula": "8 + 40% STR", "element": "metal",   "threat": 20, "notes": "Physical AoE. High threat." },
],
# L4
[
	{ "type": "skill",   "name": "Magnetize",      "mp_cost": 30, "cooldown": 3, "target": "single",      "formula": "12 + 50% STR", "element": "metal",    "threat": 0, "applies_debuff": [{ "id": "magnetized", "duration": 3 }], "notes": "Metal damage. Target: -5 DEF for 3 turns." },
	{ "type": "passive", "name": "Storm Forged",   "element": "thunder", "effect": "Thunder crits grant +3 AGI for 3 turns, stacking up to 3 times." },
	{ "type": "skill",   "name": "Chaos Strike",   "mp_cost": 35, "cooldown": 3, "target": "single",      "formula": "13 + 60% STR", "element": "chaos",    "threat": 0, "ignore_resistance": true, "notes": "Cannot be resisted." },
],
# L5-10
[{ "type": "stat", "stats": { "str": 3 } },                       { "type": "stat", "stats": { "hp": 10, "str": 2 } },           { "type": "stat", "stats": { "def": 3 } }],
[{ "type": "stat", "stats": { "hp": 20, "str": 1 } },             { "type": "stat", "stats": { "str": 3 } },                    { "type": "stat", "stats": { "parry": 0.05, "def": 1 } }],
[{ "type": "stat", "stats": { "crit_damage": 0.20, "str": 1 } },  { "type": "stat", "stats": { "str": 2, "def": 1 } },          { "type": "stat", "stats": { "hp": 20, "str": 1 } }],
[{ "type": "stat", "stats": { "str": 3 } },                       { "type": "stat", "stats": { "hp": 20 } },                    { "type": "stat", "stats": { "def": 3 } }],
[{ "type": "stat", "stats": { "crit_chance": 0.05, "str": 1 } },  { "type": "stat", "stats": { "str": 2, "agi": 1 } },          { "type": "stat", "stats": { "hp": 20, "def": 1 } }],
[{ "type": "stat", "stats": { "str": 3 } },                       { "type": "stat", "stats": { "def": 3 } },                    { "type": "stat", "stats": { "crit_damage": 0.20, "str": 2 } }],
],

# ── EAST ──────────────────────────────────────────────────────────────────────
"East": [
# L1
[
	{ "type": "skill", "name": "Fireball",      "mp_cost": 15, "cooldown": 1, "target": "single", "formula": "9 + 55% INT",  "element": "fire",  "threat": 0,  "notes": "Standard fire projectile." },
	{ "type": "skill", "name": "Sunstrike",     "mp_cost": 20, "cooldown": 2, "target": "single", "formula": "11 + 50% INT", "element": "light", "threat": 0,  "crit_bonus_this_cast": 0.05, "notes": "Light damage. +5% crit this cast." },
	{ "type": "skill", "name": "Blazing Taunt", "mp_cost": 12, "cooldown": 3, "target": "self",   "formula": "",             "element": "fire",  "threat": 45, "threat_self": 45, "attacker_takes_dmg": { "value": 3, "element": "fire" }, "notes": "Taunt +45%. Attacker takes 3 fire dmg on hit." },
],
# L2
[
	{ "type": "skill",   "name": "Flame Burst", "mp_cost": 30, "cooldown": 3, "target": "all_enemies", "formula": "7 + 35% INT", "element": "fire", "threat": 8, "notes": "AoE fire." },
	{ "type": "passive", "name": "Bright Eyes", "element": "light", "effect": "+10% Precision. Crits apply Blind: -15% Precision for 1 turn.", "stat_bonus": { "precision": 0.10 }, "on_crit": true, "applies_debuff": [{ "id": "blind", "value": -0.15, "duration": 1 }] },
	{ "type": "passive", "name": "Kindle",       "element": "fire",  "effect": "Fireball applies Burn: 3 fire dmg/turn for 3 turns.", "on_skill": "Fireball", "applies_debuff": [{ "id": "burn", "duration": 3 }] },
],
# L3
[
	{ "type": "skill",   "name": "Solar Flare", "mp_cost": 45, "cooldown": 4, "target": "all_enemies", "formula": "8 + 40% INT", "element": "light", "threat": 5, "applies_debuff": [{ "id": "blind", "value": -0.15, "duration": 2 }], "notes": "Blinds all enemies: -15% Precision for 2 turns." },
	{ "type": "passive", "name": "Afterburn",   "element": "fire",  "effect": "When Burn expires, deal 6 bonus fire damage. Burn duration +1.", "on_debuff_expired": "burn", "deal_damage": { "value": 6, "element": "fire" }, "modify_debuff": { "id": "burn", "duration_bonus": 1 } },
	{ "type": "skill",   "name": "Ignite",      "mp_cost": 15, "cooldown": 2, "target": "single",      "formula": "4 + 20% INT", "element": "fire",  "threat": 0, "applies_debuff": [{ "id": "burn", "duration": 4 }], "notes": "Low damage. Burn for 4 turns." },
],
# L4
[
	{ "type": "skill",   "name": "Pyre",           "mp_cost": 45, "cooldown": 4, "target": "single",      "formula": "16 + 65% INT", "element": "fire",     "threat": 0, "applies_debuff": [{ "id": "burn", "duration": 4 }], "notes": "Heavy fire. Applies Burn for 4 turns." },
	{ "type": "passive", "name": "Blinding Light", "element": "light", "effect": "Light skills have 15% chance to Blind: -20% Precision for 2 turns.", "on_element": "light", "applies_debuff": [{ "id": "blind", "value": -0.20, "duration": 2, "chance": 0.15 }] },
	{ "type": "skill",   "name": "Chaos Ember",    "mp_cost": 35, "cooldown": 3, "target": "single",      "formula": "13 + 55% INT", "element": "chaos",    "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "random", "pool": ["burn", "blind", "slow"], "duration": 2 }], "notes": "Cannot be resisted. Applies random debuff: Burn, Blind, or Slow." },
],
# L5-10
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "mana": 10, "int": 2 } },         { "type": "stat", "stats": { "mana": 10, "int": 2 } }],
[{ "type": "stat", "stats": { "crit_damage": 0.20, "int": 1 } },   { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "mana": 20, "int": 1 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "crit_chance": 0.05, "int": 1 } },{ "type": "stat", "stats": { "int": 3 } }],
[{ "type": "stat", "stats": { "hp": 10, "mana": 10 } },            { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "crit_damage": 0.20, "int": 1 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "int": 2, "lck": 1 } },           { "type": "stat", "stats": { "mana": 20, "lck": 1 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "crit_chance": 0.05, "crit_damage": 0.15 } }, { "type": "stat", "stats": { "int": 2, "lck": 1 } }],
],

# ── SOUTHEAST ─────────────────────────────────────────────────────────────────
"SouthEast": [
# L1
[
	{ "type": "skill", "name": "Scorch",       "mp_cost": 12, "cooldown": 0, "target": "single", "formula": "7 + 45% INT",  "element": "fire",     "threat": 5,  "notes": "Quick fire hit." },
	{ "type": "skill", "name": "Bone Crush",   "mp_cost": 15, "cooldown": 1, "target": "single", "formula": "12 + 80% STR", "element": "physical", "threat": 20, "notes": "Massive physical hit." },
	{ "type": "skill", "name": "Inferno Roar", "mp_cost": 15, "cooldown": 3, "target": "self",   "formula": "",             "element": "fire",     "threat": 60, "threat_self": 60, "notes": "Taunt +60%. Highest base threat." },
],
# L2
[
	{ "type": "skill",   "name": "Magma Fist", "mp_cost": 25, "cooldown": 2, "target": "single", "formula": "10 + 50% STR + 20% INT", "element": "fire", "threat": 10, "notes": "Hybrid physical+fire." },
	{ "type": "passive", "name": "Thick Hide", "effect": "+15 DEF. Reduce physical damage taken by 8%.", "stat_bonus": { "def": 15 }, "damage_taken_reduction": { "type": "physical", "value": 0.08 } },
	{ "type": "passive", "name": "Bloodlust",  "effect": "Killing a target restores 15 HP. +5 STR for the rest of battle.", "on_kill": true, "heal_self": 15, "applies_buff": ["bloodlust_str"] },
],
# L3
[
	{ "type": "skill",   "name": "Volcanic Slam", "mp_cost": 35, "cooldown": 4, "target": "all_enemies", "formula": "9 + 45% STR", "element": "fire",     "threat": 15, "notes": "AoE fire+physical." },
	{ "type": "passive", "name": "Berserker",     "effect": "+15% STR and +10% crit chance when HP < 50%.", "on_turn_start": true, "condition": { "hp_below": 0.50 }, "applies_buff": ["berserker"] },
	{ "type": "skill",   "name": "Cauterize",     "mp_cost": 20, "cooldown": 3, "target": "self",        "formula": "Heal 10 + 40% SPR", "element": "fire", "threat": 0,  "notes": "Self-heal using fire." },
],
# L4
[
	{ "type": "skill",   "name": "Molten Charge",  "mp_cost": 30, "cooldown": 3, "target": "single",      "formula": "15 + 70% STR", "element": "fire",     "threat": 20, "notes": "Charge through enemy. High threat." },
	{ "type": "passive", "name": "Undying Rage",   "effect": "When HP drops below 25%, gain +20% STR and +10% Crit for 3 turns. Once per battle.", "on_hp_threshold": 0.25, "applies_buff": ["undying_rage"] },
	{ "type": "skill",   "name": "Chaos Roar",     "mp_cost": 35, "cooldown": 4, "target": "all_enemies", "formula": "",             "element": "chaos",    "threat": 30, "threat_self": 30, "ignore_resistance": true, "applies_debuff": [{ "id": "damage_amp", "value": 0.15, "duration": 2 }], "notes": "Taunt +30%. All enemies take 15% more damage for 2 turns." },
],
# L5-10
[{ "type": "stat", "stats": { "str": 3 } },                        { "type": "stat", "stats": { "hp": 20, "str": 1 } },           { "type": "stat", "stats": { "hp": 10, "str": 2 } }],
[{ "type": "stat", "stats": { "str": 3 } },                        { "type": "stat", "stats": { "crit_damage": 0.20, "str": 1 } },{ "type": "stat", "stats": { "hp": 20, "str": 1 } }],
[{ "type": "stat", "stats": { "str": 3 } },                        { "type": "stat", "stats": { "def": 3 } },                    { "type": "stat", "stats": { "hp": 10, "str": 2 } }],
[{ "type": "stat", "stats": { "crit_chance": 0.05, "str": 1 } },   { "type": "stat", "stats": { "str": 3 } },                    { "type": "stat", "stats": { "hp": 20, "str": 1 } }],
[{ "type": "stat", "stats": { "str": 3 } },                        { "type": "stat", "stats": { "hp": 20, "str": 1 } },           { "type": "stat", "stats": { "crit_damage": 0.20, "str": 1 } }],
[{ "type": "stat", "stats": { "str": 3 } },                        { "type": "stat", "stats": { "hp": 30 } },                    { "type": "stat", "stats": { "crit_chance": 0.05, "crit_damage": 0.15 } }],
],

# ── SOUTH ─────────────────────────────────────────────────────────────────────
"South": [
# L1
[
	{ "type": "skill", "name": "Shadow Bolt", "mp_cost": 15, "cooldown": 0, "target": "single", "formula": "9 + 50% INT",  "element": "shadow",   "threat": 0, "notes": "Basic shadow projectile." },
	{ "type": "skill", "name": "Blood Strike", "mp_cost": 0, "hp_cost": 6, "cooldown": 1, "target": "single", "formula": "8 + 60% STR",  "element": "physical", "threat": 5, "applies_debuff": [{ "id": "bleed", "duration": 3 }], "notes": "Costs 6 HP. Applies Bleed: 3 dmg/turn for 3 turns." },
	{ "type": "skill", "name": "Death Mark",   "mp_cost": 20,"cooldown": 4, "target": "single", "formula": "",             "element": "shadow",   "threat": 0, "applies_debuff": [{ "id": "damage_amp", "value": 0.20, "duration": 3 }], "notes": "Target takes 20% more damage from all sources for 3 turns." },
],
# L2
[
	{ "type": "skill",   "name": "Hemorrhage",  "mp_cost": 25, "cooldown": 2, "target": "single", "formula": "6 + 30% INT", "element": "shadow", "threat": 0, "applies_debuff": [{ "id": "bleed", "duration": 5 }], "notes": "Applies Bleed for 5 turns." },
	{ "type": "passive", "name": "Shadow Veil", "element": "shadow", "effect": "+10% Dodge. Dodge grants +5% crit chance on your next attack.", "stat_bonus": { "dodge": 0.10 }, "on_dodge": true, "applies_buff": ["shadow_veil_crit"] },
	{ "type": "passive", "name": "Sanguine",    "effect": "Bleed restores 2 HP to you per tick. Bleed damage +1.", "on_bleed_tick": true, "heal_self": 2, "modify_debuff": { "id": "bleed", "tick_value_bonus": 1 } },
],
# L3
[
	{ "type": "skill",   "name": "Dark Pulse",  "mp_cost": 35, "cooldown": 3, "target": "all_enemies", "formula": "6 + 35% INT", "element": "shadow", "threat": 0, "applies_debuff": [{ "id": "def_break", "value": -8, "duration": 3 }], "notes": "AoE. Curse: -8 DEF for 3 turns." },
	{ "type": "passive", "name": "Relentless",  "element": "shadow", "effect": "Blood Strike CD reduced by 2 if target is Bleeding. HP cost reduced to 3.", "on_skill": "Blood Strike", "condition": { "target_has_debuff": "bleed" }, "reduce_cooldown": { "skill": "Blood Strike", "value": 2 }, "skill_hp_cost_override": { "skill": "Blood Strike", "hp_cost": 3 } },
	{ "type": "skill",   "name": "Drain",       "mp_cost": 25, "cooldown": 2, "target": "single",      "formula": "7 + 40% INT", "element": "shadow", "threat": 0, "notes": "Restore HP = 60% of damage dealt." },
],
# L4
[
	{ "type": "skill",   "name": "Soul Rend",      "mp_cost": 40, "cooldown": 3, "target": "single",      "formula": "14 + 55% INT", "element": "shadow",   "threat": 0, "lifesteal": 10, "notes": "Shadow damage. Steal 10 HP from target." },
	{ "type": "passive", "name": "Hemorrhagic",    "element": "shadow", "effect": "Bleed stacks deal +1 damage per stack. Max bleed stacks: 5." },
	{ "type": "skill",   "name": "Chaos Mark",     "mp_cost": 30, "cooldown": 4, "target": "single",      "formula": "",             "element": "chaos",    "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "damage_amp", "value": 0.25, "duration": 3 }], "notes": "Cannot be resisted. Target takes 25% more damage from all sources for 3 turns." },
],
# L5-10
[{ "type": "stat", "stats": { "crit_chance": 0.05, "agi": 1 } },   { "type": "stat", "stats": { "agi": 3 } },                    { "type": "stat", "stats": { "hp": 10, "dodge": 0.05 } }],
[{ "type": "stat", "stats": { "int": 2, "agi": 1 } },              { "type": "stat", "stats": { "crit_damage": 0.20, "agi": 1 } },{ "type": "stat", "stats": { "dodge": 0.05, "int": 1 } }],
[{ "type": "stat", "stats": { "agi": 3 } },                        { "type": "stat", "stats": { "lck": 2, "crit_chance": 0.05 } },{ "type": "stat", "stats": { "int": 3 } }],
[{ "type": "stat", "stats": { "crit_chance": 0.05, "agi": 1 } },   { "type": "stat", "stats": { "agi": 3 } },                    { "type": "stat", "stats": { "dodge": 0.05, "lck": 1 } }],
[{ "type": "stat", "stats": { "crit_damage": 0.20, "agi": 1 } },   { "type": "stat", "stats": { "agi": 3 } },                    { "type": "stat", "stats": { "int": 2, "crit_chance": 0.05 } }],
[{ "type": "stat", "stats": { "agi": 3 } },                        { "type": "stat", "stats": { "crit_chance": 0.05, "crit_damage": 0.15 } }, { "type": "stat", "stats": { "dodge": 0.05, "agi": 1 } }],
],

# ── SOUTHWEST ─────────────────────────────────────────────────────────────────
"SouthWest": [
# L1
[
	{ "type": "skill", "name": "Void Rift",      "mp_cost": 45, "cooldown": 2, "target": "single",      "formula": "12 + 60% INT",           "element": "void",  "threat": 0, "ignore_resistance": true, "notes": "Ignores Resistance." },
	{ "type": "skill", "name": "Chaos Lash",     "mp_cost": 40, "cooldown": 1, "target": "single",      "formula": "8 + 40% INT + 20% LCK",  "element": "chaos", "threat": 0, "ignore_resistance": true, "notes": "Cannot be resisted." },
	{ "type": "skill", "name": "Entropic Wail",  "mp_cost": 55, "cooldown": 4, "target": "all_enemies", "formula": "",                        "element": "void",  "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "slow", "value": -4, "duration": 2 }], "notes": "Slow: -4 SPD for 2 turns to all." },
],
# L2
[
	{ "type": "skill",   "name": "Collapse",       "mp_cost": 50, "cooldown": 4, "target": "single", "formula": "18 + 70% INT", "element": "void", "threat": 0, "ignore_resistance": true, "hp_cost_if_no_mp": 10, "notes": "High void damage. Costs 10 HP if MP insufficient." },
	{ "type": "passive", "name": "Void Walker",    "element": "void",  "effect": "+15% Resistance. Immune to Slow and Curse.", "stat_bonus": { "resistance": 0.15 }, "on_learn_tags": ["immune:slow", "immune:curse"] },
	{ "type": "passive", "name": "Chaos Affinity", "element": "chaos", "effect": "Chaos skills +15% damage. Chaos crits have 20% chance to reset CD.", "on_element": "chaos", "damage_dealt_bonus": 0.15, "on_crit": true, "reset_cooldown": { "skill": "last_cast", "chance": 0.20 } },
],
# L3
[
	{ "type": "skill",   "name": "Shadow Collapse", "mp_cost": 55, "cooldown": 4, "target": "single",      "formula": "16 + 80% INT", "element": "shadow", "threat": 0, "applies_debuff": [{ "id": "curse", "duration": 3 }], "notes": "Curse: target deals 15% less damage for 3 turns." },
	{ "type": "passive", "name": "Unraveling",      "element": "void",  "effect": "Void Rift reduces target Resistance by 10% for 3 turns. Stacks.", "on_skill": "Void Rift", "applies_debuff": [{ "id": "def_break", "stat": "resistance", "value": -0.10, "duration": 3, "stacking": "stack" }] },
	{ "type": "skill",   "name": "Entropy Field",   "mp_cost": 45, "cooldown": 5, "target": "all_enemies", "formula": "5 + 25% INT",  "element": "void",   "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "random", "pool": ["slow", "curse", "def_break"], "duration": 2 }], "notes": "AoE void. Random debuff each hit: Slow, Curse, or -8 DEF." },
],
# L4
[
	{ "type": "skill",   "name": "Void Surge",     "mp_cost": 45, "cooldown": 4, "target": "single",      "formula": "18 + 70% INT", "element": "void",     "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "damage_amp", "value": 0.05, "duration": -1, "duration_type": "battle", "stat": "max_hp_mult" }], "notes": "Ignores Resistance. Reduces target max HP by 5% for battle." },
	{ "type": "passive", "name": "Entropic Grasp", "element": "void", "effect": "Void skills have 20% chance to reduce target CD by 1 on each hit (your next void skill). +5% Resistance.", "stat_bonus": { "resistance": 0.05 }, "on_element": "void", "reduce_target_cd": { "chance": 0.20, "value": 1 } },
	{ "type": "skill",   "name": "Chaos Rift",     "mp_cost": 50, "cooldown": 5, "target": "all_enemies", "formula": "10 + 50% INT", "element": "chaos",    "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "random", "pool": ["slow", "curse", "def_break", "blind", "bleed"], "duration": 2 }], "notes": "Cannot be resisted. AoE. Random debuff on each target." },
],
# L5-10
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "mana": 10, "int": 2 } },         { "type": "stat", "stats": { "mana": 20, "int": 1 } }],
[{ "type": "stat", "stats": { "resistance": 0.15, "int": 2 } },    { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "lck": 3 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "crit_chance": 0.05, "lck": 1 } },{ "type": "stat", "stats": { "mana": 20, "int": 1 } }],
[{ "type": "stat", "stats": { "int": 2, "lck": 1 } },              { "type": "stat", "stats": { "int": 3 } },                    { "type": "stat", "stats": { "resistance": 0.15, "int": 2 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "mana": 20, "lck": 1 } },         { "type": "stat", "stats": { "crit_damage": 0.20, "int": 1 } }],
[{ "type": "stat", "stats": { "int": 3 } },                        { "type": "stat", "stats": { "lck": 3 } },                    { "type": "stat", "stats": { "lck": 2, "crit_chance": 0.05 } }],
],

# ── WEST ──────────────────────────────────────────────────────────────────────
"West": [
# L1
[
	{ "type": "skill", "name": "Tidal Wave", "mp_cost": 25, "cooldown": 2, "target": "all_enemies",  "formula": "6 + 35% INT",      "element": "water", "threat": 0, "notes": "AoE water damage." },
	{ "type": "skill", "name": "Mend",       "mp_cost": 15, "cooldown": 0, "target": "single_ally", "formula": "Heal 10 + 60% SPR", "element": "water", "threat": 5, "notes": "Heal single ally." },
	{ "type": "skill", "name": "Riptide",    "mp_cost": 15, "cooldown": 1, "target": "single",      "formula": "8 + 45% INT",       "element": "water", "threat": 0, "applies_debuff": [{ "id": "slow", "value": -3, "duration": 2 }], "notes": "Water damage. Slow: -3 SPD for 2 turns." },
],
# L2
[
	{ "type": "skill",   "name": "Healing Tide",  "mp_cost": 35, "cooldown": 4, "target": "all_allies", "formula": "Heal 6 + 40% SPR", "element": "water", "threat": 8, "notes": "Heal all allies." },
	{ "type": "passive", "name": "Flowing Spirit", "element": "water", "effect": "+10 SPR. Healing spells heal for 10% more.", "stat_bonus": { "spr": 10 }, "heal_mult": 0.10 },
	{ "type": "passive", "name": "Deep Currents",  "element": "water", "effect": "Water skills restore 2 MP per cast. +5 SPR.", "stat_bonus": { "spr": 5 }, "on_element": "water", "restore_resource": { "resource": "mana", "value": 2 } },
],
# L3
[
	{ "type": "skill",   "name": "Torrent",    "mp_cost": 45, "cooldown": 3, "target": "single",      "formula": "18 + 65% INT",      "element": "water", "threat": 0, "notes": "High single-target water." },
	{ "type": "passive", "name": "Aqua Shield", "element": "water", "effect": "Healing an ally grants them +10% Resistance for 2 turns.", "on_heal": true, "condition": { "target_is": "ally" }, "applies_buff_to_target": ["aqua_shield_resist"] },
	{ "type": "skill",   "name": "Cleanse",    "mp_cost": 20, "cooldown": 3, "target": "single_ally", "formula": "Heal 5 + 20% SPR",  "element": "water", "threat": 5, "remove_debuffs": 2, "notes": "Remove 2 debuffs from ally. Small heal." },
],
# L4
[
	{ "type": "skill",   "name": "Deluge",         "mp_cost": 45, "cooldown": 4, "target": "all_allies",  "formula": "Heal 10 + 55% SPR", "element": "water", "threat": 10, "remove_debuffs": 1, "notes": "Heal all allies. Remove 1 debuff each." },
	{ "type": "passive", "name": "Tidal Empathy",  "element": "water", "effect": "Each ally you heal grants you +2 Mana. Healing spells cost 5 less Mana.", "on_heal": true, "condition": { "target_is": "ally" }, "restore_resource": { "resource": "mana", "value": 2, "target": "self" }, "mp_cost_reduction": { "skill_type": "heal", "value": 5 } },
	{ "type": "skill",   "name": "Chaos Tide",     "mp_cost": 40, "cooldown": 4, "target": "all_enemies", "formula": "9 + 45% INT",       "element": "chaos", "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "slow", "value": -3, "duration": 2 }], "notes": "Cannot be resisted. AoE. Slow: -3 SPD for 2 turns." },
],
# L5-10
[{ "type": "stat", "stats": { "spr": 3 } },                        { "type": "stat", "stats": { "int": 2, "spr": 1 } },           { "type": "stat", "stats": { "mana_regen": 3, "spr": 1 } }],
[{ "type": "stat", "stats": { "hp": 10, "spr": 2 } },              { "type": "stat", "stats": { "spr": 3 } },                    { "type": "stat", "stats": { "resistance": 0.15, "spr": 1 } }],
[{ "type": "stat", "stats": { "spr": 3 } },                        { "type": "stat", "stats": { "mana": 20, "spr": 1 } },         { "type": "stat", "stats": { "hp_regen": 1, "mana_regen": 3 } }],
[{ "type": "stat", "stats": { "spr": 3 } },                        { "type": "stat", "stats": { "hp": 10, "spr": 2 } },           { "type": "stat", "stats": { "mana_regen": 3, "spr": 1 } }],
[{ "type": "stat", "stats": { "spr": 3 } },                        { "type": "stat", "stats": { "mana_regen": 3, "spr": 2 } },    { "type": "stat", "stats": { "int": 2, "spr": 1 } }],
[{ "type": "stat", "stats": { "spr": 3 } },                        { "type": "stat", "stats": { "hp_regen": 1, "mana_regen": 3 } }, { "type": "stat", "stats": { "mana_regen": 6, "spr": 1 } }],
],

# ── NORTHWEST ─────────────────────────────────────────────────────────────────
"NorthWest": [
# L1
[
	{ "type": "skill", "name": "Vine Whip",      "mp_cost": 12, "cooldown": 0, "target": "single",      "formula": "7 + 40% STR",  "element": "plant", "threat": 0,  "applies_debuff": [{ "id": "root", "duration": 1 }], "notes": "Root: enemy loses 1 action next turn." },
	{ "type": "skill", "name": "Stone Throw",    "mp_cost": 10, "cooldown": 0, "target": "single",      "formula": "9 + 50% STR",  "element": "stone", "threat": 5,  "notes": "Physical stone projectile." },
	{ "type": "skill", "name": "Nature's Wrath", "mp_cost": 25, "cooldown": 3, "target": "all_enemies", "formula": "5 + 30% INT",  "element": "plant", "threat": 0,  "applies_debuff": [{ "id": "slow", "value": -2, "duration": 2 }], "notes": "AoE plant. Slow: -2 SPD to all." },
],
# L2
[
	{ "type": "skill",   "name": "Petrify",    "mp_cost": 30, "cooldown": 3, "target": "single", "formula": "10 + 40% INT", "element": "stone", "threat": 0, "applies_debuff": [{ "id": "root", "duration": 1 }], "notes": "Stone damage. Target loses 1 action next turn." },
	{ "type": "passive", "name": "Bark Skin",  "element": "plant", "effect": "+12 DEF. +5% Block. Physical damage taken reduced by 5%.", "stat_bonus": { "def": 12, "block": 0.05 }, "damage_taken_reduction": { "type": "physical", "value": 0.05 } },
	{ "type": "passive", "name": "Overgrowth", "element": "plant", "effect": "Vine Whip Root lasts 2 turns. Root has 20% chance to spread to adjacent enemy.", "on_skill": "Vine Whip", "modify_debuff": { "id": "root", "duration_bonus": 1 }, "spread_debuff": { "id": "root", "chance": 0.20, "target": "adjacent_enemy", "duration": 1 } },
],
# L3
[
	{ "type": "skill",   "name": "Earthquake", "mp_cost": 55, "cooldown": 5, "target": "all_enemies", "formula": "12 + 50% STR", "element": "stone", "threat": 20, "applies_debuff": [{ "id": "slow", "value": -3, "duration": 3 }], "notes": "Massive AoE. -3 SPD for 3 turns to all enemies." },
	{ "type": "passive", "name": "Rooted",     "element": "stone", "effect": "+15 HP. +5% Resistance. Stone skills ignore 15% DEF.", "stat_bonus": { "hp": 15, "resistance": 0.05 }, "on_element": "stone", "ignore_def_pct": 0.15 },
	{ "type": "skill",   "name": "Spore Cloud","mp_cost": 30, "cooldown": 3, "target": "all_enemies", "formula": "",             "element": "plant", "threat": 0,  "applies_debuff": [{ "id": "poison", "duration": 4 }], "notes": "No damage. Poison: 4 dmg/turn for 4 turns to all enemies." },
],
# L4
[
	{ "type": "skill",   "name": "Thorn Wall",     "mp_cost": 35, "cooldown": 3, "target": "self",        "formula": "",             "element": "plant",    "threat": 15, "applies_buff": ["thorn_wall"], "notes": "Reflect 4 plant dmg to attackers for 3 turns." },
	{ "type": "passive", "name": "Stone Blood",    "element": "stone", "effect": "+10 DEF. When hit, 15% chance to Petrify attacker: -3 SPD for 2 turns.", "stat_bonus": { "def": 10 }, "on_hit_taken": true, "applies_debuff_to_attacker": [{ "id": "petrify", "duration": 2, "chance": 0.15 }] },
	{ "type": "skill",   "name": "Chaos Quake",    "mp_cost": 45, "cooldown": 4, "target": "all_enemies", "formula": "11 + 50% STR", "element": "chaos",    "threat": 0, "ignore_resistance": true, "applies_debuff": [{ "id": "random", "pool": ["root", "slow", "def_break"], "duration": 2 }], "notes": "Cannot be resisted. AoE. Random: Root, Slow, or -8 DEF on each target." },
],
# L5-10
[{ "type": "stat", "stats": { "def": 3 } },                        { "type": "stat", "stats": { "block": 0.05, "def": 1 } },      { "type": "stat", "stats": { "hp": 10, "def": 2 } }],
[{ "type": "stat", "stats": { "hp": 20, "def": 1 } },              { "type": "stat", "stats": { "def": 3 } },                    { "type": "stat", "stats": { "resistance": 0.15, "def": 1 } }],
[{ "type": "stat", "stats": { "def": 3 } },                        { "type": "stat", "stats": { "str": 2, "hp": 10 } },           { "type": "stat", "stats": { "block": 0.05, "def": 1 } }],
[{ "type": "stat", "stats": { "hp": 20, "def": 1 } },              { "type": "stat", "stats": { "def": 3 } },                    { "type": "stat", "stats": { "parry": 0.05, "def": 2 } }],
[{ "type": "stat", "stats": { "def": 3 } },                        { "type": "stat", "stats": { "hp": 10, "block": 0.05 } },      { "type": "stat", "stats": { "str": 3 } }],
[{ "type": "stat", "stats": { "def": 3 } },                        { "type": "stat", "stats": { "hp": 20, "def": 1 } },           { "type": "stat", "stats": { "block": 0.05, "parry": 0.05 } }],
],

} # end BRANCHES
