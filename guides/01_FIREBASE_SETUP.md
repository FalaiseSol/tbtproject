# Firebase Setup

## Firebase Project

- Project ID: `tbtproject-d415a`
- Services used: Authentication, Firestore, Realtime Database

## Credentials File

Firebase credentials live in `godot/firebase.env`. This file is in `.gitignore` and must never be committed — it contains the API key.

Format:
```ini
[firebase/environment_variables]
"apiKey"="...",
"authDomain"="tbtproject-d415a.firebaseapp.com",
"databaseURL"="...",
"projectId"="tbtproject-d415a",
"storageBucket"="...",
"messagingSenderId"="...",
"appId"="..."
```

The godot-firebase plugin reads this file automatically on startup via the `export_presets.cfg` include filter `*.env`.

## Godot Plugin: godot-firebase

Located at `godot/addons/godot-firebase/`. Enabled via Project → Project Settings → Plugins.

The plugin exposes a global `Firebase` autoload node (defined in `project.godot`). All Firebase calls go through it:

- `Firebase.Auth` — login, register, token refresh, logout
- `Firebase.Firestore` — document reads/writes
- `Firebase.Database` — realtime listeners and writes

The plugin also requires `http-sse-client` (`godot/addons/http-sse-client/`) for Realtime Database streaming. Both must be enabled.

## Firestore Data Structure

```
users/
  {uid}/
    username: String
    created_at: int (unix timestamp)
    characters/
      slot_0/   (document)
        name, branch, generation, level, created_at, stats, skills, weapon
      slot_1/
      slot_2/
```

Characters are stored per-user in a subcollection, one document per slot (slot_0, slot_1, slot_2).

## Realtime Database Structure

```
lobby/
  {uid}/
    username: String
    heartbeat: int (unix timestamp)

groups/
  {group_id}/
    host: String (uid)
    name: String
    open: bool
    members/
      {uid}: String (username)

invites/
  {uid}/
    {group_id}/
      from_name: String
      group_id: String
```

The lobby and groups are live-streamed using Firebase Database references and SSE. Players prune stale lobby entries after 45 seconds without a heartbeat.

## Security Rules

- `firestore.rules` — Firestore rules (users can only read/write their own data)
- `database.rules.json` — Realtime Database rules

Deploy rules with the Firebase CLI:
```bash
firebase deploy --only firestore:rules
firebase deploy --only database
```
