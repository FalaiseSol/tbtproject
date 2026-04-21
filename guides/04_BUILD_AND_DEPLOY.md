# Build Pipeline and Deployment

## How to Ship a New Build

1. Finish your code, commit and push to master
2. Create and push a version tag:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. GitHub Actions runs automatically (visible at github.com/FalaiseSol/tbtproject/actions)
4. A GitHub Release is created with `TBT.zip` as an asset (~5 minutes total)
5. Testers launch `TBT_Launcher.exe` — it auto-downloads and launches the new version

## GitHub Actions Pipeline (`.github/workflows/build.yml`)

**Trigger:** any tag matching `v*` pushed to the repo.

**Steps:**
1. Downloads Godot 4.5-stable Linux headless binary from GitHub releases
2. Downloads Godot 4.5-stable export templates (`.tpz` file)
3. Installs templates to `~/.local/share/godot/export_templates/4.5.stable/`
4. Runs `godot --headless --export-release "Windows Desktop" ../build/TBT.exe` from the `godot/` directory
5. Writes the tag name (e.g. `v0.1.0`) to `build/version.txt`
6. Zips `build/` into `TBT.zip`
7. Creates a GitHub Release using `softprops/action-gh-release@v2`

**Required repo setting (one-time):**
Go to: Repo → Settings → Actions → General → Workflow permissions → "Read and write permissions"
Without this, the release upload step fails with a 403.

## Godot Export Preset

The Windows Desktop export preset is already configured in `godot/export_presets.cfg`.

- Platform: Windows Desktop
- Architecture: x86_64
- Export path in the file: `../../TBT project.exe` (relative) — the CI command overrides this with its own path argument, so it doesn't matter
- The `include_filter = "*.env"` line ensures `firebase.env` is bundled with the export

## Auto-Update Launcher (`launcher/launcher.py`)

A small Python script that testers run instead of the game directly.

**What it does on launch:**
1. Reads `version.txt` from the same folder (local version)
2. Calls `https://api.github.com/repos/FalaiseSol/tbtproject/releases/latest`
3. Compares `tag_name` to local version
4. If newer: shows a small progress window, downloads `TBT.zip`, extracts it in-place, updates `version.txt`
5. Launches `TBT.exe` via `subprocess.Popen`
6. If no internet or API is down: silently skips update and launches whatever is local

**Building the launcher exe (only needed when launcher.py changes):**

Double-click `launcher/build_launcher.bat`. It installs PyInstaller and compiles to `launcher/dist/TBT_Launcher.exe`.

**First-time tester setup:**
- Give testers `TBT_Launcher.exe` once
- That's it — all future game updates are automatic

## Local Repo Info

- Path: `C:/Users/PC/Documents/Code/tbtproject`
- Remote: `https://github.com/FalaiseSol/tbtproject.git`
- Branch: `master`

## What Must NOT Be Committed

- `godot/firebase.env` — Firebase API key and project credentials. It's in `.gitignore`. If it ever gets committed accidentally, rotate the Firebase API key immediately in the Firebase console.
