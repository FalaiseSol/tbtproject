# TBT Project — Overview

## What Is This?

TBT is a turn-based RPG built in Godot 4.5 with Firebase as the backend. Players create characters, join a lobby, form groups with other online players, and enter ATB-based combat. The game is designed for small groups (up to 4 players).

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Game engine | Godot 4.5 | All scenes, UI, game logic |
| Language | GDScript | All scripts |
| Backend | Firebase | Auth, Firestore (character data), Realtime Database (lobby/groups/invites) |
| Firebase plugin | godot-firebase (addons/godot-firebase) | Godot ↔ Firebase bridge |
| SSE plugin | http-sse-client (addons/http-sse-client) | Required by godot-firebase for Realtime Database streaming |
| Build CI | GitHub Actions | Auto-exports Windows build on version tag push |
| Auto-updater | Python launcher (launcher/launcher.py) | Checks GitHub Releases API, downloads update, launches game |

## Repository Structure

```
tbtproject/
├── godot/                        # Godot project root
│   ├── project.godot             # Project config, autoloads
│   ├── export_presets.cfg        # Windows Desktop export preset
│   ├── firebase.env              # Firebase credentials — NEVER COMMIT
│   ├── addons/
│   │   ├── godot-firebase/       # Firebase plugin
│   │   └── http-sse-client/      # SSE streaming plugin (dependency)
│   ├── scenes/                   # All .tscn scene files
│   └── scripts/
│       ├── game/                 # Data and global state (no UI)
│       └── ui/                   # One script per scene
├── Guides/                       # This documentation folder
├── guides/                       # Legacy design docs (Game_Concept_Summary, Dev_Status, etc.)
├── launcher/
│   ├── launcher.py               # Auto-update launcher source
│   └── build_launcher.bat        # Compiles launcher.py → TBT_Launcher.exe
├── .github/workflows/build.yml   # GitHub Actions CI pipeline
├── database.rules.json           # Firebase Realtime Database security rules
└── firestore.rules               # Firestore security rules
```

## Firebase Services Used

- **Firebase Auth** — email/password login and registration, token persistence (remember me)
- **Firestore** — persistent storage for user profiles and character data
- **Realtime Database** — live lobby presence, groups, and invite system (streaming via SSE)

## Autoloads (Global Singletons)

- `Firebase` — the godot-firebase plugin node (defined in project.godot)
- `GameManager` — custom singleton (`scripts/game/game_manager.gd`) — holds current user/character state across scenes

## Scene Flow

```
Main (main menu)
  └─ Login / Register
       └─ CharacterSelect (3 slots)
            ├─ CharacterCreate (new character)
            └─ Lobby (online players, groups)
                 └─ BattleSelect (encounter picker)
                      └─ Battle (ATB combat)
```
