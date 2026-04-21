import os
import sys
import json
import zipfile
import shutil
import subprocess
import urllib.request
import tkinter as tk
from tkinter import ttk

REPO = "FalaiseSol/tbtproject"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"
GAME_EXE = "TBT.exe"
VERSION_FILE = "version.txt"


def get_local_version():
    if os.path.exists(VERSION_FILE):
        return open(VERSION_FILE).read().strip()
    return ""


def get_latest_release():
    req = urllib.request.Request(API_URL, headers={"User-Agent": "TBT-Launcher"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def find_zip_asset(release):
    for asset in release.get("assets", []):
        if asset["name"].endswith(".zip"):
            return asset["browser_download_url"], asset["name"]
    return None, None


def download_with_progress(url, dest, progress_var, status_var, window):
    def reporthook(count, block_size, total_size):
        if total_size > 0:
            pct = min(int(count * block_size * 100 / total_size), 100)
            progress_var.set(pct)
            status_var.set(f"Downloading... {pct}%")
            window.update()

    urllib.request.urlretrieve(url, dest, reporthook)


def run_gui_update(release, zip_url):
    window = tk.Tk()
    window.title("TBT Launcher")
    window.geometry("360x130")
    window.resizable(False, False)

    status_var = tk.StringVar(value="Downloading update...")
    progress_var = tk.IntVar(value=0)

    tk.Label(window, textvariable=status_var, pady=10).pack()
    bar = ttk.Progressbar(window, variable=progress_var, maximum=100, length=300)
    bar.pack(pady=5)

    window.update()

    zip_path = "TBT_update.zip"
    try:
        download_with_progress(zip_url, zip_path, progress_var, status_var, window)

        status_var.set("Extracting...")
        window.update()

        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(".")

        os.remove(zip_path)
        status_var.set("Done!")
        window.update()

    except Exception as e:
        status_var.set(f"Update failed: {e}")
        window.update()
        window.after(3000, window.destroy)
        window.mainloop()
        return

    window.destroy()


def main():
    local_version = get_local_version()

    try:
        release = get_latest_release()
    except Exception:
        # No internet or API down — just launch whatever we have
        if os.path.exists(GAME_EXE):
            subprocess.Popen([GAME_EXE])
        return

    latest_version = release.get("tag_name", "")

    if latest_version and latest_version != local_version:
        zip_url, zip_name = find_zip_asset(release)
        if zip_url:
            run_gui_update(release, zip_url)

    if os.path.exists(GAME_EXE):
        subprocess.Popen([GAME_EXE])
    else:
        tk.Tk().withdraw()
        import tkinter.messagebox as mb
        mb.showerror("TBT Launcher", f"{GAME_EXE} not found. Update may have failed.")


if __name__ == "__main__":
    main()
