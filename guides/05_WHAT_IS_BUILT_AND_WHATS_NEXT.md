# Development Status

Last updated: 2026-04-21

---

## What Is Built and Working

### Auth
- Register (email, password, username)
- Login (email, password) with Remember Me (persists token via Firebase Auth save)
- Auto-login on startup if token is saved
- Logout (cleans up lobby/group presence, clears GameManager)

### Character System
- 3 character slots per account (Firestore subcollection)
- Character creation: name, branch selection, weapon, L1 skill/passive, 3 stat points
- Character select screen with stats preview on card
- Character sheet overlay (full stat view)
- Delete character (requires typing "DELETE")

### Lobby
- Live online player list (Firebase Realtime Database + heartbeat/prune)
- Group system: create, join (open groups), invite (closed groups), leave, disband
- Max 4 players per group
- Host can rename group, toggle open/closed, start battle
- Context menu: invite, inspect (shows character stats in event log), leave group
- Event log with timestamps
- Stale group cleanup on login

### Battle
- ATB (Active Time Battle) tick system
- Combatant panels with HP bar, MP bar, ATB bar
- Basic attack: precision/dodge, block, parry, crit, weapon damage ranges
- Spear ignores 50% DEF
- Dagger grants +10% crit on attack (defined in BranchData, not yet applied in combat code)
- Training Dummy: 200 HP, SPD 8, does nothing on its turn
- Victory overlay, defeat returns to lobby
- Battle log with color-coded outcomes

### Data
- All 8 branches defined in BranchData with L1–L10 nodes
- All debuffs and buffs defined (schema complete, not yet applied in combat)
- All weapons defined

### Build Pipeline
- GitHub Actions auto-builds on `v*` tag push
- Python launcher auto-updates and launches game

---

## What Is NOT Yet Built

### High Priority (next milestone)

- **Skills in combat** — BranchData has full skill/passive schema, action bar needs skill buttons, MP cost, cooldown tracking, formula resolution
- **Status effects in combat** — DEBUFFS/BUFFS defined but not applied
- **MP regen per turn** — stat exists, not implemented in battle loop
- **HP regen per turn** — stat exists, not implemented

### Medium Priority

- **Enemy AI** — Dummy does nothing. Real enemies need attack patterns.
- **Real enemy encounters** — BattleSelect shows no real encounter data yet
- **XP and leveling** — no XP granted on victory, no level-up screen
- **Loot on victory** — no item drops
- **Weapon: Shield** — off_hand slot not available at creation yet
- **Trinket system** — schema planned, not implemented

### Lower Priority / Future

- **Soul system** — character inherits stats from parent on death, generation tracking
- **Multiplayer battle sync** — battle is currently local only; group battles show all party members but actions are not synced via Firebase
- **Status icons on combatant panels**
- **Skill/passive previews in combat UI**
- **Sound and animations**

---

## Key Design Decisions to Know

- **Block vs Parry:** both negate 100% of damage. Block is tied to the Shield weapon (+10% block stat). Parry is a base stat available to all characters.
- **Resistance:** flat % reduction on magic damage. Does not apply to physical hits.
- **Chaos element:** ignores Resistance entirely.
- **ATB ties:** broken by random shuffle.
- **Group host leaving:** deletes the entire group. Non-host leaving only removes their member entry.
- **Character creation:** weapon determines combat role more than branch in early game. Branch determines skill access.
- **Generation:** tracked per character (starts at 1). Soul system will increment it on death/inheritance.
